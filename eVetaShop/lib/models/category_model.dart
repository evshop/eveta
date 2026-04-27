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
    final icon = json['icon']?.toString().trim() ?? '';
    final banner = json['image_url']?.toString().trim() ?? '';
    return CategoryModel(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      imageUrl: icon.isNotEmpty ? icon : banner,
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
