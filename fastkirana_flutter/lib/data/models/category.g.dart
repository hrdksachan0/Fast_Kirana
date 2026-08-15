// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['imageUrl'] as String?,
      parentId: json['parentId'] as String?,
      sortOrder: (json['sortOrder'] as num).toInt(),
      count: json['_count'] == null
          ? null
          : CategoryCount.fromJson(json['_count'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'imageUrl': instance.imageUrl,
      'parentId': instance.parentId,
      'sortOrder': instance.sortOrder,
      '_count': instance.count,
    };

CategoryCount _$CategoryCountFromJson(Map<String, dynamic> json) =>
    CategoryCount(
      products: (json['products'] as num).toInt(),
    );

Map<String, dynamic> _$CategoryCountToJson(CategoryCount instance) =>
    <String, dynamic>{
      'products': instance.products,
    };
