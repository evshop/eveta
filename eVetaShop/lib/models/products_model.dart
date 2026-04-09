class ProductsModels {
  final int count;
  final String next;
  final String previous;
  final List<Results> results;

  const ProductsModels({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  factory ProductsModels.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'];
    return ProductsModels(
      count: json['count'] is int
          ? json['count'] as int
          : int.tryParse(json['count']?.toString() ?? '') ?? 0,
      next: json['next']?.toString() ?? '',
      previous: json['previous']?.toString() ?? '',
      results: resultsJson is List
          ? resultsJson
              .whereType<Map>()
              .map((v) => Results.fromJson(v.cast<String, dynamic>()))
              .toList()
          : <Results>[],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['count'] = count;
    data['next'] = next;
    data['previous'] = previous;
    data['results'] = results.map((v) => v.toJson()).toList();
    return data;
  }
}

class Results {
  final String name;
  final String slug;
  final List<String> imageUrls;
  final String priceType;
  final String maxPrice;
  final String minPrice;
  final String minDiscountedPrice;

  const Results({
    required this.name,
    required this.slug,
    required this.imageUrls,
    required this.priceType,
    required this.maxPrice,
    required this.minPrice,
    required this.minDiscountedPrice,
  });

  factory Results.fromJson(Map<String, dynamic> json) {
    final imageUrlsJson = json['image_urls'];
    return Results(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      imageUrls: imageUrlsJson is List
          ? imageUrlsJson.map((e) => e.toString()).toList()
          : <String>[],
      priceType: json['price_type']?.toString() ?? '',
      maxPrice: json['max_price']?.toString() ?? '',
      minPrice: json['min_price']?.toString() ?? '',
      minDiscountedPrice: json['min_discounted_price']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['slug'] = slug;
    data['image_urls'] = imageUrls;
    data['price_type'] = priceType;
    data['max_price'] = maxPrice;
    data['min_price'] = minPrice;
    data['min_discounted_price'] = minDiscountedPrice;
    return data;
  }
}
