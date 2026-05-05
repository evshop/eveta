import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Panel inferior deslizable (hasta ~medio pantalla) con detalle del pedido y acciones.
Future<void> showDeliveryOfferBottomSheet(
  BuildContext context, {
  String? productImageUrl,
  required String productLine,
  required String storeName,
  required String buyerName,
  required String deliveryEarningsLabel,
  required String storeToHomeKmLabel,
  required String? driverToPickupKmLabel,
  String? pickupEtaLabel,
  String? originAddress,
  String? destAddress,
  required bool canAccept,
  required VoidCallback onAccept,
  required VoidCallback onChat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.34,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scroll) {
          final scheme = Theme.of(ctx).colorScheme;
          return Material(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: CustomScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (productImageUrl != null && productImageUrl.trim().isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                productImageUrl.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          productLine,
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _detailRow(ctx, 'Tienda', storeName),
                      ),
                      if (originAddress != null && originAddress.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _detailRow(ctx, 'Origen (tienda)', originAddress.trim()),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _detailRow(ctx, 'Cliente', buyerName),
                      ),
                      if (destAddress != null && destAddress.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _detailRow(ctx, 'Entrega', destAddress.trim()),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _detailRow(
                          ctx,
                          'Tu ganancia (delivery)',
                          deliveryEarningsLabel,
                          emphasize: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _detailRow(ctx, 'Distancia ruta', storeToHomeKmLabel),
                      ),
                      if (driverToPickupKmLabel != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            driverToPickupKmLabel,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                      if (pickupEtaLabel != null && pickupEtaLabel.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _detailRow(ctx, 'Tiempo estimado', pickupEtaLabel.trim()),
                        ),
                      ],
                      if (!canAccept) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Acércate al punto de recojo para poder aceptar.',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: canAccept
                                    ? () {
                                        Navigator.of(ctx).pop();
                                        onAccept();
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: CupertinoColors.systemPink,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      scheme.onSurfaceVariant.withValues(alpha: 0.25),
                                ),
                                child: const Text('Aceptar pedido'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  onChat();
                                },
                                icon: const Icon(CupertinoIcons.chat_bubble_2, size: 20),
                                label: const Text('Chat'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  foregroundColor: CupertinoColors.systemPink,
                                  side: const BorderSide(color: CupertinoColors.systemPink, width: 1.2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: MediaQuery.paddingOf(ctx).bottom + 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _detailRow(
  BuildContext context,
  String label,
  String value, {
  bool emphasize = false,
}) {
  final tt = Theme.of(context).textTheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: (emphasize ? tt.titleMedium : tt.bodyLarge)?.copyWith(
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  );
}
