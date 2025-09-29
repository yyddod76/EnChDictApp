import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'sqlite_util.dart';
import 'search_page.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const envPath = ".env";
  await dotenv.load(fileName: envPath);
  await MobileAds.instance.initialize();
  runApp(
    Provider<DictDatabase>(
      create: (context) => DictDatabase.instance, // Create the database instance
      dispose: (context, db) => db.close(), // Close the database when the app exits
      child: MyApp(db: DictDatabase.instance),
    ),
  );
}

class MyApp extends StatelessWidget {
  final DictDatabase db;
  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(db),
      child: _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();

    return MaterialApp(
      title: 'Dictionary App',
      theme: ThemeData(
        brightness: Brightness.light,
        // primarySwatch:Colors.blueGrey,
        platform: TargetPlatform.android,
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        // primarySwatch:Colors.blueGrey,
        platform: TargetPlatform.android,
        colorSchemeSeed: Colors.blueGrey,
        useMaterial3: true,
      ),
      themeMode: appState.themeMode,
      home: SearchPage(),
    );
  }
}

enum ListTypes {histories, favorites}
class MyAppState extends ChangeNotifier with WidgetsBindingObserver {
  final DictDatabase db;
  Timer? _debounceTimer;
  late Map<String, List<String>> _histList; // history list
  late List<String> _histHiddenVal;
  List<dynamic> _favList = []; // favorite list
  String _searchWord = '';
  final FlutterTts _tts = FlutterTts();

  // theme setting
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  int get modeId => _modeId;
  late int _modeId;
  void setThemeMode(int modeId) {
    _modeId = modeId;
    if (modeId == 0) {
      _themeMode = (DateTime.now().hour >= 19 || DateTime.now().hour < 6) ? ThemeMode.dark : ThemeMode.light;
    } else if (modeId == 1) {
      _themeMode = ThemeMode.light;
    } else if (modeId == 2) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  // display language setting
  late int _langId;
  int get langMode => _langId;
  void setLangMode(int langId) {
    _langId = langId;
    notifyListeners();
  }

  // font size setting
  late double _fontId;
  double get fontSize => _fontId;
  void setFontSize(double fontId) {
    _fontId = fontId;
    notifyListeners();
  }
  String fontName() {
    String ret = "";
    if (_langId == 0) {
      if (_fontId == 0) {
        ret = "smallest";
      } else if (_fontId == 1) {
        ret = "small";
      } else if (_fontId == 2) {
        ret = "normal";
      } else if (_fontId == 3) {
        ret = "large";
      } else if (_fontId == 4) {
        ret = "largest";
      }
    } else {
      if (_fontId == 0) {
        ret = "最小";
      } else if (_fontId == 1) {
        ret = "小";
      } else if (_fontId == 2) {
        ret = "正常";
      } else if (_fontId == 3) {
        ret = "大";
      } else if (_fontId == 4) {
        ret = "最大";
      }
    }
    return ret;
  }

  //no Ads mode flag
  bool _noAdsMode = false;
  bool get noAdsMode => _noAdsMode;
  Future<void> setNoAdsMode(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    _noAdsMode = val;
    await prefs.setBool('isAdsRemoved', val);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _modeId);
    await prefs.setInt('langMode', _langId);
    await prefs.setDouble('fontSize', _fontId);
    await prefs.setStringList('histHiddenVal', _histHiddenVal);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _modeId = prefs.getInt('themeMode') ?? 0;
    _langId = prefs.getInt('langMode') ?? 0;
    _fontId = prefs.getDouble('fontSize') ?? 2;
    _noAdsMode = prefs.getBool('isAdsRemoved') ?? false;
    _histHiddenVal = prefs.getStringList('histHiddenVal') ?? ['false', 'true', 'true', 'true', 'true'];
    setThemeMode(_modeId);
  }

  Map<String, List<String>> get historyList => _histList;
  List<String> get histHiddenVal => _histHiddenVal;
  List<dynamic> get favoriteList => _favList;
  String get searchWord => _searchWord;
  bool get isHistoryEmpty => !(_histList.entries.any((entry) => entry.value.isNotEmpty));

  void setHistHiddenVal(List<bool> vals) {
    for (int i = 0; i < vals.length; i++) {
      _histHiddenVal[i] = vals[i].toString();
    }
    notifyListeners();
  }

  MyAppState(this.db) {
    WidgetsBinding.instance.addObserver(this);
    initFavList();
    _histList = db.histories;
    loadSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      db.refreshFavorites(_favList);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    db.refreshFavorites(_favList);
    _tts.stop();
    saveSettings();
    super.dispose();
  }

  void setSearchWord(String? word) {
    _searchWord = word!.trim();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _searchWord = '';
    });
    notifyListeners();
  }

  void addHistList(String? word) async {
    if (word!.isNotEmpty) {
      await db.updateHistory(word.trim());
      notifyListeners();
    }
  }

  void clearHistList(String key) async {
    await db.clearHistory(key);
    notifyListeners();
  }

  void scheduleDbSync(ListTypes listType) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () async {
      if (listType == ListTypes.favorites) {
        await db.refreshFavorites(_favList);
      }
    });
  }

  void initFavList() {
    _favList.clear();
    _favList.addAll(db.favorites);
  }

  void toggleFavList(dynamic item) {
    if (_favList.contains(item)) {
      _favList.remove(item);
    } else {
      _favList.add(item);
    }

    scheduleDbSync(ListTypes.favorites);
    notifyListeners();
  }

  void removeFavList(List<int> indices) {
    indices.sort((a, b) => b.compareTo(a)); // avoid index shifting
    for (int i in indices) {
      if (i >=0 && i < _favList.length) {
        _favList.removeAt(i);
      }
    }

    scheduleDbSync(ListTypes.favorites);
    notifyListeners();
  }

  void clearFavList() {
    _favList.clear();
    notifyListeners();
  }

  Future<void> trySpeak(String lang, String content) async {
    await _tts.setLanguage(lang); // "en-US" or "zh-CN"
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(0.95);
    await _tts.setPitch(1.05);
    await _tts.speak(content);
  }

  Future<void> tryAbortSpeak() async {
    await _tts.stop();
  }
}

class HomeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      icon: Icon(Icons.restore),
    );
  }
}

Future<bool> showDeleteConfirmationDialog(BuildContext context, String title, String content, MyAppState appState) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(appState.langMode == 0 ? "No" : "否"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
          child: Text(appState.langMode == 0 ? "Yes" : "是"),
        ),
      ],
    ),
  ).then((value) => value ?? false); // default to false if dialog dismissed
}

double getFont(MyAppState appState, double defaultFont, [double a = 2]) => defaultFont + (appState.fontSize - a) * a;

class BuyRemoveAdWidget extends StatefulWidget {
  @override
  State<BuyRemoveAdWidget> createState() => _BuyRemoveAdWidgetState();
}

class _BuyRemoveAdWidgetState extends State<BuyRemoveAdWidget> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  final _removeAdProdID = dotenv.env['REMOVE_AD_PRODUCT_TAG'];

  bool _isPurchasing = false;
  ProductDetails? _removeAdsProduct;
  late MyAppState _appState;

  @override
  void initState() {
    super.initState();
    _initializeProducts();

    _subscription = _iap.purchaseStream.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        // handle error
        print("PurchaseStream error: $error");
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initializeProducts() async {
    final available = await _iap.isAvailable();
    if (!available) {
      // Store not available
      return;
    }
    Set<String> productIds = {_removeAdProdID!};
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      // handle error
      print("ProductDetails query failed: ${response.error}");
    }
    if (response.productDetails.isNotEmpty) {
      setState(() {
        _removeAdsProduct = response.productDetails.first;
      });
    }
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        setState(() => _isPurchasing = true);
      } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        await _appState.setNoAdsMode(true);
        setState(() => _isPurchasing = false);
        // Must complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // handle error
        print("Purchase error: ${purchaseDetails.error}");
      }
    }
  }

  Future<void> _buyRemoveAds() async {
    if (_removeAdsProduct == null) {
      // product not loaded yet
      return;
    }
    final purchaseParam = PurchaseParam(productDetails: _removeAdsProduct!);
    // Non-consumable
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
    // Restored purchases will show up via purchaseStream listener above
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    _appState = appState;
    final messenger = ScaffoldMessenger.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _isPurchasing ? LinearProgressIndicator() : SwitchListTile(
        secondary: IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () async {
              await _restorePurchases();
              if (mounted) {
                if (appState.noAdsMode) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(appState.langMode == 0 ? "No-Ads mode purchase restored!" : "无广告模式购买已还原！")),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text(appState.langMode == 0 ? "Purchase history not found: No-Ads mode" : "暂无购买记录: 无广告模式")),
                  );
                }
              }
            },
            tooltip: appState.langMode == 0 ? "Restore Purchases" : "还原已购项目",
          ),
        title: appState.noAdsMode ?
          Text(appState.langMode == 0 ? "No-Ads mode activated" : "无广告模式已启用", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)) :
          Text("${appState.langMode == 0 ? "No-Ads mode" : "无广告模式"}${_removeAdsProduct == null ? '' : ' \$${_removeAdsProduct!.price}'}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        value: appState.noAdsMode,
        onChanged: appState.noAdsMode ?
        (value) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(content: Text(appState.langMode == 0 ? "No-Ads mode activated, no need to purchase again" : "无广告模式已启用，无需再次购买")),
            );
          }
        } :
        (value) async {
          await _buyRemoveAds();
          if (mounted) {
            if (appState.noAdsMode) {
              messenger.showSnackBar(
                SnackBar(content: Text(appState.langMode == 0 ? "No-Ads mode purchased successful!" : "无广告模式购买成功！")),
              );
            } else {
              messenger.showSnackBar(
                SnackBar(content: Text(appState.langMode == 0 ? "No-Ads mode purchase failed or cancelled.." : "无广告模式购买失败或取消..")),
              );
            }
          }
        },
      ),
    );
  }
}