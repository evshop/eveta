import 'dart:async';
import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/common_widget/eveta_circular_back_button.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/screens/product_detail_screen.dart';
import 'package:eveta/screens/seller_store_screen.dart';
import 'package:eveta/utils/supabase_service.dart';
import 'package:eveta/utils/page_transitions.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _productResults = [];
  List<Map<String, dynamic>> _storeResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onSearchChanged(widget.initialQuery!);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialQuery == null) {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length < 2) {
        if (mounted) {
          setState(() {
            _productResults = [];
            _storeResults = [];
            _isSearching = false;
          });
        }
        return;
      }

      setState(() {
        _isSearching = true;
      });

      final q = query.trim();
      final results = await Future.wait([
        SupabaseService.searchProducts(q),
        SupabaseService.searchStores(q),
      ]);
      if (mounted) {
        setState(() {
          _productResults = results[0];
          _storeResults = results[1];
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        toolbarHeight: 48,
        automaticallyImplyLeading: false,
        leading: const EvetaCircularBackButton(
          variant: EvetaCircularBackVariant.onDarkBackground,
        ),
        leadingWidth: 56,
        iconTheme: IconThemeData(color: scheme.onPrimary),
        titleSpacing: 8,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            style: TextStyle(fontSize: 14, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Productos o tiendas…',
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
              isDense: true,
              prefixIcon: Icon(
                Icons.search,
                color: scheme.onSurfaceVariant,
                size: 22,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, size: 20, color: scheme.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _productResults = [];
                          _storeResults = [];
                        });
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 10,
              ),
            ),
          ),
        ),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    final scheme = Theme.of(context).colorScheme;

    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }

    if (_searchController.text.trim().length < 2) {
      return Center(
        child: Text(
          'Escribe al menos 2 letras para buscar',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
      );
    }

    if (_productResults.isEmpty && _storeResults.isEmpty) {
      return Center(
        child: Text(
          'No se encontraron resultados',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
      );
    }

    final storeCount = _storeResults.length;
    final productCount = _productResults.length;
    var listItemCount = 0;
    if (storeCount > 0) {
      listItemCount += 1 + storeCount;
    }
    if (productCount > 0) {
      if (storeCount > 0) {
        listItemCount += 1;
      }
      listItemCount += productCount;
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: listItemCount,
      itemBuilder: (context, index) {
        var i = index;
        if (storeCount > 0) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                'Tiendas',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          i -= 1;
          if (i < storeCount) {
            return _buildStoreTile(_storeResults[i]);
          }
          i -= storeCount;
        }
        if (productCount > 0 && storeCount > 0) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                'Productos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          i -= 1;
        }
        final product = _productResults[i];
        final images = product['images'];
        String imageUrl = '';
        if (images is List && images.isNotEmpty) {
          imageUrl = images.first.toString();
        } else if (images is String && images.isNotEmpty) {
          imageUrl = images;
        }

        final name = product['name']?.toString() ?? 'Sin nombre';
        final priceString = product['price']?.toString() ?? '0';
        final price = double.tryParse(priceString) ?? 0;
        final category = product['categories']?['name']?.toString() ?? '';

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              SlideUpPageRoute(
                builder: (context) => ProductDetailScreen(
                  productId: product['id'].toString(),
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  color: scheme.surfaceContainerHigh,
                  child: imageUrl.isEmpty
                      ? Icon(
                          Icons.image_not_supported,
                          color: scheme.onSurfaceVariant,
                        )
                      : EvetaCachedImage(
                          imageUrl: imageUrl,
                          delivery: EvetaImageDelivery.card,
                          fit: BoxFit.contain,
                          memCacheWidth: 200,
                          errorIconSize: 32,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bs ${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoreTile(Map<String, dynamic> store) {
    final scheme = Theme.of(context).colorScheme;
    final shopName = store['shop_name']?.toString().trim() ?? '';
    final fullName = store['full_name']?.toString().trim() ?? '';
    final label = shopName.isNotEmpty
        ? shopName
        : (fullName.isNotEmpty ? fullName : 'Tienda');
    final logoRaw = store['shop_logo_url']?.toString().trim() ?? '';
    final avatarRaw = store['avatar_url']?.toString().trim() ?? '';
    final imageUrl = logoRaw.isNotEmpty ? logoRaw : avatarRaw;

    return InkWell(
      onTap: () {
        final id = store['id']?.toString();
        if (id == null || id.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => SellerStoreScreen(sellerId: id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52,
                height: 52,
                color: scheme.surfaceContainerHigh,
                child: imageUrl.isEmpty
                    ? Icon(
                        Icons.storefront_outlined,
                        color: scheme.onSurfaceVariant,
                        size: 28,
                      )
                    : EvetaCachedImage(
                        imageUrl: imageUrl,
                        delivery: EvetaImageDelivery.card,
                        fit: BoxFit.cover,
                        memCacheWidth: 160,
                        errorIconSize: 28,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
