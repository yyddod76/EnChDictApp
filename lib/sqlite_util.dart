import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:core';

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
      print('Error decoding $name JSON: $e');
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

  // Factory constructor to create EnWordData from a QueryRow
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

  // Factory constructor to create ChWordData from a QueryRow
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

  // Database instance
  late final Database _db;
  final Map<String, PreparedStatement> _searchEnStmts = {};
  late final PreparedStatement _searchChStmt;
  List<String> _enInChList = [];
  List<dynamic> _favorites = [];
  Map<String, List<String>> _histories = {};

  List<dynamic> get favorites => _favorites;
  Map<String, List<String>> get histories => _histories;

  DictDatabase._init() {
    openDb();
  }

  void openDb() async{
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
    print('Database opened at: $dbPath');

    final result = _db.select('SELECT word FROM en_in_ch');
    _enInChList = result.map((row) => row['word'] as String).toList();

    for (String letter in alphabets) {
      _searchEnStmts[letter] =
        _db.prepare(
          'SELECT * FROM dict_en_ch_$letter WHERE ID > ? AND LOWER(word) LIKE ? LIMIT ?',
        );
    }

    _searchChStmt = _db.prepare(
      'SELECT * FROM dict_ch_en WHERE ID > ? AND LOWER(simplified) LIKE ? OR LOWER(traditional) LIKE ? LIMIT ?',
    );

    for (String letter in alphabets) {
      _favorites.addAll(
        _db.select(
          'SELECT * FROM dict_en_ch_$letter WHERE bookmark IS NOT NULL',
        )
      );
    }
    _favorites.addAll(
      _db.select(
        'SELECT * FROM dict_ch_en WHERE bookmark IS NOT NULL',
      )
    );

    _histories['today'] = _db.select(
      """SELECT word from history
      WHERE date(dt) = date('now')
      ORDER BY datetime(dt) DESC
      """).map((row) => _getStr('word', row)).toList();

    _histories['this week'] = _db.select(
      """SELECT word from history
      WHERE date(dt) < date('now') AND date(dt) >= date('now', '-7 day')
      ORDER BY datetime(dt) DESC
      """).map((row) => _getStr('word', row)).toList();

    _histories['this month'] = _db.select(
      """SELECT word from history
      WHERE date(dt) < date('now', '-7 day') AND date(dt) >= date('now', '-1 month')
      ORDER BY datetime(dt) DESC
      """).map((row) => _getStr('word', row)).toList();

    _histories['this year'] = _db.select(
      """SELECT word from history
      WHERE date(dt) < date('now', '-1 month') AND date(dt) >= date('now', '-12 month')
      ORDER BY datetime(dt) DESC
      """).map((row) => _getStr('word', row)).toList();

    _histories['older'] = _db.select(
      """SELECT word from history
      WHERE date(dt) < date('now', '-12 month')
      ORDER BY datetime(dt) DESC
      """).map((row) => _getStr('word', row)).toList();
  }

  Future<void> refreshFavorites(List<dynamic> updatedList) async{
    Set<dynamic> orig = _favorites.toSet();
    Set<dynamic> updated = updatedList.toSet();

    var deleted = orig.difference(updated);
    var added = updated.difference(orig);

    for (var del in deleted) {
      if (del is EnWordData) {
        _db.execute(
          'UPDATE dict_en_ch_${del.word[0]} SET bookmark = ? WHERE word = ?',
          [null, del.word]
        );
      }
    }

    for (var add in added) {
      if (add is EnWordData) {
        _db.execute(
          'UPDATE dict_en_ch_${add.word[0]} SET bookmark = ? WHERE word = ? RETURNING *',
          [1, add.word]
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
      _db.execute("""
          UPDATE history
          SET dt = datetime(?)
          WHERE word = ?
        """,
        ["now", word]
      );
      _histories[tag]!.remove(word);
    } else {
      _db.execute("""
          INSERT INTO history (word, dt)
          VALUES (?, datetime(?))
        """, [word, "now"]
      );
    }
    _histories['today']!.insert(0, word);
  }

  Future<void> clearHistory() async {
    _db.execute("""
        DELETE FROM history;
      """
    );
    for (var entry in _histories.entries) {
      entry.value.clear();
    }
  }

  // Method to search for a word in the database
  List<EnWordData> searchEn(String? word, int? limit, int? offset) {
    print('Searching for en word: $word');
    final String pattern = '${word!.toLowerCase()}%';
    final stopwatch = Stopwatch()..start();
    ResultSet result = _searchEnStmts[pattern[0]]!.select([offset, pattern, limit!]);

    // if (word.contains(' ')) {
    //   final String pattern2 = '${word.toLowerCase().replaceAll(' ', '-')}%';
    //   result = _searchEnStmts[pattern[0]]!.select([offset, pattern2, limit]);
    // }

    stopwatch.stop();
    print('Search completed in ${stopwatch.elapsedMilliseconds} ms, found ${result.length} results.');

    return result.map((row) {
      return EnWordData.fromRow(row);
    }).toList();
  }

  List<ChWordData> searchCh(String? word, int? limit, int? offset) {
    print('Searching for ch word: $word');
    final String pattern = '%${word!.toLowerCase()}%';
    final stopwatch = Stopwatch()..start();
    final ResultSet result = _searchChStmt.select([offset, pattern, pattern, limit!]);
    stopwatch.stop();
    print('Search(2)completed in ${stopwatch.elapsedMilliseconds} ms, found ${result.length} results.');

    return result.map((row) {
      return ChWordData.fromRow(row);
    }).toList();
  }

  List<dynamic> search(String? word, int? limit, {int? offset = 0}) {
    List<dynamic> results = [];
    if (word!.isNotEmpty) {
      final RegExp irregularChars = RegExp(r'[^a-zA-Z -]');
      if (irregularChars.hasMatch(word)) {
        // Search in Chinese words as type ChWordData
        results.addAll(searchCh(word, limit, offset));
      } else if (word.startsWith(RegExp(r'[a-zA-Z]'))) {
        // Search in English words as type EnWordData
        results.addAll(searchEn(word, limit, offset));
        // all English letters in Ch dict
        if (_enInChList.contains(word.toLowerCase()) || _enInChList.contains(word.toUpperCase())) {
          if (results.length > 16) {
            results.insertAll(16, searchCh(word, limit, 0));
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
    print('Database closed.');
  }
}
