import 'package:carousel_slider/carousel_slider.dart';
import 'package:eveta/common_widget/eveta_carousel_segment_indicator.dart';
import 'package:eveta/common_widget/eveta_cached_image.dart';
import 'package:eveta/utils/cloudinary_image_url.dart';
import 'package:eveta/utils/supabase_service.dart';
import 'package:flutter/material.dart';

/// Carrusel de promociones en inicio: solo URLs desde Supabase (admin).
/// Sin banners activos no muestra nada.
class PromoCarouselWidget extends StatefulWidget {
  const PromoCarouselWidget({super.key});

  @override
  State<PromoCarouselWidget> createState() => _PromoCarouselWidgetState();
}

class _PromoCarouselWidgetState extends State<PromoCarouselWidget> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  final int _autoPlaySeconds = 4;
  late final Future<List<String>> _remoteUrlsFuture;

  @override
  void initState() {
    super.initState();
    _remoteUrlsFuture = SupabaseService.getHomePromotionBannerUrls();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _autoPlaySeconds),
    )..forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth * 0.88;
        final double carouselHeight = cardWidth * 9 / 16;

        return FutureBuilder<List<String>>(
          future: _remoteUrlsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                const SizedBox(height: 10),
                CarouselSlider(
                  options: CarouselOptions(
                    height: carouselHeight,
                    autoPlay: items.length > 1,
                    autoPlayInterval: Duration(seconds: _autoPlaySeconds),
                    autoPlayAnimationDuration: const Duration(milliseconds: 800),
                    autoPlayCurve: Curves.fastOutSlowIn,
                    enlargeCenterPage: true,
                    enlargeFactor: 0.15,
                    viewportFraction: 0.88,
                    onPageChanged: (index, reason) {
                      setState(() => _currentIndex = index);
                      _progressController.forward(from: 0.0);
                    },
                  ),
                  items: items.map((url) {
                    return Builder(
                      builder: (BuildContext context) {
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: EvetaCachedImage(
                              imageUrl: url,
                              delivery: EvetaImageDelivery.promo,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: EvetaCarouselSegmentIndicator(
                    count: items.length,
                    selectedIndex: _currentIndex,
                    progressController: _progressController,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }
}
