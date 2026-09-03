import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
class Category with _$Category {
  const Category._();

  const factory Category({
    required String id,
    required String name,
    required String slug,
    String? imageUrl,
    String? parentId,
    @Default(0) int sortOrder,
    @JsonKey(name: '_count') CategoryCount? count,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  int? get productCount => count?.products;
}

@freezed
class CategoryCount with _$CategoryCount {
  const factory CategoryCount({
    required int products,
  }) = _CategoryCount;

  factory CategoryCount.fromJson(Map<String, dynamic> json) =>
      _$CategoryCountFromJson(json);
}