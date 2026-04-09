import 'package:flutter/material.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

class EvetaOrderSummaryCard extends StatelessWidget {
  const EvetaOrderSummaryCard({
    super.key,
    required this.subtotal,
    required this.shippingLabel,
    required this.shippingAmount,
    required this.discountAmount,
    required this.total,
    required this.ctaLabel,
    required this.onCta,
    this.ctaBusy = false,
    this.couponField,
    /// Si false, no añade [SafeArea] inferior (p. ej. carrito con padding ya reservado para tab bar).
    this.applyBottomSafeArea = true,
  });

  final double subtotal;
  final String shippingLabel;
  final double shippingAmount;
  final double discountAmount;
  final double total;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool ctaBusy;
  final Widget? couponField;
  final bool applyBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomPad = applyBottomSafeArea ? MediaQuery.paddingOf(context).bottom : 0.0;

    final inner = DefaultTextStyle.merge(
      style: TextStyle(color: scheme.onSurface, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
      child: IconTheme.merge(
        data: IconThemeData(color: scheme.onSurfaceVariant),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 14 + bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (couponField != null) ...[
                couponField!,
                const SizedBox(height: 18),
              ],
              _row(context, 'Subtotal', 'Bs ${subtotal.toStringAsFixed(0)}', tt),
              const SizedBox(height: 10),
              _row(context, shippingLabel, 'Bs ${shippingAmount.toStringAsFixed(0)}', tt),
              const SizedBox(height: 10),
              _row(
                context,
                'Descuento',
                discountAmount <= 0 ? 'Bs 0' : '- Bs ${discountAmount.toStringAsFixed(0)}',
                tt,
                valueColor: discountAmount > 0 ? scheme.error : scheme.onSurface,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: scheme.outlineVariant),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                  Text(
                    'Bs ${total.toStringAsFixed(0)}',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: scheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: (ctaBusy || onCta == null) ? null : onCta,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    disabledBackgroundColor: scheme.surfaceContainerHigh,
                    disabledForegroundColor: scheme.onSurfaceVariant,
                  ),
                  child: ctaBusy
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.onPrimary),
                        )
                      : Text(ctaLabel, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.12),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl + 4)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceBright,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(EvetaShopDimens.radiusXl + 4)),
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
            left: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
            right: BorderSide(color: scheme.outline.withValues(alpha: 0.28)),
          ),
        ),
        child: applyBottomSafeArea
            ? SafeArea(top: false, child: inner)
            : inner,
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, TextTheme tt, {Color? valueColor}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
        Text(
          value,
          style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: valueColor ?? scheme.onSurface),
        ),
      ],
    );
  }
}
