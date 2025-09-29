import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'sqlite_util.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'main.dart';

class DetailPage extends StatefulWidget {
  final dynamic wordData;
  const DetailPage({
    super.key,
    required this.wordData,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  bool isLoading = false;
  String? onlineContent;
  bool _showMoreContent = false;
  bool _contentLoaded = false;
  late MyAppState _appState;

  Future<void> fetchMoreDetails(String word) async {
    setState(() {
      isLoading = true;
    });

    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception("OpenAI API key not found in .env");
      }

      const endpoint = 'https://api.openai.com/v1/chat/completions';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4.1-nano",
          "messages": [
            {
              "role": "user",
              "content":
                  """Explain word '$word' in English and Chinese in dictionary style, separated by ---"""
            }
          ],
          "temperature": 0.1
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          onlineContent = data['choices'][0]['message']['content'].trim();
          _showMoreContent = true;
          _contentLoaded = true;
        });
      } else {
        setState(() {
          onlineContent = 'Failed to load content.';
          _showMoreContent = true;
        });
      }
    } catch (e) {
      setState(() {
        onlineContent = 'Error fetching details.';
        _showMoreContent = true;
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  void toggleShowMore(String word) {
    if (onlineContent == null) {
      fetchMoreDetails(word);
    } else {
      setState(() {
        _showMoreContent = !_showMoreContent;
      });
    }
  }

  @override
  void dispose() {
    _contentLoaded = false;
    _appState.tryAbortSpeak(); // Stop speaking when widget is disposed
    super.dispose();
  }

  Widget buildOnlineContent(String word, bool isEn, MyAppState appState) {
    if (onlineContent == null) {
      return SizedBox.shrink();
    } else {
      List<String>? contents = onlineContent?.split("---");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(word, style: TextStyle(fontSize: getFont(appState, 20)),),
              SizedBox(width: 36,),
              Text("by OpenAI", style: TextStyle(fontSize: getFont(appState, 10), color: Colors.blueGrey, fontWeight: FontWeight.normal),),
            ],
          ),
          const SizedBox(height: 8),
          if (contents!.isNotEmpty)
            SideButtonText(text: contents[0].replaceAll(RegExp(r'[*]'), ""), alignment: CrossAxisAlignment.end, sideButton: 1, lang: isEn ? "en-US" : "zh-CN", style: TextStyle(fontSize: getFont(appState, 14))),
          if (contents.length > 1)
            SideButtonText(text: contents[1].replaceAll(RegExp(r'[*]'), ""), alignment: CrossAxisAlignment.end, sideButton: 1, lang: isEn ? "zh-CN" : "en-US", style: TextStyle(fontSize: getFont(appState, 14))),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    _appState = appState;
    final dynamic wordData = widget.wordData;
    final bool isEn = wordData is EnWordData;
    final bool isNew = wordData is String;
    final String word = isNew ? wordData : (isEn ? wordData.word : wordData.simplified);

    if (isNew && onlineContent == null) {
      fetchMoreDetails(word);
    }

    return isNew ?
    Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: BackButton(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child:
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading) const CircularProgressIndicator(),
                if (!isLoading) TextButton.icon(
                  label: Text(appState.langMode == 0 ? "Google Search" : "Google 查询"),
                  icon: Icon(Icons.search),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final Uri url = Uri.parse('https://www.google.com/search?q=$word');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text("Could not launch $url")),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text("Error: $e")),
                        );
                      }
                      setState(() {});
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: buildOnlineContent(word, isEn, appState),
                ),
              ],
            ),
        ),
      ),
    ) :
    Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: BackButton(),
        actions: [
          IconButton(
            icon: Icon(appState.favoriteList.contains(wordData) ? Icons.bookmark : Icons.bookmark_border,),
            onPressed: () {
              appState.toggleFavList(wordData);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SideButtonText(
                text: word,
                sideButton: 1,
                style: TextStyle(fontSize: getFont(appState, 20), fontWeight: FontWeight.normal),
                lang: isEn ? "en-US" : "zh-CN",
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  isEn ? (
                    wordData.phonetic == "" ? SizedBox.shrink() : Column(
                      children: [
                        SideButtonText(
                          text: "/${wordData.phonetic}/",
                          sideButton: 0,
                          style: TextStyle(fontSize: getFont(appState, 14), color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ) : (
                    wordData.pinyin == "" ? SizedBox.shrink() : Column(
                      children: [
                        SideButtonText(
                          text: "[${wordData.pinyin}]",
                          sideButton: 0,
                          style: TextStyle(fontSize: getFont(appState, 14), color: Colors.grey, fontWeight: FontWeight.bold),
                        )
                      ],
                    )
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              isEn ? (wordData.definition.isEmpty ? SizedBox.shrink() : Column(
                children: [
                  SideButtonText(text: wordData.definition.join('\n\n'), strList: wordData.definition, alignment: CrossAxisAlignment.start, sideButton: 0, style: TextStyle(fontSize: getFont(appState, 14))),
                  const SizedBox(height: 16),
                ],
              )) : Column(
                children: [
                  SideButtonText(text: wordData.traditional, alignment: CrossAxisAlignment.start, sideButton: 0, style: TextStyle(fontSize: getFont(appState, 14))),
                  const SizedBox(height: 16),
                ],
              ),
              isEn ? (wordData.translation.isEmpty ? SizedBox.shrink() : Column(
                children: [
                  SideButtonText(text: wordData.translation.join('\n\n'), strList: wordData.translation, alignment: CrossAxisAlignment.start, sideButton: 0, style: TextStyle(fontSize: getFont(appState, 14))),
                  const SizedBox(height: 16),
                ],
              )) : (wordData.definitions.isEmpty ? SizedBox.shrink() : Column(
                children: [
                  SideButtonText(text: wordData.definitions.join('\n\n'), sideButton: 0, style: TextStyle(fontSize: getFont(appState, 14))),
                  const SizedBox(height: 16),
                ],
              )),
              const SizedBox(height: 16),

              isEn && wordData.examples.isNotEmpty ?
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Examples",
                      style: TextStyle(fontSize: getFont(appState, 14), color: Colors.blueGrey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        for (int i = 0; i < (wordData.examples.length < 6 ? wordData.examples.length : 5); i++) 
                        SideButtonText(
                          text: wordData.examples[i],
                          sideButton: 1,
                          style: TextStyle(fontSize: getFont(appState, 14))
                          // alignment: CrossAxisAlignment.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ) : SizedBox.shrink(),
              const Divider(),
              const SizedBox(height: 8),

              Row(
                // mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    label: Text(_showMoreContent ? (appState.langMode == 0 ? "Hide AI answer" : "隐藏AI解释") : (_contentLoaded ? (appState.langMode == 0 ? "Show AI answer" : "展开AI解释") : (appState.langMode == 0 ? "Ask AI" : "AI解释")), style: TextStyle(fontSize: getFont(appState, 14)),),
                    icon: Icon(Icons.public),
                    style: TextButton.styleFrom(foregroundColor: Colors.blueGrey,),
                    onPressed: () => {toggleShowMore(word)},
                  ),
                  // SizedBox(width: 24,),
                  _showMoreContent ?
                  SizedBox.shrink():
                  Expanded(
                    child: TextButton.icon(
                      label: Text(appState.langMode == 0 ? "Google Search" : "Google 查询", style: TextStyle(fontSize: getFont(appState, 14))),
                      icon: Icon(Icons.search),
                      style: TextButton.styleFrom(foregroundColor: Colors.blueGrey,),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final Uri url = Uri.parse('https://www.google.com/search?q=$word');
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text("Could not launch $url")),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text("Error: $e")),
                            );
                          }
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              if (isLoading) const CircularProgressIndicator(
                color: Colors.blueGrey,
              ),
              if (_showMoreContent && onlineContent != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: buildOnlineContent(word, isEn, appState),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SideButtonText extends StatefulWidget {
  final String text;
  final int sideButton;
  final TextStyle? style;
  final CrossAxisAlignment? alignment;
  final String? lang;
  final List<String>? strList;

  SideButtonText({
    super.key,
    required this.text,
    required this.sideButton,
    this.style,
    this.alignment,
    this.lang,
    this.strList
  });

  @override
  State<SideButtonText> createState() => _SideButtonTextState();
}

class _SideButtonTextState extends State<SideButtonText> {
  TextSelection? _selection;
  bool _collapsed = true;
  final int hiddenLines = 5;

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    final String textToShow = widget.strList != null ? 
        (_collapsed && widget.strList!.length > hiddenLines
        ? widget.strList!.take(2).toList()
        : widget.strList)!.join('\n\n') :
        widget.text;

    return Column(
      children: [
        Row(
          crossAxisAlignment: widget.alignment ?? CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SelectableText(
                textToShow,
                style: widget.style,
                onSelectionChanged: (selection, cause) { // The callback is called when selection changes
                  setState(() {
                    _selection = (selection.isCollapsed) ? null : selection; // Update the state with the new selection
                  });
                },
                contextMenuBuilder: (context, selectableTextState) {
                  return AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: selectableTextState.contextMenuAnchors,
                    buttonItems: [
                      // Custom button
                      ContextMenuButtonItem(
                        label: appState.langMode == 0 ? 'Look-up' : '查询',
                        onPressed: () {
                          final selectedText = _selection!.textInside(
                            selectableTextState.textEditingValue.text,
                          );
        
                          final trimWord = selectedText
                              .trim()
                              .replaceAll(RegExp(r'''['",.;-]'''), "")
                              .toLowerCase();
        
                          if (trimWord.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Empty selection!")),
                            );
                            return;
                          }
        
                          appState.setSearchWord(trimWord);
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(appState.langMode == 0 ? "Searching '$trimWord'" : "查询 '$trimWord'")),
                          );
        
                          // final db = Provider.of<DictDatabase>(context, listen: false);
                          // final isAlpha = RegExp(r'^[a-zA-Z].*$').hasMatch(selectedText);
        
                          // final results = isAlpha
                          //     ? db.search(trimWord, 1)
                          //     : db.searchCh(trimWord, 1, 0);
        
                          // bool isValid = false;
        
                          // if (results.isNotEmpty) {
                          //   final first = results[0];
        
                          //   if (isAlpha && first is EnWordData) {
                          //     isValid = first.word.toLowerCase() == trimWord;
                          //   } else if (!isAlpha && first is ChWordData) {
                          //     final simp = first.simplified.toLowerCase();
                          //     final trad = first.traditional.toLowerCase();
                          //     isValid = (simp == trimWord || trad == trimWord);
                          //   }
                          // }
        
                          // if (!isValid) {
                          //   ScaffoldMessenger.of(context).showSnackBar(
                          //     SnackBar(content: Text("Not found: $trimWord")),
                          //   );
                          // } else {
                          //   Navigator.push(
                          //     context,
                          //     MaterialPageRoute(
                          //       builder: (context) => DetailPage(wordData: results[0]),
                          //     ),
                          //   );
                          // }
                          appState.addHistList(trimWord);
                        },
                      ),
                      ContextMenuButtonItem(
                        label: appState.langMode == 0 ? 'Ask AI' : 'AI解释',
                        onPressed: () {
                          final selectedText = _selection!.textInside(
                            selectableTextState.textEditingValue.text,
                          );
                          if (selectedText.isNotEmpty) {
                            Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailPage(wordData: selectedText),
                              ),
                            );
                            appState.addHistList(selectedText);
                          }
                        },
                      ),
                      ContextMenuButtonItem(
                        label: 'Google',
                        onPressed: () async {
                          final selectedText = _selection!.textInside(
                            selectableTextState.textEditingValue.text,
                          );
                          if (selectedText.isNotEmpty) {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final Uri url = Uri.parse('https://www.google.com/search?q=$selectedText');
                              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text("Could not launch $url")),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text("Error: $e")),
                                );
                              }
                              setState(() {});
                            }
                            appState.addHistList(selectedText);
                          }
                        },
                      ),
                      // Default buttons
                      ...selectableTextState.contextMenuButtonItems,
                    ],
                  );
                },
              ),
            ),
            widget.sideButton == 0 ?
            SizedBox.shrink() :
            IconButton(
              icon: Icon(Icons.volume_up, color: Colors.blueGrey, size: getFont(appState, 14),),
              tooltip: "Speak",
              onPressed: () {
                appState.trySpeak(widget.lang ?? "en-US", textToShow);
              },
            ),
          ],
        ),

        if (widget.strList != null && widget.strList!.length > hiddenLines)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  _collapsed ? Icons.keyboard_double_arrow_down : Icons.keyboard_double_arrow_up,
                  size: getFont(appState, 14),
                ),
                onPressed: () {
                  setState(() {
                    _collapsed = !_collapsed;
                  });
                },
              ),
            ],
          ),
      ],
    );
  }
}
