class CategoryModel {
  final String name;
  final String slug;
  final String imageUrl;

  const CategoryModel({
    required this.name,
    required this.slug,
    required this.imageUrl,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
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
