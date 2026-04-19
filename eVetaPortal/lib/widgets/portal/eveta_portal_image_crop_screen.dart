import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import 'portal_haptics.dart';
import 'portal_ios_segmented_control.dart';
import 'portal_tokens.dart';

/// Modo de proporción fija para el recorte (banner portada vs icono cuadrado).
enum EvetaCropAspectMode {
  /// 16:9 horizontal (portada / banner).
  banner,

  /// 1:1 (icono / miniatura).
  icon,
}

/// Pantalla de recorte minimalista (fondo oscuro, marco fijo, pinch + arrastre).
///
/// Tras elegir una imagen, abrir con [open]; solo al pulsar Guardar se exporta el recorte.
class EvetaPortalImageCropScreen extends StatefulWidget {
  const EvetaPortalImageCropScreen({
    super.key,
    required this.imageBytes,
    this.initialMode = EvetaCropAspectMode.icon,
    this.lockToInitialMode = false,
  });

  final Uint8List imageBytes;
  final EvetaCropAspectMode initialMode;

  /// Si es `true`, solo se usa [initialMode]: no se muestra el selector Banner / Icono.
  final bool lockToInitialMode;

  static Future<Uint8List?> open(
    BuildContext context,
    Uint8List bytes, {
    EvetaCropAspectMode initialMode = EvetaCropAspectMode.icon,
    bool lockToInitialMode = false,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (context) => EvetaPortalImageCropScreen(
          imageBytes: bytes,
          initialMode: initialMode,
          lockToInitialMode: lockToInitialMode,
        ),
      ),
    );
  }

  @override
  State<EvetaPortalImageCropScreen> createState() =>
      _EvetaPortalImageCropScreenState();
}

class _EvetaPortalImageCropScreenState extends State<EvetaPortalImageCropScreen> {
  static const double _cropRadius = 14;
  static const Color _canvasBg = Color(0xFF0A0A0B);

  late final CropController _controller = CropController();
  late EvetaCropAspectMode _mode;

  CropStatus _status = CropStatus.nothing;
  bool _saveBusy = false;

  double get _aspectRatio =>
      _mode == EvetaCropAspectMode.banner ? 16 / 9 : 1.0;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  void _onModeChanged(EvetaCropAspectMode mode) {
    if (widget.lockToInitialMode) return;
    if (mode == _mode) return;
    setState(() => _mode = mode);
    portalHapticSelect();
    // Un solo [Crop]: el controlador ajusta el marco sin duplicar el widget
    // (evita dos delegados en el mismo [CropController]).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.aspectRatio =
          mode == EvetaCropAspectMode.banner ? 16 / 9 : 1.0;
    });
  }

  void _onCancel() {
    portalHapticSelect();
    Navigator.of(context).pop<Uint8List>(null);
  }

  void _onSave() {
    if (_status != CropStatus.ready || _saveBusy) return;
    portalHapticSelect();
    setState(() => _saveBusy = true);
    _controller.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop<Uint8List>(croppedImage);
      case CropFailure(:final cause):
        setState(() => _saveBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo recortar: $cause')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: _canvasBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _onCancel,
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                Text(
                  'Recortar',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: (_status == CropStatus.ready && !_saveBusy)
                        ? _onSave
                        : null,
                    child: AnimatedOpacity(
                      duration: PortalTokens.motionFast,
                      opacity: (_status == CropStatus.ready && !_saveBusy)
                          ? 1
                          : 0.4,
                      child: Text(
                        _saveBusy ? '…' : 'Guardar',
                        style: TextStyle(
                          color: const Color(0xFF64B5F6),
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _controller,
              aspectRatio: _aspectRatio,
              initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                size: 1.0,
                aspectRatio: _aspectRatio,
              ),
              interactive: true,
              fixCropRect: true,
              baseColor: _canvasBg,
              maskColor: Colors.black.withValues(alpha: 0.52),
              radius: _cropRadius,
              filterQuality: FilterQuality.high,
              cornerDotBuilder: (_, __) => const SizedBox.shrink(),
              overlayBuilder: (context, rect) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_cropRadius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.42),
                      width: 1,
                    ),
                  ),
                  child: const SizedBox.expand(),
                );
              },
              onStatusChanged: (s) {
                if (!mounted) return;
                setState(() {
                  _status = s;
                  if (s != CropStatus.cropping) _saveBusy = false;
                });
              },
              onCropped: _onCropped,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PortalTokens.space2,
              8,
              PortalTokens.space2,
              PortalTokens.space2,
            ),
            child: Theme(
              data: ThemeData(
                brightness: Brightness.dark,
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF64B5F6),
                  brightness: Brightness.dark,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.lockToInitialMode) ...[
                    PortalIosSegmentedControl<EvetaCropAspectMode>(
                      segments: const [
                        PortalSegment(
                          value: EvetaCropAspectMode.banner,
                          label: 'Banner 16:9',
                        ),
                        PortalSegment(
                          value: EvetaCropAspectMode.icon,
                          label: 'Icono 1:1',
                        ),
                      ],
                      selected: _mode,
                      onChanged: _onModeChanged,
                    ),
                    const SizedBox(height: 10),
                  ],
                  AnimatedSwitcher(
                    duration: PortalTokens.motionNormal,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Text(
                      _mode == EvetaCropAspectMode.banner
                          ? 'Portada horizontal 16:9 · pellizca y arrastra para encuadrar.'
                          : 'Miniatura cuadrada 1:1 · pellizca y arrastra para encuadrar.',
                      key: ValueKey<EvetaCropAspectMode>(_mode),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.38),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
