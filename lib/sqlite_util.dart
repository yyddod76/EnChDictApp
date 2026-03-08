import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;

const List<String> alphabets = [
  "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"
];

String _getStr(String? name, Row row) {
  return row[name!] ?? '';
}

List<String> _getStrList(String? name, Row row) {
  final jsonListStr = row[name!];
  List<String> strList = [];
  if (jsonListStr != null && jsonListStr.isNotEmpty && jsonListStr != '[]') {
    try {
      final dynamic decodedData = json.decode(jsonListStr);
      strList = decodedData is List ? decodedData.map((e) => e.toString()).toList() : <String>[];
    } catch (e) {
      debugPrint('Error decoding $name JSON: $e');
    }
  }
  return strList;
}

class EnWordData {
  final int id;
  final String word;
  final String phonetic;
  final List<String> definition;
  final List<String> translation;
  final List<String> examples;

  EnWordData({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.definition,
    required this.translation,
    required this.examples,
  });

  factory EnWordData.fromRow(Row row) {
    return EnWordData(
      id: row['id'],
      word: _getStr('word', row),
      phonetic: _getStr('phonetic', row),
      definition: _getStrList('definition', row),
      translation: _getStrList('translation', row),
      examples: _getStrList('examples', row),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnWordData &&
          runtimeType == other.runtimeType &&
          word == other.word;

  @override
  int get hashCode => word.hashCode ^ phonetic.hashCode;
}

class ChWordData {
  final int id;
  final String traditional;
  final String simplified;
  final String pinyin;
  final List<String> definitions;

  ChWordData({
    required this.id,
    required this.traditional,
    required this.simplified,
    required this.pinyin,
    required this.definitions,
  });

  factory ChWordData.fromRow(Row row) {
    return ChWordData(
      id: row['id'],
      traditional: _getStr('traditional', row),
      simplified: _getStr('simplified', row),
      pinyin: _getStr('pinyin', row),
      definitions: _getStrList('definitions', row),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChWordData &&
          runtimeType == other.runtimeType &&
          simplified == other.simplified;

  @override
  int get hashCode => simplified.hashCode ^ traditional.hashCode;
}

class DictDatabase {
  static final DictDatabase _instance = DictDatabase._init();
  static DictDatabase get instance => _instance;

  late final Database _db;
  final Map<String, PreparedStatement> _searchEnStmts = {};
  late final PreparedStatement _searchChStmt;
  List<String> _enInChList = [];
  List<dynamic> _favorites = [];
  Map<String, List<String>> _histories = {};

  // [Fix #1] Exposed future so callers can await DB readiness before use.
  late final Future<void> _readyFuture;
  Future<void> get ready => _readyFuture;

  List<dynamic> get favorites => _favorites;
  Map<String, List<String>> get histories => _histories;

  DictDatabase._init() {
    _readyFuture = _openDb();
  }

  Future<void> _openDb() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, 'dictionary_ec_database.sqlite');
    final file = File(dbPath);

    if (!await file.exists()) {
      final byteData = await rootBundle.load('assets/database/dictionary_ec_database.sqlite');
      await file.writeAsBytes(
        byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
        flush: true,
      );
    }

    _db = sqlite3.open(dbPath);
    debugPrint('Database opened at: $dbPath');

    final result = _db.select('SELECT word FROM en_in_ch');
    _enInChList = result.map((row) => row['word'] as String).toList();

    for (String letter in alphabets) {
      _searchEnStmts[letter] = _db.prepare(
        'SELECT * FROM dict_en_ch_$letter WHERE ID > ? AND LOWER(word) LIKE ? LIMIT ?',
      );
    }

    // [Fix #4] Added parentheses so OR clause is scoped correctly; LIMIT and
    // ID > ? offset now apply to both simplified and traditional branches.
    _searchChStmt = _db.prepare(
      'SELECT * FROM dict_ch_en WHERE ID > ? AND (LOWER(simplified) LIKE ? OR LOWER(traditional) LIKE ?) LIMIT ?',
    );

    // [Fix #2] Load favorites as typed model objects so operator== works correctly.
    for (String letter in alphabets) {
      _favorites.addAll(
        _db.select('SELECT * FROM dict_en_ch_$letter WHERE bookmark IS NOT NULL')
            .map((row) => EnWordData.fromRow(row)),
      );
    }
    _favorites.addAll(
      _db.select('SELECT * FROM dict_ch_en WHERE bookmark IS NOT NULL')
          .map((row) => ChWordData.fromRow(row)),
    );

    _histories['today'] = _db.select("""
      SELECT word FROM history
      WHERE date(dt) = date('now')
      ORDER BY datetime(dt) DESC
    """).map((row) => _getStr('word', row)).toList();

    _histories['this week'] = _db.select("""
      SELECT word FROM history
      WHERE date(dt) < date('now') AND date(dt) >= date('now', '-7 day')
      ORDER BY datetime(dt) DESC
    """).map((row) => _getStr('word', row)).toList();

    _histories['this month'] = _db.select("""
      SELECT word FROM history
      WHERE date(dt) < date('now', '-7 day') AND date(dt) >= date('now', '-1 month')
      ORDER BY datetime(dt) DESC
    """).map((row) => _getStr('word', row)).toList();

    _histories['this year'] = _db.select("""
      SELECT word FROM history
      WHERE date(dt) < date('now', '-1 month') AND date(dt) >= date('now', '-12 month')
      ORDER BY datetime(dt) DESC
    """).map((row) => _getStr('word', row)).toList();

    _histories['older'] = _db.select("""
      SELECT word FROM history
      WHERE date(dt) < date('now', '-12 month')
      ORDER BY datetime(dt) DESC
    """).map((row) => _getStr('word', row)).toList();
  }

  // [Fix #3] Added ChWordData handling so Chinese bookmarks are persisted.
  Future<void> refreshFavorites(List<dynamic> updatedList) async {
    final Set<dynamic> orig = _favorites.toSet();
    final Set<dynamic> updated = updatedList.toSet();

    final deleted = orig.difference(updated);
    final added = updated.difference(orig);

    for (var del in deleted) {
      if (del is EnWordData) {
        _db.execute(
          'UPDATE dict_en_ch_${del.word[0].toLowerCase()} SET bookmark = ? WHERE word = ?',
          [null, del.word],
        );
      } else if (del is ChWordData) {
        _db.execute(
          'UPDATE dict_ch_en SET bookmark = ? WHERE simplified = ?',
          [null, del.simplified],
        );
      }
    }

    for (var add in added) {
      if (add is EnWordData) {
        _db.execute(
          'UPDATE dict_en_ch_${add.word[0].toLowerCase()} SET bookmark = ? WHERE word = ?',
          [1, add.word],
        );
      } else if (add is ChWordData) {
        _db.execute(
          'UPDATE dict_ch_en SET bookmark = ? WHERE simplified = ?',
          [1, add.simplified],
        );
      }
    }

    _favorites.clear();
    _favorites.addAll(updatedList);
  }

  Future<void> updateHistory(String word) async {
    String tag = "";
    for (var entry in _histories.entries) {
      if (entry.value.contains(word)) {
        tag = entry.key;
        break;
      }
    }
    if (tag != "") {
      _db.execute(
        "UPDATE history SET dt = datetime(?) WHERE word = ?",
        ["now", word],
      );
      _histories[tag]!.remove(word);
    } else {
      _db.execute(
        "INSERT INTO history (word, dt) VALUES (?, datetime(?))",
        [word, "now"],
      );
    }
    _histories['today']!.insert(0, word);
  }

  Future<void> clearHistory(String key) async {
    final Map<String, String> cmds = {
      'today':      "DELETE FROM history WHERE date(dt) = date('now');",
      'this week':  "DELETE FROM history WHERE date(dt) < date('now') AND date(dt) >= date('now', '-7 day');",
      'this month': "DELETE FROM history WHERE date(dt) < date('now', '-7 day') AND date(dt) >= date('now', '-1 month');",
      'this year':  "DELETE FROM history WHERE date(dt) < date('now', '-1 month') AND date(dt) >= date('now', '-12 month');",
      'older':      "DELETE FROM history WHERE date(dt) < date('now', '-12 month');",
    };
    final cmd = cmds[key];
    if (cmd != null) {
      _db.execute(cmd);
      _histories[key]?.clear();
    }
  }

  // [Fix #14] Guard against non-alpha first character to avoid null key crash.
  List<EnWordData> searchEn(String word, int limit, int offset) {
    debugPrint('Searching for en word: $word');
    final String pattern = '${word.toLowerCase()}%';
    final String firstChar = pattern[0];
    if (!_searchEnStmts.containsKey(firstChar)) return [];
    final stopwatch = Stopwatch()..start();
    final ResultSet result = _searchEnStmts[firstChar]!.select([offset, pattern, limit]);
    stopwatch.stop();
    debugPrint('Search completed in ${stopwatch.elapsedMilliseconds} ms, found ${result.length} results.');
    return result.map((row) => EnWordData.fromRow(row)).toList();
  }

  List<ChWordData> searchCh(String word, int limit, int offset) {
    debugPrint('Searching for ch word: $word');
    final String pattern = '%${word.toLowerCase()}%';
    final stopwatch = Stopwatch()..start();
    final ResultSet result = _searchChStmt.select([offset, pattern, pattern, limit]);
    stopwatch.stop();
    debugPrint('Search(2) completed in ${stopwatch.elapsedMilliseconds} ms, found ${result.length} results.');
    return result.map((row) => ChWordData.fromRow(row)).toList();
  }

  List<dynamic> search(String word, int limit, {int offset = 0}) {
    List<dynamic> results = _search(word, limit, offset: offset);
    if (results.isEmpty && word.trim() != word) {
      results = _search(word.trim(), limit, offset: offset);
    }
    if (results.isEmpty && word.replaceAll(' ', '-') != word) {
      results = _search(word.replaceAll(' ', '-'), limit, offset: offset);
    }
    return results;
  }

  List<dynamic> _search(String word, int limit, {int offset = 0}) {
    List<dynamic> results = [];
    if (word.isNotEmpty) {
      final RegExp irregularChars = RegExp(r'[^a-zA-Z -]');
      if (irregularChars.hasMatch(word)) {
        results.addAll(searchCh(word, limit, offset));
      } else if (word.startsWith(RegExp(r'[a-zA-Z]'))) {
        results.addAll(searchEn(word, limit, offset));
        if (_enInChList.contains(word.toLowerCase()) || _enInChList.contains(word.toUpperCase())) {
          if (results.length > 16) {
            results.insertAll(0, searchCh(word, limit, 0));
          } else {
            results.addAll(searchCh(word, limit, 0));
          }
        }
      }
    }
    return results;
  }

  void close() {
    for (var stmt in _searchEnStmts.values) {
      stmt.dispose();
    }
    _searchChStmt.dispose();
    _db.dispose();
    debugPrint('Database closed.');
  }
}
