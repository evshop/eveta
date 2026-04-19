import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:eveta/screens/my_orders_screen.dart';
import 'package:eveta/theme/eveta_shop_theme.dart';

/// Pago único por QR tras confirmar el pedido; luego pantalla de éxito y acceso a pedidos.
class CheckoutPaymentScreen extends StatefulWidget {
  const CheckoutPaymentScreen({
    super.key,
    required this.orderIds,
    required this.amountLabel,
  });

  final List<String> orderIds;
  final String amountLabel;

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> with SingleTickerProviderStateMixin {
  bool _paymentDone = false;
  late final AnimationController _celebrateCtrl;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _popScale = Tween<double>(begin: 0.12, end: 1).animate(
      CurvedAnimation(parent: _celebrateCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _celebrateCtrl.dispose();
    super.dispose();
  }

  String get _qrPayload {
    final map = <String, dynamic>{
      'app': 'eveta',
      'type': 'order_pay',
      'orderIds': widget.orderIds,
      'amount': widget.amountLabel,
    };
    return jsonEncode(map);
  }

  void _onMarkPaid() {
    setState(() => _paymentDone = true);
    _celebrateCtrl.forward(from: 0);
  }

  Future<void> _openMyOrders() async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MyOrdersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _paymentDone ? 'Listo' : 'Pago con QR',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _paymentDone
            ? _SuccessBody(
                key: const ValueKey('success'),
                scale: _popScale,
                opacity: _celebrateCtrl,
                onViewOrders: _openMyOrders,
                scheme: scheme,
                tt: tt,
              )
            : _QrBody(
                key: const ValueKey('qr'),
                qrPayload: _qrPayload,
                amountLabel: widget.amountLabel,
                orderCount: widget.orderIds.length,
                scheme: scheme,
                tt: tt,
                onPaid: _onMarkPaid,
              ),
      ),
    );
  }
}

class _QrBody extends StatelessWidget {
  const _QrBody({
    super.key,
    required this.qrPayload,
    required this.amountLabel,
    required this.orderCount,
    required this.scheme,
    required this.tt,
    required this.onPaid,
  });

  final String qrPayload;
  final String amountLabel;
  final int orderCount;
  final ColorScheme scheme;
  final TextTheme tt;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'El pago de tu pedido es solo por código QR. Escanea con tu app bancaria o billetera.',
            style: tt.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1C1C1E)),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1C1C1E),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Total: $amountLabel',
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: scheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            orderCount == 1 ? '1 pedido registrado' : '$orderCount pedidos registrados',
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onPaid,
              style: FilledButton.styleFrom(
                backgroundColor: EvetaShopColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(
                'Ya completé el pago',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({
    super.key,
    required this.scale,
    required this.opacity,
    required this.onViewOrders,
    required this.scheme,
    required this.tt,
  });

  final Animation<double> scale;
  final Animation<double> opacity;
  final VoidCallback onViewOrders;
  final ColorScheme scheme;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surface,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ScaleTransition(
                scale: scale,
                child: FadeTransition(
                  opacity: opacity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 120, color: scheme.primary),
                      const SizedBox(height: 24),
                      Text(
                        '¡Pago completado!',
                        textAlign: TextAlign.center,
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Tu pedido quedó registrado. Podés ver el estado en Mis pedidos.',
                          textAlign: TextAlign.center,
                          style: tt.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onViewOrders,
                style: FilledButton.styleFrom(
                  backgroundColor: EvetaShopColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: Text(
                  'Ver mis pedidos',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
