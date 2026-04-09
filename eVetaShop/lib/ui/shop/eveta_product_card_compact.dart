import 'package:flutter/material.dart';
import 'package:eveta/ui/shop/eveta_product_card_modern.dart';

/// Wrapper de ancho fijo para listas horizontales.
class EvetaProductCardCompact extends StatelessWidget {
  const EvetaProductCardCompact({
    super.key,
    required this.product,
    this.width = 148,
    this.onTap,
  });

  final Map<String, dynamic> product;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: EvetaProductCardModern(
        product: product,
        onTap: onTap,
        compact: true,
      ),
    );
  }
}
