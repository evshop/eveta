import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'eveta_portal_camera_preview_screen.dart';
import 'portal_haptics.dart';
import 'portal_soft_card.dart';
import 'portal_tokens.dart';

/// Opciones para [EvetaPortalImagePicker.pick].
class EvetaPortalImagePickerOptions {
  const EvetaPortalImagePickerOptions({
    this.title = 'Añadir imágenes',
    this.subtitle,
    this.allowMultiFromGallery = true,
    this.maxFiles = 10,
    this.imageQuality = 85,
    this.maxWidth = 2200.0,
  });

  final String title;
  final String? subtitle;
  final bool allowMultiFromGallery;
  final int maxFiles;
  final int imageQuality;
  final double maxWidth;
}

/// Sheet estilo iOS + flujo cámara con vista previa. Reutilizable en todo el Portal.
class EvetaPortalImagePicker {
  EvetaPortalImagePicker._();

  static String _humanMessage(Object error) {
    if (error is PlatformException) {
      final c = error.code.toLowerCase();
      if (c.contains('camera') || c.contains('permission')) {
        return 'No pudimos usar la cámara. Revisá permisos en Ajustes del dispositivo.';
      }
      if (c.contains('photo') || c.contains('gallery') || c.contains('picker')) {
        return 'No pudimos abrir la galería. Revisá permisos en Ajustes del dispositivo.';
      }
      return 'No se pudo completar la acción. Intentá de nuevo.';
    }
    return 'Algo salió mal. Intentá de nuevo.';
  }

  /// Devuelve una lista de [XFile] o `null` si el usuario cancela por completo.
  static Future<List<XFile>?> pick(
    BuildContext context,
    EvetaPortalImagePickerOptions options,
  ) async {
    final max = options.maxFiles.clamp(1, 99);
    if (max <= 0) return [];

    final source = await _showSourceSheet(context, options);
    if (!context.mounted || source == null) return null;

    final picker = ImagePicker();

    if (source == ImageSource.gallery) {
      try {
        if (options.allowMultiFromGallery && max > 1) {
          final files = await picker.pickMultiImage(
            imageQuality: options.imageQuality,
            maxWidth: options.maxWidth,
            requestFullMetadata: false,
          );
          if (!context.mounted) return null;
          if (files.isEmpty) return null;
          if (files.length > max) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Solo se usan $max foto(s) (límite de esta acción).'),
                ),
              );
            }
            return files.sublist(0, max);
          }
          return files;
        }
        final one = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: options.imageQuality,
          maxWidth: options.maxWidth,
          requestFullMetadata: false,
        );
        if (!context.mounted || one == null) return null;
        return [one];
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_humanMessage(e))),
          );
        }
        return null;
      }
    }

    // Cámara: capturar → vista previa → confirmar o repetir.
    while (context.mounted) {
      XFile? shot;
      try {
        shot = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: options.imageQuality,
          maxWidth: options.maxWidth,
          requestFullMetadata: false,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_humanMessage(e))),
          );
        }
        return null;
      }
      if (!context.mounted || shot == null) return null;

      final dynamic previewResult = await Navigator.of(context).push<dynamic>(
        PageRouteBuilder<dynamic>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (context, animation, secondaryAnimation) =>
              EvetaPortalCameraPreviewScreen(file: shot!),
          transitionsBuilder: (context, anim, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: PortalTokens.motionNormal,
        ),
      );

      if (!context.mounted) return null;
      if (previewResult == null) return null;
      if (previewResult is XFile) return [previewResult];
      if (previewResult == false) continue;
      return null;
    }
    return null;
  }

  static Future<ImageSource?> _showSourceSheet(
    BuildContext context,
    EvetaPortalImagePickerOptions options,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return showGeneralDialog<ImageSource>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: PortalTokens.motionNormal,
      pageBuilder: (ctx, anim, secAnim) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, MediaQuery.paddingOf(ctx).bottom + 12),
            child: Material(
              color: Colors.transparent,
              child: FadeTransition(
                opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(PortalTokens.radiusXl + 4),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            options.title,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          if (options.subtitle != null && options.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              options.subtitle!,
                              style: tt.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          PortalSoftCard(
                            padding: EdgeInsets.zero,
                            radius: PortalTokens.radiusLg + 2,
                            child: Column(
                              children: [
                                _SourceRow(
                                  icon: CupertinoIcons.photo_on_rectangle,
                                  iconBg: scheme.primary.withValues(alpha: 0.14),
                                  iconColor: scheme.primary,
                                  title: 'Galería',
                                  subtitle: options.allowMultiFromGallery && options.maxFiles > 1
                                      ? 'Varias fotos a la vez'
                                      : 'Elegir de tus fotos',
                                  onTap: () {
                                    portalHapticSelect();
                                    Navigator.of(ctx).pop(ImageSource.gallery);
                                  },
                                ),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: scheme.outline.withValues(alpha: 0.1),
                                ),
                                _SourceRow(
                                  icon: CupertinoIcons.camera_fill,
                                  iconBg: scheme.secondary.withValues(alpha: 0.2),
                                  iconColor: scheme.secondary,
                                  title: 'Cámara',
                                  subtitle: 'Vista previa antes de usar',
                                  onTap: () {
                                    portalHapticSelect();
                                    Navigator.of(ctx).pop(ImageSource.camera);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              portalHapticSelect();
                              Navigator.of(ctx).pop();
                            },
                            child: Text(
                              'Cancelar',
                              style: tt.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) => child,
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PortalTokens.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.25),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_forward, size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
