import 'package:json_annotation/json_annotation.dart';

part 'banner.g.dart';

@JsonSerializable()
class Banner {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? link;
  final int sortOrder;
  final bool isActive;

  Banner({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.link,
    required this.sortOrder,
    required this.isActive,
  });

  factory Banner.fromJson(Map<String, dynamic> json) => _$BannerFromJson(json);
  Map<String, dynamic> toJson() => _$BannerToJson(this);
}