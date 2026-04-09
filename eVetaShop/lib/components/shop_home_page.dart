import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:eveta/common_widget/circular_progress.dart';
import 'package:eveta/common_widget/grid_tiles_category.dart';
import 'package:eveta/models/shop_model.dart';
import 'package:eveta/utils/urls.dart';
import 'package:http/http.dart' as http;

ShopModel? shopModel;

class ShopHomePage extends StatefulWidget {
  const ShopHomePage({
    super.key,
    required this.slug,
    this.isSubList = false,
  });

  final String slug;
  final bool isSubList;

  @override
  State<ShopHomePage> createState() => _ShopHomePageState();
}

class _ShopHomePageState extends State<ShopHomePage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShopModel>(
      future: getCategoryList(widget.slug, widget.isSubList),
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

Widget createListView(BuildContext context, AsyncSnapshot<ShopModel> snapshot) {
  final values = snapshot.data;
  final results = values?.data ?? <Data>[];
  return GridView.count(
    crossAxisCount: 3,
    padding: const EdgeInsets.all(1.0),
    childAspectRatio: 8.0 / 9.0,
    children: List<Widget>.generate(results.length, (index) {
      return GridTile(
          child: GridTilesCategory(
              name: results[index].shopName,
              imageUrl: results[index].shopImage,
              slug: results[index].slug));
    }),
  );
}

Future<ShopModel> getCategoryList(String slug, bool isSubList) async {
  if (isSubList) {
    shopModel = null;
  }
  if (shopModel == null) {
    final response = await http.get(Uri.parse('${Urls.rootUrl}$slug'));
    final statusCode = response.statusCode;
    final body = jsonDecode(response.body);
    log('$body');
    if (statusCode == 200) {
      shopModel = ShopModel.fromJson(body);
//    brandModel = (body).map((i) =>BrandModel.fromJson(body)) ;
      return shopModel!;
    }
    return const ShopModel(success: false, message: '', count: 0, data: <Data>[]);
  }
  return shopModel!;
}
//https://api.evaly.com.bd/core/public/category/shops/bags-luggage-966bc8aac/?page=1&limit=15
