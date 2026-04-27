import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// -----------------------------------------------------------------------------
// TODO (eVeta — publicación en Play Store):
// 1. Reemplazar [kPlayStoreEvetaAppUrl] por la URL real de tu ficha en Play Store
//    (Misma base que uses al publicar el package name de esta app).
// 2. Configurar Android App Links / intent-filter para abrir el detalle desde
//    el enlace [httpsProductDeepLink]; hasta entonces el esquema eveta:// sigue
//    siendo válido para pruebas con la APK instalada.
// 3. (Opcional) Mismo host en iOS Universal Links.
// -----------------------------------------------------------------------------

/// Placeholder: sustituir cuando publiques la app en Google Play.
const String kPlayStoreEvetaAppUrl =
    'https://play.google.com/store/apps/details?id=COMPLETAR_PACKAGE_EVETA';

/// Deep link para abrir la pantalla de detalle si la APK está instalada (registrar en AndroidManifest).
String evetaProductDeepLink(String productId) => 'com.eveta.eveta://product/$productId';
String evetaUniversalProductLink(String productId) => 'https://eveta.app/p/$productId';

String _firstImageUrl(Map<String, dynamic> product) {
  final images = product['images'];
  if (images is List && images.isNotEmpty) {
    return images.first.toString();
  }
  if (images is String && images.isNotEmpty) {
    return images;
  }
  return '';
}

String buildProductShareMessage(Map<String, dynamic> product) {
  final name = product['name']?.toString().trim() ?? 'Producto';
  final id = product['id']?.toString() ?? '';
  final priceRaw = product['price']?.toString() ?? '0';
  final priceNum = double.tryParse(priceRaw);
  final priceLine = priceNum != null ? 'Bs ${priceNum.toStringAsFixed(priceNum.truncateToDouble() == priceNum ? 0 : 2)}' : 'Bs $priceRaw';
  final deepLink = evetaUniversalProductLink(id);

  final buf = StringBuffer()
    ..writeln('🛒 *$name*')
    ..writeln('💰 $priceLine')
    ..writeln('')
    ..writeln(deepLink)
    ..writeln('')
    ..writeln('📲 ¿No tienes eVeta? Descárgala:')
    ..writeln(kPlayStoreEvetaAppUrl);

  return buf.toString();
}

Future<void> _shareImagePlusText({
  required BuildContext context,
  required Map<String, dynamic> product,
  required String message,
}) async {
  final renderObject = context.findRenderObject();
  final imageUrl = _firstImageUrl(product);
  if (imageUrl.isEmpty) {
    await Share.share(message);
    return;
  }
  try {
    final res = await http.get(Uri.parse(imageUrl));
    if (res.statusCode != 200) {
      await Share.share(message);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/eveta_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(res.bodyBytes);
    Rect? origin;
    final box = renderObject;
    if (box is RenderBox) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      text: message,
      sharePositionOrigin: origin,
    );
  } catch (_) {
    if (context.mounted) {
      await Share.share(message);
    }
  }
}

/// Hoja inferior: WhatsApp (texto + enlace foto) y opción con imagen adjunta.
Future<void> showProductShareSheet(BuildContext context, Map<String, dynamic> product) async {
  final scheme = Theme.of(context).colorScheme;
  final message = buildProductShareMessage(product);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: scheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Compartir producto',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 26),
                ),
                title: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Adjunta foto + nombre, precio y un solo enlace'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    await _shareImagePlusText(context: context, product: product, message: message);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.share_rounded, color: scheme.onSurface, size: 28),
                ),
                title: const Text('Compartir con imagen', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Menú del sistema (incluye imagen y el mismo enlace)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    await _shareImagePlusText(context: context, product: product, message: message);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
