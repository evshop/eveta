import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eveta/common_widget/bottom_nav_bar_widget.dart';
import 'package:eveta/screens/home_screen.dart';
import 'package:eveta/screens/login_screen.dart';
import 'package:eveta/screens/menu_screen.dart';
import 'package:eveta/screens/onboarding_flow_screen.dart';
import 'package:eveta/screens/register_screen.dart';
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

const String _pendingProductDeepLinkKey = 'pending_product_deep_link_id';

String? _extractProductIdFromUri(Uri uri) {
  if (uri.scheme == 'https' && uri.host == 'eveta.app' && uri.pathSegments.length >= 2 && uri.pathSegments.first == 'p') {
    final id = uri.pathSegments[1].trim();
    return id.isEmpty ? null : id;
  }
  if (uri.host != 'product' && (uri.pathSegments.isEmpty || uri.pathSegments.first != 'product')) {
    return null;
  }
  if (uri.host == 'product' && uri.pathSegments.isNotEmpty) {
    final id = uri.pathSegments.first.trim();
    return id.isEmpty ? null : id;
  }
  if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'product') {
    final id = uri.pathSegments[1].trim();
    return id.isEmpty ? null : id;
  }
  return null;
}

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
  await initEvetaThemeMode();

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
            '/login': (context) => const LoginScreen(),
            '/create-account': (context) => const RegisterScreen(),
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
  final AppLinks _appLinks = AppLinks();
  double _logoScale = 0.92;
  double _logoOpacity = 0.0;
  double _scanOpacity = 0.0;
  double _scanY = 0.42;
  bool _hasLottie = false;

  @override
  void initState() {
    super.initState();
    _probeLottie();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _logoScale = 1.0;
        _logoOpacity = 1.0;
      });
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _scanOpacity = 0.75;
          _scanY = 0.56;
        });
      });
      Future.delayed(const Duration(milliseconds: 1750), () {
        if (!mounted) return;
        setState(() => _scanOpacity = 0.0);
      });
    });
    _captureInitialDeepLink();
    _checkLoginStatus();
  }

  Future<void> _probeLottie() async {
    try {
      await rootBundle.load('lib/animation_onboarding/onboarding.json');
      if (!mounted) return;
      setState(() => _hasLottie = true);
    } catch (_) {
      // No JSON aún: usamos SVG + animación Flutter.
    }
  }

  Future<void> _captureInitialDeepLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return;
      final productId = _extractProductIdFromUri(uri);
      if (productId == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingProductDeepLinkKey, productId);
    } catch (_) {
      // Ignora errores de parseo/captura para no bloquear el splash.
    }
  }

  Future<void> _checkLoginStatus() async {
    // Deja correr la animacion SVG de arranque antes de navegar.
    await Future.delayed(const Duration(milliseconds: 4300));

    final supabaseSession = Supabase.instance.client.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool(OnboardingScreen.completedKey) ?? false;
    if (supabaseSession == null) {
      // Evita entrar por una preferencia vieja sin sesión real.
      await prefs.remove('isLoggedIn');
      await prefs.remove('userEmail');
    }

    if (mounted) {
      if (supabaseSession != null) {
        // Bloquea sesión si esta cuenta pertenece a Portal/Delivery.
        try {
          final uid = supabaseSession.id;
          final portal = await Supabase.instance.client
              .from('profiles_portal')
              .select('id')
              .eq('auth_user_id', uid)
              .maybeSingle();
          if (portal != null) {
            await Supabase.instance.client.auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            return;
          }
        } catch (_) {}
        try {
          final uid = supabaseSession.id;
          final delivery = await Supabase.instance.client
              .from('profiles_delivery')
              .select('id')
              .eq('auth_user_id', uid)
              .maybeSingle();
          if (delivery != null) {
            await Supabase.instance.client.auth.signOut();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            return;
          }
        } catch (_) {}

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
        if (onboardingCompleted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          opacity: _logoOpacity,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            scale: _logoScale,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 220),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_hasLottie)
                    Lottie.asset(
                      'lib/animation_onboarding/onboarding.json',
                      fit: BoxFit.contain,
                      repeat: false,
                    )
                  else
                    SvgPicture.asset(
                      'lib/animation_onboarding/onboarding.svg',
                      fit: BoxFit.contain,
                    ),
                  // Scan line (animación simple en Flutter).
                  if (!_hasLottie)
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment(0, _scanY * 2 - 1),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 280),
                        opacity: _scanOpacity,
                        child: Container(
                          width: 320,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.55),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;

  void _onThemeModeChanged() {
    if (mounted) _updateSystemUI();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    evetaThemeMode.addListener(_onThemeModeChanged);
    _consumePendingDeepLink();
    _deepLinkSub = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (_) {});
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
    _deepLinkSub?.cancel();
    evetaThemeMode.removeListener(_onThemeModeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _consumePendingDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingId = prefs.getString(_pendingProductDeepLinkKey)?.trim();
    if (!mounted || pendingId == null || pendingId.isEmpty) return;
    await prefs.remove(_pendingProductDeepLinkKey);
    _showProductDetail(pendingId);
  }

  Future<void> _handleDeepLink(Uri uri) async {
    final productId = _extractProductIdFromUri(uri);
    if (productId == null || productId.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingProductDeepLinkKey, productId);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    if (!mounted) return;
    _showProductDetail(productId);
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
