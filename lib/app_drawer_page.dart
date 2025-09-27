import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'main.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HistoryListView(pageView: false,),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  TextButton.icon(
                    label: Text(appState.langMode == 0 ? "Settings" : "设置", style: TextStyle(fontWeight: FontWeight.bold, fontSize: getFont(appState, 16)),),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsPage()),
                      );
                    },
                    icon: Icon(Icons.settings, ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}