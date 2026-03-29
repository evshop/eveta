import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Proporción del logo de categoría (cuadrado).
const double kCategoryLogoAspectRatio = 1;

/// Proporción típica de banner horizontal (16:9).
const double kCategoryBannerAspectRatio = 16 / 9;

/// Abre el editor de recorte con [aspectRatio] fijo y devuelve los bytes PNG recortados.
Future<Uint8List?> showCategoryImageCropDialog(
  BuildContext context, {
  required Uint8List imageBytes,
  required double aspectRatio,
  required String title,
  required String hint,
}) {
  final cropController = CropController();

  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hint,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 400,
                child: Crop(
                  image: imageBytes,
                  controller: cropController,
                  aspectRatio: aspectRatio,
                  interactive: true,
                  onCropped: (result) {
                    if (result is CropSuccess) {
                      Navigator.of(ctx).pop(result.croppedImage);
                    } else if (result is CropFailure) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No se pudo recortar: ${result.cause}'),
                        ),
                      );
                    }
                  },
                  baseColor: Colors.black,
                  maskColor: Colors.black.withValues(alpha: 0.55),
                  filterQuality: FilterQuality.high,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                    size: 0.88,
                    aspectRatio: aspectRatio,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => cropController.crop(),
                      icon: const Icon(Icons.crop),
                      label: const Text('Recortar y continuar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
