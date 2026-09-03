// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CategoryImpl _$$CategoryImplFromJson(Map<String, dynamic> json) =>
    _$CategoryImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      imageUrl: json['imageUrl'] as String?,
      parentId: json['parentId'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      count: json['_count'] == null
          ? null
          : CategoryCount.fromJson(json['_count'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$CategoryImplToJson(_$CategoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'imageUrl': instance.imageUrl,
      'parentId': instance.parentId,
      'sortOrder': instance.sortOrder,
      '_count': instance.count,
    };

_$CategoryCountImpl _$$CategoryCountImplFromJson(Map<String, dynamic> json) =>
    _$CategoryCountImpl(
      products: (json['products'] as num).toInt(),
    );

Map<String, dynamic> _$$CategoryCountImplToJson(_$CategoryCountImpl instance) =>
    <String, dynamic>{
      'products': instance.products,
    };
