import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sqlite_util.dart';
import 'main.dart';
import 'detail_page.dart';

class FavoritesPage extends StatefulWidget {
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool editingMode = false;
  var selected = <int>[];
  bool selectedAll = false;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var favorites = appState.favoriteList;

    return Scaffold(
      appBar: AppBar(
        leading: editingMode ?
        IconButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (selected.isNotEmpty) {
              final confirmed = await showDeleteConfirmationDialog(context, appState.langMode == 0 ? "Are you sure" : "确定要", appState.langMode == 0 ? "to remove ${selected.length} item(s) from the list?" : "从列表中删除 ${selected.length} 个单词吗？", appState);
              if (confirmed) {
                appState.removeFavList(selected);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(appState.langMode == 0 ? "${selected.length} item(s) deleted." : "${selected.length} 个单词已被删除")),
                  );
                }
                setState(() {
                  selected.clear();
                  editingMode = !editingMode;
                });
              }
            } else {
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(appState.langMode == 0 ? "Nothing selected yet!" : "还未选择任何单词！")),
                );
              }
            }
          },
          icon: Icon(Icons.delete)) :
          BackButton(),
        title: Title(color: Theme.of(context).colorScheme.primary, child: Text(appState.langMode == 0 ? "Bookmarks" : "收藏",)),
        actions: [
          favorites.isEmpty ?
          SizedBox.shrink() :
          (editingMode ?
          IconButton(
            onPressed: () {
              setState(() {
                selected.clear();
                editingMode = !editingMode;
              });
            },
            icon: Icon(Icons.done)) :
          IconButton(
            onPressed: (){
              setState(() {
                editingMode = !editingMode;
                selected.clear();
                selectedAll = false;
              });
            },
            icon: Icon(Icons.edit_note)
          )),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.shrink(),
            Expanded(
              child: favorites.isEmpty ?
              Center(
                child: Text(
                  appState.langMode == 0 ? 'Nothing yet..' : '还是空的..',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ) :
              ListView.builder(
                itemCount: editingMode ? favorites.length + 1 : favorites.length,
                itemBuilder: (context, index) {
                  if (editingMode && index == 0) {
                    return ListTile(
                      dense: true,
                      title: Text(selectedAll ? (appState.langMode == 0 ? "Unselect all" : "取消全选") : (appState.langMode == 0 ? "Select all" : "全选"), style: TextStyle(color: Colors.blueGrey),),
                      leading: editingMode ?
                      Icon(
                          selectedAll ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                          size: 16,
                        ) : null,
                      onTap: () {
                        setState(() {
                          if (!selectedAll) {
                            selected.clear();
                            for (int i = 0; i < favorites.length; i++) {
                              selected.add(i);
                            }
                          } else {
                            selected.clear();
                          }
                          selectedAll = !selectedAll;
                        });
                      }
                    );
                  } else {
                    var idx = editingMode ? index - 1 : index;
                    var item = favorites[idx];
                    return ListTile(
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                      dense: true,
                      title: Text(item is EnWordData ? item.word : item.simplified, maxLines: 1, style: TextStyle(fontSize: getFont(appState, 14),)),
                      subtitle: Text(item is EnWordData ? item.translation.join('; ') : item.definitions.join('; '), maxLines: 1, style: TextStyle(fontSize: getFont(appState, 13),)),
                      leading: editingMode ?
                      Icon(
                          selected.contains(idx) ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                          size: 16,
                        ) : null,
                      onTap: () {
                        if (editingMode) {
                          setState(() {
                            if (selected.contains(idx)) {
                              selected.remove(idx);
                            } else {
                              selected.add(idx);
                            }
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => DetailPage(wordData: item,)),
                          );
                        }
                      }
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
