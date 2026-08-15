import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

@JsonSerializable()
class Category {
  final String id;
  final String name;
  final String slug;
  final String? imageUrl;
  final String? parentId;
  final int sortOrder;
  @JsonKey(name: '_count')
  final CategoryCount? count;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.parentId,
    required this.sortOrder,
    this.count,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);

  int? get productCount => count?.products;
}

@JsonSerializable()
class CategoryCount {
  final int products;
  CategoryCount({required this.products});

  factory CategoryCount.fromJson(Map<String, dynamic> json) =>
      _$CategoryCountFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryCountToJson(this);
}