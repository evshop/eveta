import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Visor de galería a pantalla completa: sin gestos que compitan con [InteractiveViewer].
class EvetaFullscreenImageViewer extends StatefulWidget {
  const EvetaFullscreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    this.onExit,
  });

  final List<String> imageUrls;
  final int initialIndex;
  final void Function(int index)? onExit;

  @override
  State<EvetaFullscreenImageViewer> createState() => _EvetaFullscreenImageViewerState();
}

class _EvetaFullscreenImageViewerState extends State<EvetaFullscreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final List<TransformationController> _transforms = [];
  Timer? _chromeTimer;
  bool _chromeVisible = true;
  bool _edgeSwipeEnabled = true;
  static const _chromeHideDelay = Duration(seconds: 3);

  Color get _backdrop =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _scheduleHideChrome();
    // Precache current + neighbors to avoid partial renders/flicker.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchAround(_currentIndex);
    });
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _pageController.dispose();
    for (final t in _transforms) {
      t.dispose();
    }
    super.dispose();
  }

  TransformationController _tc(int index) {
    while (_transforms.length <= index) {
      final c = TransformationController();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      _transforms.add(c);
    }
    return _transforms[index];
  }

  double _scaleFor(int index) {
    if (index >= _transforms.length) return 1.0;
    return _transforms[index].value.getMaxScaleOnAxis();
  }

  void _scheduleHideChrome() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(_chromeHideDelay, () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  void _onUserInteraction() {
    setState(() => _chromeVisible = true);
    _scheduleHideChrome();
  }

  void _close() {
    final idx = _currentIndex;
    widget.onExit?.call(idx);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(idx);
    });
  }

  void _toggleZoom(int index, TransformationController c) {
    final s = c.value.getMaxScaleOnAxis();
    if (s > 1.15) {
      c.value = Matrix4.identity();
    } else {
      final size = MediaQuery.sizeOf(context);
      final cx = size.width / 2;
      final cy = size.height / 2;
      c.value = Matrix4.identity()
        ..translateByDouble(cx, cy, 0, 1)
        ..scaleByDouble(2.2, 2.2, 1.0, 1)
        ..translateByDouble(-cx, -cy, 0, 1);
    }
    _onUserInteraction();
  }

  void _onPageChanged(int i) {
    for (var j = 0; j < _transforms.length; j++) {
      if (j != i) {
        _transforms[j].value = Matrix4.identity();
      }
    }
    setState(() => _currentIndex = i);
    _onUserInteraction();
    _prefetchAround(i);
  }

  void _prefetchAround(int index) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) return;
    final candidates = <int>{index, index - 1, index + 1}
        .where((i) => i >= 0 && i < urls.length)
        .toList(growable: false);
    for (final i in candidates) {
      final url = evetaImageDeliveryUrl(urls[i], EvetaImageDelivery.detail);
      precacheImage(CachedNetworkImageProvider(url), context);
    }
  }

  bool _isEdgeSwipeStart(Offset globalPosition) {
    final w = MediaQuery.sizeOf(context).width;
    if (w <= 0) return true;
    final x = globalPosition.dx;
    final edge = w * 0.2; // 20% por cada lado
    return x <= edge || x >= (w - edge);
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    if (urls.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final zoomed = _scaleFor(_currentIndex) > 1.02;

    return Semantics(
      label: 'Galería de fotos, ${urls.length} imágenes',
      child: Scaffold(
        backgroundColor: _backdrop,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: (e) {
                final edge = _isEdgeSwipeStart(e.position);
                if (_edgeSwipeEnabled != edge) {
                  setState(() => _edgeSwipeEnabled = edge);
                }
                _onUserInteraction();
              },
              onPointerUp: (_) {
                if (_edgeSwipeEnabled != true) setState(() => _edgeSwipeEnabled = true);
              },
              onPointerCancel: (_) {
                if (_edgeSwipeEnabled != true) setState(() => _edgeSwipeEnabled = true);
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: urls.length,
                physics: zoomed
                    ? const NeverScrollableScrollPhysics()
                    : (_edgeSwipeEnabled
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics()),
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final ctrl = _tc(index);
                  final zoomedThis = _scaleFor(index) > 1.02;
                  return InteractiveViewer(
                    transformationController: ctrl,
                    minScale: 1.0,
                    maxScale: 4.0,
                    scaleEnabled: true,
                    // Sin zoom: no arrastrar. Con zoom: pan acotado (sin huecos blancos al bordes).
                    panEnabled: zoomedThis,
                    boundaryMargin: EdgeInsets.zero,
                    onInteractionStart: (_) => _onUserInteraction(),
                    onInteractionEnd: (_) => _onUserInteraction(),
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTap: () => _toggleZoom(index, ctrl),
                        child: Material(
                          color: Colors.transparent,
                          child: EvetaCachedImage(
                            imageUrl: urls[index],
                            delivery: EvetaImageDelivery.detail,
                            fit: BoxFit.contain,
                            memCacheWidth: (MediaQuery.sizeOf(context).width *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round()
                                .clamp(900, 1600),
                            errorIconSize: 64,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                child: AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.94)
                              : Colors.black87,
                          size: 22,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.all(12),
                          minimumSize: const Size(48, 48),
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: Colors.transparent,
                        ),
                        onPressed: _close,
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (urls.length > 1)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: AnimatedOpacity(
                    opacity: _chromeVisible ? 1 : 0.85,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 64),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                scrollDirection: Axis.horizontal,
                                shrinkWrap: true,
                                itemCount: urls.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final sel = i == _currentIndex;
                                  final scheme = Theme.of(context).colorScheme;
                                  return GestureDetector(
                                    onTap: () {
                                      if (i == _currentIndex) return;
                                      _onUserInteraction();
                                      _pageController.animateToPage(
                                        i,
                                        duration: const Duration(milliseconds: 280),
                                        curve: Curves.easeOutCubic,
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 48,
                                        height: 48,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: sel
                                              ? [
                                                  BoxShadow(
                                                    color: scheme.primary.withValues(alpha: 0.28),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            EvetaCachedImage(
                                              imageUrl: urls[i],
                                              delivery: EvetaImageDelivery.card,
                                              fit: BoxFit.cover,
                                              memCacheWidth: 160,
                                              errorIconSize: 22,
                                            ),
                                            IgnorePointer(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: sel ? scheme.primary : scheme.outline.withValues(alpha: 0.45),
                                                    width: sel ? 2.2 : 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
