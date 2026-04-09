class BrandModel {
  final int count;
  final String next;
  final String previous;
  final List<Results> results;

  const BrandModel({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'];
    return BrandModel(
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
  final String imageUrl;

  const Results({
    required this.name,
    required this.slug,
    required this.imageUrl,
  });

  factory Results.fromJson(Map<String, dynamic> json) {
    return Results(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['slug'] = slug;
    data['image_url'] = imageUrl;
    return data;
  }
}
