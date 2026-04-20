import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/screens/home_screen.dart';
import 'package:eveta/screens/login_screen.dart';
import 'package:eveta/screens/menu_screen.dart';
import 'package:eveta/screens/shopping_cart_screen.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/screens/search_screen.dart';
import 'package:eveta/screens/categories_screen.dart';
import 'package:eveta/screens/wish_list_screen.dart';
import 'package:eveta/screens/complete_profile_screen.dart';
import 'package:flutter/services.dart';
import 'package:eveta/utils/cart_service.dart';
import 'package:eveta/utils/catalog_local_sync.dart';
import 'package:eveta/utils/favorites_service.dart';
import 'package:eveta/utils/auth_service.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';
import 'package:eveta/theme/eveta_theme_controller.dart';
import 'package:eveta/theme/shop_system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquea orientación: solo vertical (portrait).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['NEXT_PUBLIC_SUPABASE_URL']!,
    anonKey: dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY']!,
  );

  await CartService.init();
  await FavoritesService.init();
  await CatalogLocalSync.syncCartAndFavoritesWithCatalog();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: evetaThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'eVeta',
          themeMode: mode,
          theme: EvetaShopTheme.light().copyWith(
            textTheme: EvetaShopTheme.light().textTheme.apply(fontFamily: 'Roboto'),
          ),
          darkTheme: EvetaShopTheme.dark().copyWith(
            textTheme: EvetaShopTheme.dark().textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: const SplashScreen(),
          routes: {
            '/home': (context) => const MyHomePage(),
          },
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final supabaseSession = Supabase.instance.client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    if (supabaseSession == null) {
      // Evita entrar por una preferencia vieja sin sesión real.
      await prefs.remove('isLoggedIn');
      await prefs.remove('userEmail');
    }

    if (mounted) {
      if (supabaseSession != null) {
        final needsCompletion = await AuthService.profileNeedsCompletion();
        if (!mounted) return;
        if (needsCompletion) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CompleteProfileScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MyHomePage()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF22C55E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/eVeta.svg',
              width: 130,
              height: 130,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const Text(
              'eVeta',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageNewState();
}

class _MyHomePageNewState extends State<MyHomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final List<String> _productHistory = [];
  final PageController _pageController = PageController(initialPage: 0);
  final GlobalKey<CategoriesScreenState> _categoriesScreenKey = GlobalKey<CategoriesScreenState>();
  bool _searchOpen = false;
  int _searchSession = 0;
  String? _searchInitialQuery;

  void _onThemeModeChanged() {
    if (mounted) _updateSystemUI();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    evetaThemeMode.addListener(_onThemeModeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSystemUI();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateSystemUI();
      CatalogLocalSync.syncCartAndFavoritesWithCatalog();
    }
  }

  void _updateSystemUI() {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    SystemChrome.setSystemUIOverlayStyle(evetaShopShellOverlayStyle(scheme));
  }

  String? get _selectedProductId => _productHistory.isNotEmpty ? _productHistory.last : null;

  @override
  void dispose() {
    evetaThemeMode.removeListener(_onThemeModeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _showProductDetail(String productId) {
    // Cierra rutas encima (p. ej. "Ver todo" / productos de categoría) para que el detalle
    // se pinte sobre MyHomePage y la navbar sea coherente.
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _searchOpen = false;
      _searchInitialQuery = null;
      _productHistory.add(productId);
    });
  }

  void _closeProductDetail() {
    setState(() {
      if (_productHistory.isNotEmpty) {
        _productHistory.removeLast();
      }
    });
  }

  void _closeAllProductDetails() {
    setState(() {
      _productHistory.clear();
    });
  }

  void _openSearchOverlay({String? initialQuery}) {
    setState(() {
      _searchOpen = true;
      _searchSession++;
      _searchInitialQuery = initialQuery;
    });
  }

  void _closeSearchOverlay() {
    setState(() {
      _searchOpen = false;
      _searchInitialQuery = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedProductId == null && !_searchOpen && _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedProductId != null) {
          _closeProductDetail();
        } else if (_searchOpen) {
          _closeSearchOverlay();
        } else if (_currentIndex != 0) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                if (index == 1) {
                  _categoriesScreenKey.currentState?.reloadFromServer();
                }
              },
              children: [
                HomeScreen(
                  onProductTap: _showProductDetail,
                  onOpenSearch: () => _openSearchOverlay(),
                  onOpenWishlist: () {
                    _closeAllProductDetails();
                    _closeSearchOverlay();
                    _pageController.animateToPage(
                      2,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  onOpenCart: () {
                    _closeAllProductDetails();
                    _closeSearchOverlay();
                    _pageController.animateToPage(
                      3,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                CategoriesScreen(
                  key: _categoriesScreenKey,
                  onProductTap: _showProductDetail,
                  onOpenSearch: () => _openSearchOverlay(),
                  onBottomNavTap: (index) {
                    _closeAllProductDetails();
                    _closeSearchOverlay();
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                WishListScreen(onProductTap: _showProductDetail),
                ShoppingCartScreen(onProductTap: _showProductDetail),
                const MenuScreen(),
              ],
            ),
          if (_searchOpen)
            Positioned.fill(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: SearchScreen(
                  key: ValueKey<int>(_searchSession),
                  initialQuery: _searchInitialQuery,
                  onClose: _closeSearchOverlay,
                  onProductSelected: _showProductDetail,
                ),
              ),
            ),
          if (_selectedProductId != null) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeAllProductDetails,
                child: Container(color: Colors.black54),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: ProductDetailScreen(
                    productId: _selectedProductId!,
                    onClose: _closeProductDetail,
                    onTagTap: (tag) {
                      _closeAllProductDetails();
                      _openSearchOverlay(initialQuery: tag);
                    },
                    onRelatedProductTap: _showProductDetail,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomNavBarWidget(
        currentIndex: _currentIndex,
        onTap: (index) {
          _closeAllProductDetails();
          _closeSearchOverlay();
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    ));
  }
}
