import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:eveta/common_widget/circular_progress.dart';
import 'package:eveta/common_widget/grid_tiles_category.dart';
import 'package:eveta/utils/urls.dart';
import 'package:http/http.dart' as http;

import '../models/brand_model.dart';

BrandModel? brandModel;

class BrandHomePage extends StatefulWidget {
  const BrandHomePage({
    super.key,
    required this.slug,
    this.isSubList = false,
  });

  final String slug;
  final bool isSubList;

  @override
  State<BrandHomePage> createState() => _BrandHomePageState();
}

class _BrandHomePageState extends State<BrandHomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BrandModel>(
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

Widget createListView(BuildContext context, AsyncSnapshot<BrandModel> snapshot) {
  final values = snapshot.data;
  final results = values?.results ?? <Results>[];
  return GridView.count(
    crossAxisCount: 3,
    padding: const EdgeInsets.all(1.0),
    childAspectRatio: 8.0 / 9.0,
    children: List<Widget>.generate(results.length, (index) {
      return GridTile(
          child: GridTilesCategory(
              name: results[index].name,
              imageUrl: results[index].imageUrl,
              slug: results[index].slug));
    }),
  );
}

Future<BrandModel> getCategoryList(String slug, bool isSubList) async {
  if (brandModel == null) {
    final response = await http.get(Uri.parse('${Urls.rootUrl}$slug'));
    final statusCode = response.statusCode;
    final body = jsonDecode(response.body);
    log('$body');
    if (statusCode == 200) {
      brandModel = BrandModel.fromJson(body);
//    brandModel = (body).map((i) =>BrandModel.fromJson(body)) ;
      return brandModel!;
    }
    return const BrandModel(count: 0, next: '', previous: '', results: <Results>[]);
  }
  return brandModel!;
}

//https://api.evaly.com.bd/core/public/brands/?limit=20&page=1&category=bags-luggage-966bc8aac
