import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    return Scaffold(
      appBar: AppBar(title: Text(appState.langMode == 0 ? "Settings" : "设置")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Langauge selector
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appState.langMode == 0 ? "Display language" : "显示语言", style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold)),
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,      // remove left/right padding
                    visualDensity: VisualDensity.comfortable, // shrink vertical space
                    dense: true,                          // make row height smaller
                    title: const Text("English"),
                    value: 0,
                    groupValue: appState.langMode,
                    onChanged: (val) {
                      setState(() => appState.setLangMode(val!));
                    },
                  ),
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,      // remove left/right padding
                    visualDensity: VisualDensity.comfortable, // shrink vertical space
                    dense: true,                          // make row height smaller
                    title: const Text("中文"),
                    value: 1,
                    groupValue: appState.langMode,
                    onChanged: (val) {
                      setState(() => appState.setLangMode(val!));
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Theme selector
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appState.langMode == 0 ? "Theme" : "主题风格", style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownMenu<int>(
                    initialSelection: appState.modeId,
                    onSelected: (value) {
                      if (value != null) setState(() => appState.setThemeMode(value));
                    },
                    dropdownMenuEntries: [
                      DropdownMenuEntry(value: 0, label: appState.langMode == 0 ? "Auto" : "自动"),
                      DropdownMenuEntry(value: 1, label: appState.langMode == 0 ? "Light" : "白天背景"),
                      DropdownMenuEntry(value: 2, label: appState.langMode == 0 ? "Dark" : "夜晚背景"),
                      DropdownMenuEntry(value: 3, label: appState.langMode == 0 ? "Follow System" : "跟随系统"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Font size slider
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appState.langMode == 0 ? "Font Size" : "字体大小", style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text("A", style: TextStyle(fontSize: getFont(appState, AppFonts.navTitle))),
                      Expanded(
                        child: Slider(
                          value: appState.fontSize,
                          min: 0,
                          max: 4,
                          divisions: 4,
                          label: appState.fontName(),
                          onChanged: (value) {
                            setState(() => appState.setFontSize(value));
                          },
                        ),
                      ),
                      Text("A", style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader))),
                    ],
                  ),
                  Text(appState.langMode == 0 ? "Current size: ${appState.fontName()}" : "当前字体：${appState.fontName()}",
                      style: TextStyle(fontSize: getFont(appState, AppFonts.caption), color: Colors.grey[600])),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Remove Ads toggle
          BuyRemoveAdWidget(),
        ],
      ),
    );
  }
}
