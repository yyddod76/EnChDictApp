import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'sqlite_util.dart';
import 'vocab_service.dart';

class VocabPage extends StatefulWidget {
  const VocabPage({super.key});
  @override
  State<VocabPage> createState() => _VocabPageState();
}

class _VocabPageState extends State<VocabPage> {
  String? _selectedList;
  int _selectedMode = 0; // 0=sequential, 1=random
  List<VocabListInfo> _lists = [];
  VocabRegistration? _registration;
  int _dailyCount = 15;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final db = DictDatabase.instance;
    setState(() {
      _lists = db.getVocabLists();
      _registration = db.getRegistration();
      if (_registration != null) {
        _selectedList = _registration!.listKey;
        _selectedMode = _registration!.mode;
        _dailyCount = _registration!.dailyCount.clamp(10, 300);
      } else if (_lists.isNotEmpty) {
        _selectedList = _lists.first.key;
      }
      _dailyCount = _clampDailyCount(_dailyCount);
      _loading = false;
    });
  }

  void _reloadLists({String? selectedKey}) {
    final db = DictDatabase.instance;
    setState(() {
      _lists = db.getVocabLists();
      _registration = db.getRegistration();
      if (selectedKey != null) {
        _selectedList = selectedKey;
      }
      if (_selectedList != null && !_lists.any((l) => l.key == _selectedList)) {
        _selectedList = _lists.isNotEmpty ? _lists.first.key : null;
      } else if (_selectedList == null && _lists.isNotEmpty) {
        _selectedList = _lists.first.key;
      }
      _dailyCount = _clampDailyCount(_dailyCount);
    });
  }

  String _stripExtension(String name) {
    final idx = name.lastIndexOf('.');
    if (idx <= 0) return name;
    return name.substring(0, idx);
  }

  List<String> _parseWordsFromText(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('[')) {
      try {
        final decoded = json.decode(trimmed);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return [];
      }
    }
    return trimmed
        .split(RegExp(r'[\r\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _extractFavoriteWords(List<dynamic> favorites) {
    final List<String> words = [];
    for (final item in favorites) {
      if (item is EnWordData) {
        words.add(item.word);
      } else if (item is ChWordData) {
        words.add(item.simplified);
      } else {
        words.add(item.toString());
      }
    }
    return words;
  }

  List<String> _extractHistoryWords(Map<String, List<String>> histories) {
    const orderedKeys = ['today', 'this week', 'this month', 'this year', 'older'];
    final List<String> words = [];
    for (final key in orderedKeys) {
      final items = histories[key];
      if (items != null && items.isNotEmpty) {
        words.addAll(items);
      }
    }
    for (final entry in histories.entries) {
      if (orderedKeys.contains(entry.key)) continue;
      if (entry.value.isNotEmpty) {
        words.addAll(entry.value);
      }
    }
    return words;
  }

  Future<String?> _promptForListName(String initialName, MyAppState appState) async {
    final controller = TextEditingController(text: initialName);
    final isEn = appState.langMode == 0;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Name Your List' : '命名单词表'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isEn ? 'Vocabulary list name' : '单词表名称',
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(isEn ? 'Cancel' : '取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              Navigator.of(ctx).pop(name.isEmpty ? null : name);
            },
            child: Text(isEn ? 'Save' : '保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _createListFromWords({
    required String defaultName,
    required List<String> words,
  }) async {
    final appState = context.read<MyAppState>();
    final messenger = ScaffoldMessenger.of(context);
    final isEn = appState.langMode == 0;

    if (words.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(isEn ? 'No words found to create a list.' : '没有可用于创建单词表的单词。')),
      );
      return;
    }

    final name = await _promptForListName(defaultName, appState);
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) return;

    final listKey = await DictDatabase.instance.addCustomVocabList(
      nameEn: name,
      nameZh: name,
      words: words,
    );

    if (!mounted) return;
    if (listKey == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(isEn ? 'No valid words found in this list.' : '该列表没有有效单词。')),
      );
      return;
    }

    _reloadLists(selectedKey: listKey);
    messenger.showSnackBar(
      SnackBar(content: Text(isEn ? 'Vocabulary list added.' : '单词表已添加。')),
    );
  }

  Future<void> _importFromFile() async {
    final appState = context.read<MyAppState>();
    final messenger = ScaffoldMessenger.of(context);
    final isEn = appState.langMode == 0;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'json', 'csv'],
      withData: true,
    );
    if (result == null) return;

    final file = result.files.single;
    if (file.bytes == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(isEn ? 'Unable to read this file.' : '无法读取该文件。')),
      );
      return;
    }

    final content = utf8.decode(file.bytes!, allowMalformed: true);
    final words = _parseWordsFromText(content);
    if (words.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(isEn ? 'No valid words found in the file.' : '文件中没有有效单词。')),
      );
      return;
    }

    final baseName = _stripExtension(file.name);
    final defaultName = baseName.isNotEmpty
        ? baseName
        : (isEn ? 'Custom List' : '自定义单词表');
    await _createListFromWords(defaultName: defaultName, words: words);
  }

  Future<void> _createFromFavorites(MyAppState appState) async {
    final words = _extractFavoriteWords(appState.favoriteList);
    final defaultName = appState.langMode == 0 ? 'Favorites' : '收藏';
    await _createListFromWords(defaultName: defaultName, words: words);
  }

  Future<void> _createFromHistory(MyAppState appState) async {
    final words = _extractHistoryWords(appState.historyList);
    final defaultName = appState.langMode == 0 ? 'History' : '历史记录';
    await _createListFromWords(defaultName: defaultName, words: words);
  }

  Future<void> _deleteCustomList(VocabListInfo list) async {
    final appState = context.read<MyAppState>();
    final messenger = ScaffoldMessenger.of(context);
    final isEn = appState.langMode == 0;
    final confirmed = await showDeleteConfirmationDialog(
      context,
      isEn ? 'Delete list' : '删除单词表',
      isEn
          ? 'This will remove the list and its progress data.'
          : '将删除此单词表及其学习进度。',
      appState,
    );
    if (!confirmed) return;

    final wasRegistered = _registration?.listKey == list.key;
    final deleted = await DictDatabase.instance.deleteCustomVocabList(list.key);
    if (!deleted) return;
    if (wasRegistered) {
      await VocabNotificationService.cancelReminder();
      appState.refreshVocabCards();
    }
    _reloadLists();
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(isEn ? 'List deleted.' : '单词表已删除。')),
      );
    }
  }

  int _listCountForKey(String? listKey) {
    if (listKey == null) return 300;
    final match = _lists.where((l) => l.key == listKey);
    if (match.isEmpty) return 300;
    return match.first.wordCount;
  }

  int _currentListCount() {
    return _listCountForKey(_registration?.listKey ?? _selectedList);
  }

  int _minDailyCount() {
    final count = _currentListCount();
    if (count > 0 && count < 10) return count;
    return 10;
  }

  int _maxDailyCount() {
    final count = _currentListCount();
    if (count <= 0) return 300;
    final minVal = _minDailyCount();
    return count.clamp(minVal, 300);
  }

  int _clampDailyCount(int value) {
    final minVal = _minDailyCount();
    final maxAllowed = _maxDailyCount();
    return value.clamp(minVal, maxAllowed);
  }

  Future<void> _applyDailyCount(int value) async {
    final int newCount = _clampDailyCount(value);
    if (_dailyCount == newCount) return;
    setState(() {
      _dailyCount = newCount;
    });
    if (_registration != null) {
      final appStateRef = context.read<MyAppState>();
      await DictDatabase.instance.updateVocabDailyCount(newCount);
      appStateRef.refreshVocabCards();
      if (mounted) {
        setState(() {
          _registration = DictDatabase.instance.getRegistration();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final bool isEn = appState.langMode == 0;
    final colorScheme = Theme.of(context).colorScheme;
    final int sliderMax = _maxDailyCount();
    final int sliderMin = _minDailyCount();
    final int maxCountForList = sliderMax;
    final int favoritesCount = appState.favoriteList.length;
    final int historyCount = appState.historyList.values.fold(0, (sum, list) => sum + list.length);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Vocabulary Study' : '单词学习'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Current registration status
                if (_registration != null) ...[
                  Card(
                    color: colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.check_circle_rounded, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(isEn ? 'Currently Registered' : '当前已注册',
                              style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)),
                          ]),
                          const SizedBox(height: 8),
                          Text(isEn ? _registration!.listNameEn : _registration!.listNameZh,
                            style: TextStyle(fontSize: getFont(appState, AppFonts.body), color: colorScheme.onPrimaryContainer)),
                          Text(isEn
                            ? 'Mode: ${_registration!.mode == 0 ? "Sequential" : "Random"}'
                            : '模式: ${_registration!.mode == 0 ? "顺序" : "随机"}',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.caption), color: colorScheme.onPrimaryContainer)),
                          Text(
                            isEn ? 'Daily: ${_registration!.dailyCount} words' : '每日: ${_registration!.dailyCount} 词',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.caption), color: colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: 4),
                          _ProgressStats(listKey: _registration!.listKey, appState: appState, isEn: isEn),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // List selector
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEn ? 'Choose Vocabulary List' : '选择单词表',
                          style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ..._lists.map((list) => RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          dense: true,
                          value: list.key,
                          groupValue: _selectedList,
                          title: Text(isEn ? list.nameEn : list.nameZh,
                            style: TextStyle(fontSize: getFont(appState, AppFonts.body))),
                          subtitle: Text('${list.wordCount} ${isEn ? "words" : "词"}',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.caption))),
                          secondary: list.isCustom
                              ? IconButton(
                                  tooltip: isEn ? 'Delete list' : '删除单词表',
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () => _deleteCustomList(list),
                                )
                              : null,
                          onChanged: (val) {
                            setState(() => _selectedList = val);
                            if (_registration == null) {
                              _applyDailyCount(_dailyCount);
                            }
                          },
                        )),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(isEn ? 'Add Custom List' : '添加自定义单词表',
                          style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold)),

                        ...[
                          const SizedBox(height: 6),
                          Text(
                            isEn
                                ? 'Import a text file (JSON array or CSV list), or build from Favorites/History.'
                                : '导入文本文件（JSON 数组或 CSV 列表），或从收藏/历史记录生成。',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.caption), color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _importFromFile,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: Text(isEn ? 'Import File' : '导入文件'),
                              ),
                              OutlinedButton.icon(
                                onPressed: favoritesCount == 0 ? null : () => _createFromFavorites(appState),
                                icon: const Icon(Icons.bookmark_rounded),
                                label: Text(isEn ? 'From Favorites ($favoritesCount)' : '来自收藏 ($favoritesCount)'),
                              ),
                              OutlinedButton.icon(
                                onPressed: historyCount == 0 ? null : () => _createFromHistory(appState),
                                icon: const Icon(Icons.history_rounded),
                                label: Text(isEn ? 'From History ($historyCount)' : '来自历史 ($historyCount)'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Daily count selector
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEn ? 'Daily Word Count' : '每日单词数量',
                          style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(isEn ? '$_dailyCount words per day' : '每日 $_dailyCount 个单词',
                          style: TextStyle(fontSize: getFont(appState, AppFonts.caption), color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Slider(
                          value: _dailyCount.clamp(sliderMin, sliderMax).toDouble(),
                          min: sliderMin.toDouble(),
                          max: sliderMax.toDouble(),
                          divisions: (sliderMax - sliderMin) == 0 ? null : (sliderMax - sliderMin),
                          label: '$_dailyCount',
                          onChanged: (val) {
                            setState(() {
                              _dailyCount = val.round().clamp(sliderMin, maxCountForList);
                            });
                          },
                          onChangeEnd: (val) => _applyDailyCount(val.round()),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Mode selector
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEn ? 'Learning Mode' : '学习模式',
                          style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          dense: true,
                          value: 0,
                          groupValue: _selectedMode,
                          title: Text(isEn ? 'Sequential' : '顺序学习',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.body))),
                          subtitle: Text(isEn ? 'Learn words in order' : '按顺序学习单词',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.caption))),
                          onChanged: (val) => setState(() => _selectedMode = val!),
                        ),
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          dense: true,
                          value: 1,
                          groupValue: _selectedMode,
                          title: Text(isEn ? 'Random' : '随机学习',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.body))),
                          subtitle: Text(isEn ? 'Learn words in random order' : '随机顺序学习单词',
                            style: TextStyle(fontSize: getFont(appState, AppFonts.caption))),
                          onChanged: (val) => setState(() => _selectedMode = val!),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Register / Unregister buttons
                if (_selectedList != null)
                  FilledButton.icon(
                    onPressed: () async {
                      final appStateRef = context.read<MyAppState>();
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final int listCount = _listCountForKey(_selectedList);
                      final int minVal = (listCount > 0 && listCount < 10) ? listCount : 10;
                      final int maxAllowed = listCount > 0 ? listCount.clamp(minVal, 300) : 300;
                      final int dailyCount = _dailyCount.clamp(minVal, maxAllowed);
                      await DictDatabase.instance.registerVocab(_selectedList!, _selectedMode, dailyCount);
                      await VocabNotificationService.scheduleDailyReminder(appStateRef.langMode);
                      appStateRef.refreshVocabCards();
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(isEn ? 'Vocabulary list registered!' : '单词表注册成功！')),
                        );
                        navigator.pop();
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(isEn ? 'Register & Start' : '注册并开始'),
                  ),

                if (_registration != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final appStateRef = context.read<MyAppState>();
                      final navigator = Navigator.of(context);
                      final confirmed = await showDeleteConfirmationDialog(
                        context,
                        isEn ? 'Unregister' : '取消注册',
                        isEn ? 'This will remove your registration. Progress data will be kept.'
                             : '将取消注册。学习进度数据将保留。',
                        appState,
                      );
                      if (confirmed) {
                        await DictDatabase.instance.unregisterVocab();
                        await VocabNotificationService.cancelReminder();
                        appStateRef.refreshVocabCards();
                        if (mounted) navigator.pop();
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(isEn ? 'Unregister' : '取消注册'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ProgressStats extends StatelessWidget {
  final String listKey;
  final MyAppState appState;
  final bool isEn;
  const _ProgressStats({required this.listKey, required this.appState, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final total = DictDatabase.instance.getVocabTotalWords(listKey);
    final learned = DictDatabase.instance.getVocabLearnedCount(listKey);
    final pct = total > 0 ? (learned / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('$learned / $total ${isEn ? "words learned" : "词已学习"}  (${(pct * 100).toStringAsFixed(1)}%)',
          style: TextStyle(fontSize: getFont(appState, AppFonts.caption), color: Theme.of(context).colorScheme.onPrimaryContainer)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 6,
            backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.2)),
        ),
      ],
    );
  }
}
