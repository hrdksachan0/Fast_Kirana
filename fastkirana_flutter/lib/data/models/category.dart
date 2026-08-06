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

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.parentId,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}