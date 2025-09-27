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

  HistoryListView({super.key, required this.pageView});

  @override
  State<HistoryListView> createState() => _HistoryListViewState();
}

class _HistoryListViewState extends State<HistoryListView> {

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var histories = appState.historyList;
    List<bool> hidden = appState.histHiddenVal.map((e) => e.toLowerCase() == 'true').toList();

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
              return words.isEmpty ?
              SizedBox.shrink() :
              TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size(80, 30),
                  padding: EdgeInsets.all(16),
                ),
                child: Text(appState.langMode == 0 ? key : switchEnChTitle(key), style: TextStyle(fontSize: getFont(appState, 16), fontWeight: FontWeight.bold),),
                onPressed: () {
                  setState(() {
                    appState.setHistHiddenVal(keyIndex, !hidden[keyIndex]);
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
            child: Text("...", style: TextStyle(fontSize: getFont(appState, 16), fontWeight: FontWeight.bold),),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HistoryPage()),
              );
            },
          ); // last row
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
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showDeleteConfirmationDialog(context, appState.langMode == 0 ? "Are you sure" : "确定要", appState.langMode == 0 ? "to clear history items?" : "清理所有历史记录吗？", appState);
              if (confirmed) {
                appState.clearHistList();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(appState.langMode == 0 ? "All history items cleared." : "所有历史记录已被清理")),
                  );
                }
                setState(() {});
              }
            },
            icon: Icon(Icons.auto_delete)
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HistoryListView(pageView: true,),
          ],
        ),
      ),
    );
  }
}