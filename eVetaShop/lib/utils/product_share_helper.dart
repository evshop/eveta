import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Placeholder si aún no tienes dominio: usa eveta:// en mensajes; más adelante
/// puedes usar https://tudominio.com/p/{id} con App Links.
String httpsProductDeepLink(String productId) =>
    'https://eveta.app/p/$productId'; // TODO: dominio real o borrar si solo usas eveta://

/// Deep link para abrir la pantalla de detalle si la APK está instalada (registrar en AndroidManifest).
String evetaProductDeepLink(String productId) => 'eveta://product/$productId';

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
  final imageUrl = _firstImageUrl(product);

  final deepInApp = evetaProductDeepLink(id);
  final deepHttps = httpsProductDeepLink(id);

  final buf = StringBuffer()
    ..writeln('🛒 *$name*')
    ..writeln('💰 $priceLine')
    ..writeln('')
    ..writeln('Abrir en eVeta (app instalada):')
    ..writeln(deepInApp)
    ..writeln('')
    ..writeln('Enlace web (cuando esté listo):')
    ..writeln(deepHttps)
    ..writeln('')
    ..writeln('📲 ¿No tienes eVeta? Descárgala:')
    ..writeln(kPlayStoreEvetaAppUrl);

  if (imageUrl.isNotEmpty) {
    buf
      ..writeln('')
      ..writeln('📷 Foto:')
      ..writeln(imageUrl);
  }

  return buf.toString();
}

Future<void> _openWhatsAppText(BuildContext context, String message) async {
  final encoded = Uri.encodeComponent(message);
  final whatsapp = Uri.parse('whatsapp://send?text=$encoded');
  final waMe = Uri.parse('https://wa.me/?text=$encoded');

  Future<bool> tryLaunch(Uri u, {LaunchMode mode = LaunchMode.externalApplication}) async {
    try {
      if (await canLaunchUrl(u)) {
        return await launchUrl(u, mode: mode);
      }
    } catch (_) {}
    return false;
  }

  if (await tryLaunch(whatsapp, mode: LaunchMode.externalNonBrowserApplication)) {
    return;
  }
  if (await tryLaunch(waMe)) {
    return;
  }

  final market = Uri.parse('market://details?id=com.whatsapp');
  final storeHttps =
      Uri.parse('https://play.google.com/store/apps/details?id=com.whatsapp');
  if (await tryLaunch(market, mode: LaunchMode.externalApplication)) {
    return;
  }
  if (await tryLaunch(storeHttps)) {
    return;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp ni la tienda. Revisa tu conexión.')),
    );
  }
}

Future<void> _shareImagePlusText({
  required BuildContext context,
  required Map<String, dynamic> product,
  required String message,
}) async {
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
    final box = context.findRenderObject();
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
  const green = Color(0xFF09CB6B);
  final message = buildProductShareMessage(product);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Compartir producto',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 8),
              Text(
                'TODO: cuando publiques eVeta en Play Store, actualiza la URL en product_share_helper.dart',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
              ),
              const SizedBox(height: 20),
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
                subtitle: const Text('Nombre, precio, enlaces y URL de la foto en el texto'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _openWhatsAppText(context, message);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.share_rounded, color: green, size: 28),
                ),
                title: const Text('Compartir con imagen', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Adjunta la foto; elige WhatsApp en el menú del sistema'),
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
