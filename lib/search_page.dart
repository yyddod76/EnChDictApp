import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'detail_page.dart';
import 'sqlite_util.dart';
import 'main.dart';
import 'app_drawer_page.dart';
import 'favorite_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
          ],
        ),
      ),
    );
  }
}

