import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  /// Segmento aleatorio para `public_id`.
  static String _randomPublicIdSegment() {
    final data = Uint8List.fromList(
      List<int>.generate(18, (_) => Random.secure().nextInt(256)),
    );
    return base64UrlEncode(data).replaceAll('=', '');
  }

  /// Sube imagen a Cloudinary en el [folder] con un `public_id` aleatorio.
  static Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    String? publicId,
  }) async {
    final cloudName = dotenv.env['NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME'] ?? '';
    final uploadPreset =
        dotenv.env['NEXT_PUBLIC_CLOUDINARY_UPLOAD_PRESET'] ?? '';

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw Exception('Faltan variables de Cloudinary en .env');
    }

    final id = publicId ?? _randomPublicIdSegment();

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = id
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Error subiendo imagen a Cloudinary');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = (json['secure_url'] ?? '').toString();
    if (secureUrl.isEmpty) {
      throw Exception('Cloudinary no devolvió URL');
    }

    return secureUrl;
  }
}

