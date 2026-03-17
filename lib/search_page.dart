import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'detail_page.dart';
import 'sqlite_util.dart';
import 'main.dart';
import 'app_drawer_page.dart';
import 'favorite_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'vocab_page.dart';
import 'vocab_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _pageSize = 100;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  String _searchWord = '';
  // [Fix #5] Track last handled external search word to avoid reacting twice.
  String _lastHandledSearchWord = '';
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  late DictDatabase db;
  List<dynamic> filteredItems = [];
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _searchWord = _textController.text;
      });
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // When the focus is lost, clear the search word
        setState(() {
          _isSearching = true;
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });
    _loadBannerAd();
  }

  Future<void> _loadMore() async {
    setState(() => _isLoading = true);
    final List<dynamic> newItems = db.search(_searchWord, _pageSize, offset: _offset);
    if (newItems.length < _pageSize) {
      _hasMore = false;
    }
    setState(() {
      filteredItems.addAll(newItems);
      _isLoading = false;
      _offset = filteredItems.isNotEmpty ? filteredItems.last.id : 0;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _bannerAd?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadBannerAd() async {
    final bannerUnitId = dotenv.env['GOOGLE_AD_BANNER_UNIT_ID'];
    _bannerAd = BannerAd(
      adUnitId: bannerUnitId!,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() {
          _isAdLoaded = true;
          _bannerAd = ad as BannerAd;
        }),
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('Failed to load a banner ad: ${err.message}');
        },
      ),
    );
    _bannerAd!.load();
  }

  void _exitSearch(MyAppState appState) {
    _textController.clear();
    _focusNode.unfocus();
    setState(() {
      filteredItems.clear();
      _offset = 0;
      appState.setSearchWord('');
      _searchWord = '';
      _isSearching = false; // Reset searching state
    });
    // _focusNode.requestFocus();
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    db = Provider.of<DictDatabase>(context);
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    var appState = context.watch<MyAppState>();
    var favorites = appState.favoriteList;

    // [Fix #5] React to external searchWord without calling setState inside build.
    // addPostFrameCallback defers the setState to after the current frame.
    if (appState.searchWord.isNotEmpty && appState.searchWord != _lastHandledSearchWord) {
      _lastHandledSearchWord = appState.searchWord;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _textController.text = _lastHandledSearchWord;
          setState(() {
            _isSearching = true;
            _offset = 0;
            _hasMore = true;
            filteredItems.clear();
          });
          _loadMore();
        }
      });
    }

    return Scaffold(
      drawer: AppDrawer(),
      resizeToAvoidBottomInset: true,
      appBar: _isSearching ? null : AppBar(
        title: Text(
          appState.langMode == 0 ? 'Dictionary' : '英汉字典',
          style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: appState.langMode == 0 ? 'Vocabulary Study' : '单词学习',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VocabPage()),
              ).then((_) => setState(() {}));
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_rounded),
            tooltip: appState.langMode == 0 ? 'Bookmarks' : '收藏',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritesPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _textController,
                      style: TextStyle(fontSize: getFont(appState, AppFonts.body)),
                      decoration: InputDecoration(
                        hintText: appState.langMode == 0 ? 'Search words...' : '查询单词...',
                        hintStyle: TextStyle(fontSize: getFont(appState, AppFonts.body)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2.0,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        prefixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                onPressed: () => _exitSearch(appState),
                              )
                            : const Icon(Icons.search_rounded),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _textController.clear();
                                  setState(() {
                                    filteredItems.clear();
                                    _offset = 0;
                                    appState.setSearchWord('');
                                    _searchWord = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (text) {
                        _debounceTimer?.cancel();
                        setState(() {
                          if (appState.searchWord.isNotEmpty) {
                            appState.setSearchWord('');
                          }
                          filteredItems.clear();
                          _offset = 0;
                          _hasMore = true;
                          _loadMore();
                        });
                        _debounceTimer = Timer(const Duration(seconds: 10), () {
                          appState.addHistList(_searchWord);
                        });
                      },
                    ),
                  ),
                  if (_textController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.keyboard_hide_rounded),
                      onPressed: _hideKeyboard,
                    ),
                ],
              ),
            ),

            // Vocab section: takes all remaining space when not searching
            if (!_isSearching && appState.vocabRegistration != null)
              Expanded(
                child: appState.todayVocabCards.isEmpty
                    ? _VocabDoneSection(registration: appState.vocabRegistration!, appState: appState)
                    : _VocabCardsSection(
                        cards: appState.todayVocabCards,
                        registration: appState.vocabRegistration,
                        appState: appState,
                      ),
              )
            else ...[
            if (!appState.noAdsMode)
              !_isSearching ? SizedBox.shrink() :
               (_isAdLoaded && _bannerAd != null) ?
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: SizedBox(
                    height: _bannerAd!.size.height.toDouble(),
                    width: _bannerAd!.size.width.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ) : const Text(""),

            Expanded(
              child: (_searchWord != "" && isCurrent && filteredItems.isEmpty) ?
              ListView.builder(itemCount: 2,
              itemBuilder: (context, index) {
                return ListTile(
                    dense: true,
                    title: Text(
                      index == 0 ? (appState.langMode == 0 ? 'Ask AI for "$_searchWord"' : 'AI解释 "$_searchWord"') : (appState.langMode == 0 ? 'Google search "$_searchWord"' : 'Google 查询 "$_searchWord"'),
                      style: TextStyle(fontSize: getFont(appState, AppFonts.body)),
                    ),
                    leading: Icon(
                      index == 0 ? Icons.auto_awesome_rounded : Icons.travel_explore_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: index == 0 ?
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DetailPage(wordData: _searchWord,)),
                      );
                      appState.addHistList(_searchWord);
                    } :
                    () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final Uri url = Uri.parse('https://www.google.com/search?q=$_searchWord');
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
                      appState.addHistList(_searchWord);
                    },
                  );
              },) :
              ListView.builder(
                controller: _scrollController,
                itemCount: filteredItems.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < filteredItems.length) {
                    final String mainTitle = filteredItems[index] is EnWordData ? filteredItems[index].word : (filteredItems[index] as ChWordData).simplified;
                    final String subTitle = filteredItems[index] is EnWordData ? filteredItems[index].translation.join('; ') : (filteredItems[index] as ChWordData).definitions.join('; ');
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                      trailing: IconButton(
                        icon: Icon(
                          favorites.contains(filteredItems[index]) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: getFont(appState, AppFonts.body),
                          color: favorites.contains(filteredItems[index]) ? Theme.of(context).colorScheme.primary : null,
                        ),
                        onPressed: () {
                          if (!favorites.contains(filteredItems[index])) {
                            appState.addHistList(mainTitle);
                          }
                          appState.toggleFavList(filteredItems[index]);
                        },
                      ),
                      title: Text(mainTitle, maxLines: 1, style: TextStyle(fontSize: getFont(appState, AppFonts.body),)),
                      subtitle: Text(subTitle, maxLines: 1, style: TextStyle(fontSize: getFont(appState, AppFonts.caption),)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => DetailPage(wordData: filteredItems[index],)),
                        );
                        appState.addHistList(mainTitle);
                      },
                    );
                  } else {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                },
              ),
            ),
            ], // end else branch
          ],
        ),
      ),
    );
  }
}

class _VocabDoneSection extends StatelessWidget {
  final VocabRegistration registration;
  final MyAppState appState;
  const _VocabDoneSection({required this.registration, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isEn = appState.langMode == 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration_rounded, size: 72, color: colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              isEn ? 'All done for today!' : '今日任务完成！',
              style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isEn
                  ? "You've reviewed today's words from\n${registration.listNameEn}.\nCome back tomorrow for more!"
                  : '「${registration.listNameZh}」今日单词已全部复习完成。\n明天再来继续学习吧！',
              style: TextStyle(fontSize: getFont(appState, AppFonts.body), color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            FilledButton.tonal(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VocabPage()),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.list_alt_rounded, size: getFont(appState, AppFonts.body)),
                const SizedBox(width: 6),
                Text(isEn ? 'Manage List' : '管理单词表'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabCardsSection extends StatefulWidget {
  final List<String> cards;
  final VocabRegistration? registration;
  final MyAppState appState;
  const _VocabCardsSection({required this.cards, required this.registration, required this.appState});
  @override
  State<_VocabCardsSection> createState() => _VocabCardsSectionState();
}

class _VocabCardsSectionState extends State<_VocabCardsSection> {
  final Set<String> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    if (widget.cards.isNotEmpty) {
      _maybeShowHints();
    }
  }

  Future<void> _maybeShowHints() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('vocab_hint_shown') ?? false) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showHintStep(0);
    });
  }

  void _showHintStep(int step) {
    final appState = widget.appState;
    final isEn = appState.langMode == 0;
    final colorScheme = Theme.of(context).colorScheme;

    final titles = isEn ? ['Tip 1 / 2', 'Tip 2 / 2'] : ['提示 1 / 2', '提示 2 / 2'];
    final hints = isEn
        ? [
            'Tap the View (eye) button on a card to reveal its definition.',
            'Tap the  ✓  (tick) button to confirm you recognise the word.\nThe card will fade away and be scheduled for future review.',
          ]
        : [
            '点击卡片上的“查看”按钮显示单词释义。',
            '点击  ✓  按钮确认已记住该单词。\n卡片将渐渐消失，并根据遗忘曲线安排复习。',
          ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.lightbulb_rounded, color: colorScheme.primary, size: getFont(appState, AppFonts.sectionHeader)),
          const SizedBox(width: 8),
          Text(titles[step], style: TextStyle(fontSize: getFont(appState, AppFonts.sectionHeader))),
        ]),
        content: Text(hints[step], style: TextStyle(fontSize: getFont(appState, AppFonts.body))),
        actions: [
          if (step == 0)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showHintStep(1);
              },
              child: Text(isEn ? 'Next' : '下一步'),
            )
          else
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('vocab_hint_shown', true);
              },
              child: Text(isEn ? 'OK' : '好的'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = widget.appState;
    final bool isEn = appState.langMode == 0;
    final colorScheme = Theme.of(context).colorScheme;
    final registration = widget.registration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.local_library_rounded, size: getFont(appState, AppFonts.label), color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                registration != null
                    ? (isEn ? registration.listNameEn : registration.listNameZh)
                    : (isEn ? "Today's Words" : '今日单词'),
                style: TextStyle(fontSize: getFont(appState, AppFonts.caption), fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '${widget.cards.length}',
                  style: TextStyle(fontSize: getFont(appState, AppFonts.tiny), color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            physics: const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 130,
            ),
            itemCount: widget.cards.length,
            itemBuilder: (context, index) {
              final word = widget.cards[index];
              final isExpanded = _expandedCards.contains(word);
              return _VocabFlashCard(
                key: ValueKey(word),
                word: word,
                isExpanded: isExpanded,
                appState: appState,
                onToggleView: () => setState(() {
                  if (isExpanded) {
                    _expandedCards.remove(word);
                  } else {
                    _expandedCards.add(word);
                  }
                }),
                onTick: () {
                  setState(() => _expandedCards.remove(word));
                  context.read<MyAppState>().markVocabCardKnown(word);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VocabFlashCard extends StatefulWidget {
  final String word;
  final bool isExpanded;
  final MyAppState appState;
  final VoidCallback onToggleView;
  final VoidCallback onTick;

  const _VocabFlashCard({
    super.key,
    required this.word,
    required this.isExpanded,
    required this.appState,
    required this.onToggleView,
    required this.onTick,
  });

  @override
  State<_VocabFlashCard> createState() => _VocabFlashCardState();
}

class _VocabFlashCardState extends State<_VocabFlashCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0, // start fully visible
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() {
    _controller.reverse().then((_) {
      if (mounted) widget.onTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appState = widget.appState;
    final EnWordData? data = widget.isExpanded ? DictDatabase.instance.lookupWord(widget.word) : null;
    final String translation = data?.translation.take(2).join('; ') ?? '';
    final String phonetic = data?.phonetic ?? '';

    final double titleFontSize = widget.isExpanded
        ? getFont(appState, AppFonts.body)
        : getFont(appState, AppFonts.wordTitle);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(opacity: _controller.value, child: child),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isExpanded) ...[
                // Word title — top-left when expanded
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      final data = DictDatabase.instance.lookupWord(widget.word);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailPage(wordData: data ?? widget.word)),
                      );
                    },
                    child: Text(
                      widget.word,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                        decorationColor: Theme.of(context).colorScheme.primary,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (phonetic.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    phonetic,
                    style: TextStyle(fontSize: getFont(appState, AppFonts.tiny), color: colorScheme.secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                // Translation area — expands to fill remaining space, clips with ellipsis
                Expanded(
                  child: translation.isNotEmpty
                      ? Text(
                          translation,
                          style: TextStyle(fontSize: getFont(appState, AppFonts.caption), color: colorScheme.onSurface),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(),
                ),
              ] else ...[
                // Word title — centered when collapsed
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        final data = DictDatabase.instance.lookupWord(widget.word);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DetailPage(wordData: data ?? widget.word)),
                        );
                      },
                      child: Text(
                        widget.word,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationStyle: TextDecorationStyle.dotted,
                          decorationColor: Theme.of(context).colorScheme.primary,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
              // Bottom row: view (left) and tick (right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      widget.isExpanded ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: getFont(appState, AppFonts.navTitle),
                      color: colorScheme.primary,
                    ),
                    onPressed: widget.onToggleView,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.check_circle_rounded,
                      size: getFont(appState, AppFonts.navTitle),
                      color: colorScheme.tertiary,
                    ),
                    onPressed: _handleTick,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
