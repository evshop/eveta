import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/screens/products_screen.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/screens/sub_category_screen.dart';

class GridTilesCategory extends StatelessWidget {
  const GridTilesCategory({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.slug,
    this.fromSubProducts = false,
  });

  final String name;
  final String imageUrl;
  final String slug;
  final bool fromSubProducts;

  @override
  Widget build(BuildContext context) {
    // Para subcategorías queremos un tile más compacto (menos alto).
    final double tileImageSize = fromSubProducts ? 78 : 100;
    final double tileFontSize = fromSubProducts ? 11 : 12;

    final Widget tileContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        EvetaCachedImage(
          imageUrl: imageUrl,
          delivery: EvetaImageDelivery.card,
          width: tileImageSize,
          height: tileImageSize,
          fit: BoxFit.cover,
          memCacheWidth: 300,
        ),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF000000),
            fontFamily: 'Roboto-Light.ttf',
            fontSize: tileFontSize,
          ),
        ),
      ],
    );

    // Subcategorías: SIN Card, SIN sombras, SIN borderRadius.
    if (fromSubProducts) {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductsScreen(
                slug: "products/?page=1&limit=12&category=$slug",
                name: name,
              ),
            ),
          );
        },
        child: SizedBox(
          width: double.infinity,
          child: Container(
            width: double.infinity,
            color: Colors.white,
            child: tileContent,
          ),
        ),
      );
    }

    // Categorías principales (mantener comportamiento actual).
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubCategoryScreen(
              slug: slug,
            ),
          ),
        );
      },
      child: Card(
        color: Colors.white,
        elevation: 0,
        child: SizedBox(
          width: double.infinity,
          child: tileContent,
        ),
      ),
    );
  }
}
