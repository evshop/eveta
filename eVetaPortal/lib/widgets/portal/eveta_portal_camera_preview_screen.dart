import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'portal_tokens.dart';

/// Vista previa a pantalla completa tras capturar con la cámara (estilo iOS).
class EvetaPortalCameraPreviewScreen extends StatelessWidget {
  const EvetaPortalCameraPreviewScreen({super.key, required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.of(context).pop<Object?>(null),
        ),
        title: Text(
          'Vista previa',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la foto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: CupertinoActivityIndicator(radius: 16, color: Colors.white),
            );
          }
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.85,
                    maxScale: 4,
                    child: Image.memory(
                      snap.data!,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _IosStyleSecondaryButton(
                        label: 'Repetir',
                        onPressed: () => Navigator.of(context).pop<bool>(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _IosStylePrimaryButton(
                        label: 'Usar foto',
                        onPressed: () => Navigator.of(context).pop<XFile>(file),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IosStylePrimaryButton extends StatelessWidget {
  const _IosStylePrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0A84FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
    );
  }
}

class _IosStyleSecondaryButton extends StatelessWidget {
  const _IosStyleSecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
    );
  }
}
