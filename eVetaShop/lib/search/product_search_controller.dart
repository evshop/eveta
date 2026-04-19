import 'dart:async';

import 'package:flutter/material.dart';

import 'package:eveta/search/product_search_models.dart';
import 'package:eveta/utils/supabase_service.dart';

/// Sesión de búsqueda: texto con debounce, filtros y resultados. Sin [setState] en la pantalla.
class ProductSearchController extends ChangeNotifier {
  ProductSearchController({String? initialQuery}) {
    if (initialQuery != null && initialQuery.isNotEmpty) {
      textController.text = initialQuery;
      _debouncedQuery = initialQuery.trim();
    }
    textController.addListener(_onTextChanged);
    focusNode.addListener(_onFocusChanged);
    _syncShowResultsPanel();
  }

  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();

  static const Duration debounceDuration = Duration(milliseconds: 300);

  Timer? _debounce;
  String _debouncedQuery = '';
  /// Solo cambia al cruzar el umbral (texto ≥2 o filtros activos), no en cada tecla.
  final ValueNotifier<bool> showResultsPanel = ValueNotifier(false);
  ProductSearchFilters _filters = ProductSearchFilters.initial;
  double _priceSliderMax = kProductSearchPriceSliderFallbackMax;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _productResults = [];
  List<Map<String, dynamic>> _storeResults = [];
  bool _loading = false;
  bool _categoriesLoaded = false;
  bool _priceCeilingLoaded = false;

  String get debouncedQuery => _debouncedQuery;
  ProductSearchFilters get filters => _filters;
  double get priceSliderMax => _priceSliderMax;
  List<Map<String, dynamic>> get categories => List.unmodifiable(_categories);
  List<Map<String, dynamic>> get productResults => List.unmodifiable(_productResults);
  List<Map<String, dynamic>> get storeResults => List.unmodifiable(_storeResults);
  bool get isLoading => _loading;
  bool get categoriesLoaded => _categoriesLoaded;

  void _onFocusChanged() => notifyListeners();

  void _syncShowResultsPanel() {
    final live = textController.text.trim();
    final next = live.length >= 2 || _filters.hasActiveFilters(_priceSliderMax);
    if (showResultsPanel.value != next) {
      showResultsPanel.value = next;
    }
  }

  void _onTextChanged() {
    _syncShowResultsPanel();
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      final next = textController.text.trim();
      if (next == _debouncedQuery) return;
      _debouncedQuery = next;
      notifyListeners();
      unawaited(_runSearch());
    });
  }

  /// Tope del slider: precio máximo del catálogo + 200 Bs, o 1500 si no hay datos.
  Future<void> ensurePriceSliderMax() async {
    if (_priceCeilingLoaded) return;
    try {
      final prevCeiling = _priceSliderMax;
      final prev = _filters;
      final m = await SupabaseService.getMaxActiveProductPrice();
      final next = m != null ? m + 200.0 : kProductSearchPriceSliderFallbackMax;
      _priceSliderMax = next < kProductSearchPriceSliderFallbackMax ? kProductSearchPriceSliderFallbackMax : next;
      // Si el usuario no había acotado el máximo (estaba en “todo el rango” del tope anterior),
      // al cargar el techo real no debe quedar un tope accidental (p. ej. 1500) por debajo del catálogo.
      final wasFullPriceRange = prev.priceMin <= 0.01 && prev.priceMax >= prevCeiling - 0.01;
      _filters = ProductSearchFilters(
        selectedCategoryId: prev.selectedCategoryId,
        priceMin: prev.priceMin.clamp(0, _priceSliderMax),
        priceMax: wasFullPriceRange ? _priceSliderMax : prev.priceMax.clamp(prev.priceMin, _priceSliderMax),
        sort: prev.sort,
      );
      _priceCeilingLoaded = true;
      _syncShowResultsPanel();
      notifyListeners();
    } catch (_) {
      _priceCeilingLoaded = true;
      notifyListeners();
    }
  }

  /// Carga categorías una vez (para chips del filtro).
  Future<void> ensureCategoriesLoaded() async {
    if (_categoriesLoaded) return;
    try {
      _categories = await SupabaseService.getCategories();
      _categoriesLoaded = true;
      notifyListeners();
    } catch (_) {
      _categories = [];
      _categoriesLoaded = true;
      notifyListeners();
    }
  }

  void setFilters(ProductSearchFilters next) {
    if (_filters == next) return;
    _filters = ProductSearchFilters(
      selectedCategoryId: next.selectedCategoryId,
      priceMin: next.priceMin.clamp(0, _priceSliderMax),
      priceMax: next.priceMax.clamp(next.priceMin, _priceSliderMax),
      sort: next.sort,
    );
    _syncShowResultsPanel();
    notifyListeners();
    unawaited(_runSearch());
  }

  void clearText() {
    textController.clear();
    _debouncedQuery = '';
    _debounce?.cancel();
    _syncShowResultsPanel();
    notifyListeners();
    unawaited(_runSearch());
  }

  /// Desde chips de historial: aplica texto y ejecuta búsqueda sin esperar el debounce.
  void applyQueryAndSearch(String raw) {
    final q = raw.trim();
    _debounce?.cancel();
    textController.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    _debouncedQuery = q;
    _syncShowResultsPanel();
    notifyListeners();
    unawaited(_runSearch());
  }

  Future<void> refresh() => _runSearch();

  Future<void> _runSearch() async {
    final q = _debouncedQuery;
    final hasQuery = q.length >= 2;
    final hasFilters = _filters.hasActiveFilters(_priceSliderMax);

    if (!hasQuery && !hasFilters) {
      _productResults = [];
      _storeResults = [];
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final categoryIds = _filters.selectedCategoryId == null || _filters.selectedCategoryId!.isEmpty
          ? null
          : categoryIdsIncludingDescendants(_filters.selectedCategoryId, _categories);

      final products = await SupabaseService.searchProductsAdvanced(
        query: hasQuery ? q : '',
        categoryIds: categoryIds,
        minPrice: _filters.priceMin,
        maxPrice: _filters.priceMax,
        priceFilterCeiling: _priceSliderMax,
        sort: _filters.sort,
      );

      final stores = hasQuery ? await SupabaseService.searchStores(q) : <Map<String, dynamic>>[];

      _productResults = products;
      _storeResults = stores;
    } catch (e) {
      debugPrint('ProductSearchController: $e');
      _productResults = [];
      _storeResults = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    textController.removeListener(_onTextChanged);
    focusNode.removeListener(_onFocusChanged);
    showResultsPanel.dispose();
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
