import 'package:supabase_flutter/supabase_flutter.dart';

class HomePromotionService {
  static SupabaseClient get _c => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchAllForAdmin() async {
    final rows = await _c
        .from('home_promotion_banners')
        .select('id, image_url, sort_order, is_active, created_at')
        .order('sort_order', ascending: true);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<int> _nextSortOrder() async {
    final row = await _c
        .from('home_promotion_banners')
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    final max = row?['sort_order'];
    if (max is int) return max + 1;
    if (max is num) return max.toInt() + 1;
    return 0;
  }

  static Future<void> insertBanner(String imageUrl) async {
    final order = await _nextSortOrder();
    await _c.from('home_promotion_banners').insert({
      'image_url': imageUrl.trim(),
      'sort_order': order,
      'is_active': true,
    });
  }

  static Future<void> updateActive(String id, bool isActive) async {
    await _c.from('home_promotion_banners').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> deleteBanner(String id) async {
    await _c.from('home_promotion_banners').delete().eq('id', id);
  }

  static Future<void> swapSortOrder(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) async {
    final idA = a['id']?.toString() ?? '';
    final idB = b['id']?.toString() ?? '';
    if (idA.isEmpty || idB.isEmpty) return;
    final oa = a['sort_order'];
    final ob = b['sort_order'];
    final sa = oa is int ? oa : (oa is num ? oa.toInt() : 0);
    final sb = ob is int ? ob : (ob is num ? ob.toInt() : 0);
    final now = DateTime.now().toUtc().toIso8601String();
    await _c.from('home_promotion_banners').update({
      'sort_order': sb,
      'updated_at': now,
    }).eq('id', idA);
    await _c.from('home_promotion_banners').update({
      'sort_order': sa,
      'updated_at': now,
    }).eq('id', idB);
  }
}
