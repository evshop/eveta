import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

class EvetaCouponField extends StatelessWidget {
  const EvetaCouponField({
    super.key,
    required this.controller,
    required this.onApply,
  });

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl + 6),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Código de cupón',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.65), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          FilledButton(
            onPressed: onApply,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EvetaShopDimens.radiusXl),
              ),
            ),
            child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
