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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MD3 DrawerHeader with app identity
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            color: colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  size: 36,
                  color: colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 10),
                Text(
                  appState.langMode == 0 ? 'Dictionary' : '字典',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  appState.langMode == 0 ? 'English ↔ Chinese' : '英汉互译',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),

          // History list
          HistoryListView(pageView: false, deleteMode: false),

          // Settings button at bottom
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.settings_rounded, color: colorScheme.onSurfaceVariant),
              title: Text(
                appState.langMode == 0 ? 'Settings' : '设置',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: getFont(appState, AppFonts.navTitle),
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
