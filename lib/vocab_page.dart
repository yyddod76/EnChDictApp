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
      } else if (_lists.isNotEmpty) {
        _selectedList = _lists.first.key;
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final bool isEn = appState.langMode == 0;
    final colorScheme = Theme.of(context).colorScheme;

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
                          onChanged: (val) => setState(() => _selectedList = val),
                        )),
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
                      await DictDatabase.instance.registerVocab(_selectedList!, _selectedMode);
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
