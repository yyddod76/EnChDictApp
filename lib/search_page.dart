import 'dart:async';
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
    final newItems = db.search(_searchWord, _pageSize, offset: _offset);
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

  void _loadBannerAd() {
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
          print('Failed to load a banner ad: ${err.message}');
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
    if (appState.searchWord.isNotEmpty) {
      setState(() {
        _textController.text = appState.searchWord;
        _isSearching = true;
        _offset = 0;
        filteredItems.clear();
        _loadMore();
      });
    }
    // filteredItems = isCurrent ? db.search(_searchWord, _pageSize,) : []; // only search word when page is active

    return Scaffold(
      drawer: AppDrawer(),
      resizeToAvoidBottomInset: true,
      appBar: _isSearching ? null : AppBar(
        title: const Text('Dictionary 英汉字典', style: TextStyle(fontSize: 18),),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          }
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritesPage()),
              );
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blueGrey, width: 2.0), // focused
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey, width: 1.0), // unfocused
                        ),
                        isDense: true, // tighter spacing
                        prefixIcon: _isSearching
                            ? IconButton(
                                icon: const BackButtonIcon(),
                                onPressed: () {
                                  _exitSearch(appState);
                                },
                              ) :
                            Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear),
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
                        }); // Refresh UI
                        _debounceTimer = Timer(const Duration(seconds: 10), () {
                          appState.addHistList(_searchWord);
                        });
                      },
                    ),
                  ),
                  if (_textController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.keyboard_hide),
                      onPressed: () {_hideKeyboard(); print("appState.noAdsMode = ${appState.noAdsMode}");},
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
                    title: Text(index == 0 ? (appState.langMode == 0 ? 'Check GPT for "$_searchWord"' : '尝试GPT解释 "$_searchWord"') : (appState.langMode == 0 ? 'Google search "$_searchWord"' : 'Google 查询 "$_searchWord"')),
                    leading: Icon(index == 0 ? Icons.public : Icons.search),
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
                        icon: Icon(favorites.contains(filteredItems[index]) ? Icons.bookmark : Icons.bookmark_border, size: getFont(appState, 14),),
                        onPressed: () {
                          if (!favorites.contains(filteredItems[index])) {
                            appState.addHistList(mainTitle);
                          }
                          appState.toggleFavList(filteredItems[index]);
                        },
                      ),
                      title: Text(mainTitle, maxLines: 1, style: TextStyle(fontSize: getFont(appState, 14),)),
                      subtitle: Text(subTitle, maxLines: 1, style: TextStyle(fontSize: getFont(appState, 13),)),
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

