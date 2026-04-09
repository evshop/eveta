class ProductDetails {
  final bool success;
  final String message;
  final Data data;

  const ProductDetails({
    required this.success,
    required this.message,
    required this.data,
  });

  factory ProductDetails.fromJson(Map<String, dynamic> json) {
    return ProductDetails(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map
          ? Data.fromJson((json['data'] as Map).cast<String, dynamic>())
          : const Data(
              attributes: <Attributes>[],
              productVariants: <ProductVariants>[],
              productSpecifications: <ProductSpecifications>[],
            ),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['success'] = success;
    data['message'] = message;
    data['data'] = this.data.toJson();
    return data;
  }
}

class Data {
  final List<Attributes> attributes;
  final List<ProductVariants> productVariants;
  final List<ProductSpecifications> productSpecifications;

  const Data({
    required this.attributes,
    required this.productVariants,
    required this.productSpecifications,
  });

  factory Data.fromJson(Map<String, dynamic> json) {
    final attributesJson = json['attributes'];
    final variantsJson = json['product_variants'];
    final specsJson = json['product_specifications'];

    return Data(
      attributes: attributesJson is List
          ? attributesJson
              .whereType<Map>()
              .map((v) => Attributes.fromJson(v.cast<String, dynamic>()))
              .toList()
          : <Attributes>[],
      productVariants: variantsJson is List
          ? variantsJson
              .whereType<Map>()
              .map((v) => ProductVariants.fromJson(v.cast<String, dynamic>()))
              .toList()
          : <ProductVariants>[],
      productSpecifications: specsJson is List
          ? specsJson
              .whereType<Map>()
              .map((v) =>
                  ProductSpecifications.fromJson(v.cast<String, dynamic>()))
              .toList()
          : <ProductSpecifications>[],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['attributes'] = attributes.map((v) => v.toJson()).toList();
    data['product_variants'] = productVariants.map((v) => v.toJson()).toList();
    data['product_specifications'] =
        productSpecifications.map((v) => v.toJson()).toList();
    return data;
  }
}

class Attributes {
  final String attributeSlug;
  final String attributeName;
  final List<AttributeValues> attributeValues;

  const Attributes({
    required this.attributeSlug,
    required this.attributeName,
    required this.attributeValues,
  });

  factory Attributes.fromJson(Map<String, dynamic> json) {
    final valuesJson = json['attribute_values'];
    return Attributes(
      attributeSlug: json['attribute_slug']?.toString() ?? '',
      attributeName: json['attribute_name']?.toString() ?? '',
      attributeValues: valuesJson is List
          ? valuesJson
              .whereType<Map>()
              .map((v) => AttributeValues.fromJson(v.cast<String, dynamic>()))
              .toList()
          : <AttributeValues>[],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['attribute_slug'] = attributeSlug;
    data['attribute_name'] = attributeName;
    data['attribute_values'] = attributeValues.map((v) => v.toJson()).toList();
    return data;
  }
}

class AttributeValues {
  final String value;
  final int key;

  const AttributeValues({
    required this.value,
    required this.key,
  });

  factory AttributeValues.fromJson(Map<String, dynamic> json) {
    return AttributeValues(
      value: json['value']?.toString() ?? '',
      key: json['key'] is int
          ? json['key'] as int
          : int.tryParse(json['key']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['value'] = value;
    data['key'] = key;
    return data;
  }
}

class ProductVariants {
  final String sku;
  final int variantId;
  final String productName;
  final int approved;
  final dynamic minPrice;
  final dynamic maxPrice;
  final String productDescription;
  final String brandName;
  final String brandSlug;
  final String categorySlug;
  final int categoryId;
  final String categoryName;
  final List<int> attributeValues;
  final List<String> productImages;
  final String colorImage;

  const ProductVariants({
    required this.sku,
    required this.variantId,
    required this.productName,
    required this.approved,
    required this.minPrice,
    required this.maxPrice,
    required this.productDescription,
    required this.brandName,
    required this.brandSlug,
    required this.categorySlug,
    required this.categoryId,
    required this.categoryName,
    required this.attributeValues,
    required this.productImages,
    required this.colorImage,
  });

  factory ProductVariants.fromJson(Map<String, dynamic> json) {
    final attributeValuesJson = json['attribute_values'];
    final productImagesJson = json['product_images'];

    return ProductVariants(
      sku: json['sku']?.toString() ?? '',
      variantId: json['variant_id'] is int
          ? json['variant_id'] as int
          : int.tryParse(json['variant_id']?.toString() ?? '') ?? 0,
      productName: json['product_name']?.toString() ?? '',
      approved: json['approved'] is int
          ? json['approved'] as int
          : int.tryParse(json['approved']?.toString() ?? '') ?? 0,
      minPrice: json['min_price'],
      maxPrice: json['max_price'],
      productDescription: json['product_description']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      brandSlug: json['brand_slug']?.toString() ?? '',
      categorySlug: json['category_slug']?.toString() ?? '',
      categoryId: json['category_id'] is int
          ? json['category_id'] as int
          : int.tryParse(json['category_id']?.toString() ?? '') ?? 0,
      categoryName: json['category_name']?.toString() ?? '',
      attributeValues: attributeValuesJson is List
          ? attributeValuesJson
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .toList()
          : <int>[],
      productImages: productImagesJson is List
          ? productImagesJson.map((e) => e.toString()).toList()
          : <String>[],
      colorImage: json['color_image']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['sku'] = sku;
    data['variant_id'] = variantId;
    data['product_name'] = productName;
    data['approved'] = approved;
    data['min_price'] = minPrice;
    data['max_price'] = maxPrice;
    data['product_description'] = productDescription;
    data['brand_name'] = brandName;
    data['brand_slug'] = brandSlug;
    data['category_slug'] = categorySlug;
    data['category_id'] = categoryId;
    data['category_name'] = categoryName;
    data['attribute_values'] = attributeValues;
    data['product_images'] = productImages;
    data['color_image'] = colorImage;
    return data;
  }
}

class ProductSpecifications {
  final int id;
  final String specificationName;
  final String specificationValue;

  const ProductSpecifications({
    required this.id,
    required this.specificationName,
    required this.specificationValue,
  });

  factory ProductSpecifications.fromJson(Map<String, dynamic> json) {
    return ProductSpecifications(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      specificationName: json['specification_name']?.toString() ?? '',
      specificationValue: json['specification_value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['specification_name'] = specificationName;
    data['specification_value'] = specificationValue;
    return data;
  }
}
