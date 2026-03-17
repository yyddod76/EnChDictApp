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
  final TextEditingController _dailyCountController = TextEditingController();
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
        _dailyCount = _registration!.dailyCount.clamp(10, 100);
      } else if (_lists.isNotEmpty) {
        _selectedList = _lists.first.key;
      }
      _dailyCount = _clampDailyCount(_dailyCount);
      _dailyCountController.text = _dailyCount.toString();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _dailyCountController.dispose();
    super.dispose();
  }

  int _listCountForKey(String? listKey) {
    if (listKey == null) return 100;
    final match = _lists.where((l) => l.key == listKey);
    if (match.isEmpty) return 100;
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
    if (count <= 0) return 100;
    final minVal = _minDailyCount();
    return count.clamp(minVal, 100);
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
      _dailyCountController.text = _dailyCount.toString();
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

  void _handleDailyInputSubmit(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed == null) {
      _dailyCountController.text = _dailyCount.toString();
      return;
    }
    _applyDailyCount(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final bool isEn = appState.langMode == 0;
    final colorScheme = Theme.of(context).colorScheme;
    final int sliderMax = _maxDailyCount();
    final int sliderMin = _minDailyCount();
    final int maxCountForList = sliderMax;

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
                          onChanged: (val) {
                            setState(() => _selectedList = val);
                            if (_registration == null) {
                              _applyDailyCount(_dailyCount);
                            }
                          },
                        )),
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
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _dailyCount.clamp(sliderMin, sliderMax).toDouble(),
                                min: sliderMin.toDouble(),
                                max: sliderMax.toDouble(),
                                divisions: (sliderMax - sliderMin) == 0 ? null : (sliderMax - sliderMin),
                                label: '$_dailyCount',
                                onChanged: (val) {
                                  setState(() {
                                    _dailyCount = val.round().clamp(sliderMin, maxCountForList);
                                    _dailyCountController.text = _dailyCount.toString();
                                  });
                                },
                                onChangeEnd: (val) => _applyDailyCount(val.round()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _dailyCountController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                  labelText: isEn ? 'Count' : '数量',
                                  helperText: isEn ? 'Max $maxCountForList' : '最多 $maxCountForList',
                                ),
                                onSubmitted: _handleDailyInputSubmit,
                                onEditingComplete: () => _handleDailyInputSubmit(_dailyCountController.text),
                              ),
                            ),
                          ],
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
                      final int maxAllowed = listCount > 0 ? listCount.clamp(minVal, 100) : 100;
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
