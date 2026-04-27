import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:eveta/models/category_model.dart';
import 'package:eveta/common_widget/circular_progress.dart';
import 'package:eveta/common_widget/grid_tiles_category.dart';
import 'package:eveta/utils/urls.dart';
import 'package:eveta/utils/catalog_cache_service.dart';
import 'package:http/http.dart' as http;

List<CategoryModel>? categories;

class CategoryPage extends StatefulWidget {
  const CategoryPage({
    super.key,
    required this.slug,
    this.isSubList = false,
  });

  final String slug;
  final bool isSubList;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryModel>>(
      future: getCategoryListFromSupabase(widget.slug, widget.isSubList),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return const CircularProgress();
          default:
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            return createListView(context, snapshot, widget.isSubList);
        }
      },
    );
  }
}

Widget createListView(
    BuildContext context,
    AsyncSnapshot<List<CategoryModel>> snapshot,
    bool isSubList) {
  final values = snapshot.data ?? <CategoryModel>[];
  return LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: GridView.count(
          crossAxisCount: 3,
          //    physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          // Si es subcategoría la hacemos más “delgada” (menos altura por tile).
          childAspectRatio: isSubList ? 1.25 : 8.0 / 9.0,
          children: List<Widget>.generate(values.length, (index) {
            return GridTile(
              child: GridTilesCategory(
                name: values[index].name,
                imageUrl: values[index].imageUrl,
                slug: values[index].slug,
                fromSubProducts: isSubList,
              ),
            );
          }),
        ),
      );
    },
  );
}

Future<List<CategoryModel>> getCategoryListFromSupabase(String slug, bool isSubList) async {
  try {
    final data = await CatalogCacheService.getCategories();

    // En SubCategoryScreen se pasa algo como: "categories/?parent=<parentId>"
    // donde <parentId> es el ID UUID de la categoría padre.
    final parentIdMatch = RegExp(r'parent=([^&]+)').firstMatch(slug);
    final parentId = parentIdMatch?.group(1)?.trim();

    final filtered = parentId == null || parentId.isEmpty
        ? data.where((c) {
            final pid = c['parent_id'];
            return pid == null || pid.toString().trim().isEmpty;
          })
        : data.where((c) => c['parent_id']?.toString() == parentId);

    return filtered
        .map(
          (json) => CategoryModel(
            name: json['name']?.toString() ?? '',
            // Usamos ID como "slug" para que al tocar navegue por category_id.
            slug: json['id']?.toString() ?? '',
            // En eVetaShop la imagen cuadrada de categoría debe ser `icon` (1:1).
            // Si no existe, caemos a `image_url` (banner) o al asset por defecto.
            imageUrl: (() {
              final icon = json['icon']?.toString().trim() ?? '';
              if (icon.isNotEmpty) return icon;
              final banner = json['image_url']?.toString().trim() ?? '';
              if (banner.isNotEmpty) return banner;
              return '';
            })(),
          ),
        )
        .toList();
  } catch (e) {
    debugPrint('Error loading categories from Supabase: $e');
    return [];
  }
}

Future<List<CategoryModel>> getCategoryList(String slug, bool isSubList) async {
  if (isSubList) {
    categories = null;
  }
  if (categories == null) {
    final response = await http.get(Uri.parse('${Urls.rootUrl}$slug'));
    final statusCode = response.statusCode;
    final body = jsonDecode(response.body);
    if (statusCode == 200) {
      categories =
          (body as List).map((i) => CategoryModel.fromJson(i)).toList();

      return categories!;
    }
    categories = <CategoryModel>[];
    return categories!;
  } else {
    return categories!;
  }
}

// https://api.evaly.com.bd/core/public/categories/?parent=bags-luggage-966bc8aac     sub cate by slug
