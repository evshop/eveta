class ShopModel {
  final bool success;
  final String message;
  final int count;
  final List<Data> data;

  const ShopModel({
    required this.success,
    required this.message,
    required this.count,
    required this.data,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'];
    return ShopModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      count: json['count'] is int
          ? json['count'] as int
          : int.tryParse(json['count']?.toString() ?? '') ?? 0,
      data: dataJson is List
          ? dataJson
              .whereType<Map>()
              .map((v) => Data.fromJson(v.cast<String, dynamic>()))
              .toList()
          : <Data>[],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    data['message'] = message;
    data['count'] = count;
    data['data'] = this.data.map((v) => v.toJson()).toList();
    return data;
  }
}

class Data {
  final String slug;
  final String contactNumber;
  final String shopName;
  final String shopImage;
  final int approval;
  final String ownerName;

  const Data({
    required this.slug,
    required this.contactNumber,
    required this.shopName,
    required this.shopImage,
    required this.approval,
    required this.ownerName,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    return Data(
      slug: json['slug']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      shopName: json['shop_name']?.toString() ?? '',
      shopImage: json['shop_image']?.toString() ?? '',
      approval: json['approval'] is int
          ? json['approval'] as int
          : int.tryParse(json['approval']?.toString() ?? '') ?? 0,
      ownerName: json['owner_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['slug'] = slug;
    data['contact_number'] = contactNumber;
    data['shop_name'] = shopName;
    data['shop_image'] = shopImage;
    data['approval'] = approval;
    data['owner_name'] = ownerName;
    return data;
  }
}
