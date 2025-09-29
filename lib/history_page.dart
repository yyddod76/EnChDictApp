import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';

String switchEnChTitle(String title) {
  String ret = title;
  if (title == 'today') {ret = '今天';}
  else if (title == 'this week') {ret = '这周';}
  else if (title == 'this month') {ret = '这月';}
  else if (title == 'this year') {ret = '今年';}
  else if (title == 'older') {ret = '更早';}
  return ret;
}


class HistoryListView extends StatefulWidget {
  final bool pageView;
  final bool deleteMode;

  HistoryListView({super.key, required this.pageView, required this.deleteMode});

  @override
  State<HistoryListView> createState() => _HistoryListViewState();
}

class _HistoryListViewState extends State<HistoryListView> {
  final Set<String> firstTwo = {'today', 'this week'};
  late MyAppState _appState;
  List<bool> hidden = [true, true, true, true, true];

  @override
  void dispose() {
    _appState.setHistHiddenVal(hidden);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    _appState = appState;
    var histories = widget.pageView ?
      appState.historyList :
      Map.fromEntries(
        appState.historyList.entries.where(
          (entry) => firstTwo.contains(entry.key),
        ),
      );
    if (!widget.deleteMode) {
      hidden = appState.histHiddenVal.map((e) => e.toLowerCase() == 'true').toList();
    }

    return Expanded(
      child:
      appState.isHistoryEmpty ?
      ListView(
        padding: EdgeInsets.all(16),
        children: [
          ListTile(
            subtitle: Text(
              appState.langMode == 0 ? 'Nothing yet..' : '还是空的..',
              style: Theme.of(context).textTheme.titleMedium
            ),
          ),
        ]
      ) :
      ListView.builder(
        itemCount: histories.keys
            .map((k) => 1 + histories[k]!.length)
            .reduce((val, count) => val + count) + 1,
        itemBuilder: (context, index) {
          int runningIndex = 0;
          int keyIndex = 0;
          for (var key in histories.keys) {
            final words = histories[key]!;
            if (index == runningIndex) {
              return 
              words.isEmpty ?
              SizedBox.shrink() :
              TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size(80, 30),
                  padding: EdgeInsets.all(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(appState.langMode == 0 ? key : switchEnChTitle(key), style: TextStyle(fontSize: getFont(appState, 16), fontWeight: FontWeight.bold),),
                    if (widget.deleteMode)
                      IconButton(icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final confirmed = await showDeleteConfirmationDialog(context, appState.langMode == 0 ? "Are you sure" : "确定要", appState.langMode == 0 ? "to clear $key's history items?" : "清理${switchEnChTitle(key)}的历史记录吗？", appState);
                          if (confirmed) {
                            appState.clearHistList(key);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(appState.langMode == 0 ? "History items cleared" : "历史记录已清理")),
                              );
                            }
                            setState(() {});
                          }                          
                        },
                      ),
                  ],
                ),
                onPressed: () {
                  setState(() {
                    hidden[keyIndex] = !hidden[keyIndex];
                  });
                },
              );
            }
            runningIndex++;
            for (int i = 0; i < words.length; i++) {
              if (index == runningIndex) {
                return hidden[keyIndex] ?
                SizedBox.shrink() :
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                  title: Text(words[i], maxLines: 1, style: TextStyle(fontSize: getFont(appState, 14),),),
                  onTap: () {
                    appState.setSearchWord(words[i]);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    Navigator.pop(context); // pop drawer
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(appState.langMode == 0 ? "Searching '${words[i]}'" : "查询 '${words[i]}'")),
                    );
                    appState.addHistList(words[i]);
                  },
                );
              }
              runningIndex++;
            }
            keyIndex++;
          }
          return widget.pageView ?
          SizedBox.shrink() :
          TextButton(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.all(16),
            ),
            child: Text(appState.langMode == 0 ? "more..." : "更多...", style: TextStyle(fontSize: getFont(appState, 14), fontWeight: FontWeight.bold),),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryPage()),
              );
            },
          ); 
        },
      ),
    );
  }
}


class HistoryPage extends StatefulWidget {
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _deleteMode = false;
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: Title(color: Theme.of(context).colorScheme.primary, child: Text(appState.langMode == 0 ? "History" : "历史",)),
        actions: [
          IconButton(
            onPressed: () async {
              setState(() {_deleteMode = !_deleteMode;});
            },
            icon: _deleteMode ?Icon(Icons.done) : Icon(Icons.auto_delete),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HistoryListView(pageView: true, deleteMode: _deleteMode,),
          ],
        ),
      ),
    );
  }
}