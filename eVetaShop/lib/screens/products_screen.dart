import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:eveta/common_widget/app_bar_widget.dart';
import 'package:eveta/common_widget/circular_progress.dart';
import 'package:eveta/common_widget/grid_tiles_products.dart';
import 'package:eveta/models/products_model.dart';
import 'package:eveta/utils/urls.dart';
import 'package:http/http.dart' as http;

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.name,
    required this.slug,
  });

  final String name;
  final String slug;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWidget(context),
      body: Container(
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.only(left: 10, right: 10),
          child: ProductListWidget(
            slug: widget.slug,
          )),
    );
  }
}

class ProductListWidget extends StatelessWidget {
  const ProductListWidget({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductsModels>(
      future: getProductList(slug, false),
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return const CircularProgress();
          default:
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            return createListView(context, snapshot);
        }
      },
    );
  }
}

ProductsModels? products;

Future<ProductsModels> getProductList(String slug, bool isSubList) async {
  if (isSubList) {
    products = null;
  }
  if (products == null) {
    final response = await http.get(Uri.parse('${Urls.rootUrl}$slug'));
    final statusCode = response.statusCode;
    final body = jsonDecode(response.body);
    if (statusCode == 200) {
      products = ProductsModels.fromJson(body);
      return products!;
    }
    products = const ProductsModels(
      count: 0,
      next: '',
      previous: '',
      results: <Results>[],
    );
    return products!;
  } else {
    return products!;
  }
}

Widget createListView(
    BuildContext context, AsyncSnapshot<ProductsModels> snapshot) {
  final values = snapshot.data;
  final results = values?.results ?? <Results>[];
  return GridView.count(
    crossAxisCount: 2,
//    physics: NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(1.0),
    childAspectRatio: 8.0 / 12.0,
    children: List<Widget>.generate(results.length, (index) {
      return GridTile(
          child: GridTilesProducts(
        name: results[index].name,
        imageUrl:
            results[index].imageUrls.isNotEmpty ? results[index].imageUrls[0] : '',
        slug: results[index].slug,
        price: results[index].maxPrice,
      ));
    }),
  );
}
