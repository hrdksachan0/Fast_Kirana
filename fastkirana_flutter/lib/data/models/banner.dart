import 'dart:convert';

class Banner {
  final String id;
  final String title;
  final String description;
  final String code;
  final String gradient;
  final String type;
  final String? imageUrl;
  final String? videoUrl;
  final String? linkUrl;
  final int sortOrder;
  final bool isActive;

  final Map<String, dynamic>? extraData;

  // Backwards-compatibility getters
  String? get subtitle => description.isNotEmpty ? description : null;
  String? get link => linkUrl;

  const Banner({
    required this.id,
    this.title = '',
    this.description = '',
    this.code = '',
    this.gradient = 'from-primary via-rose-500 to-orange-400',
    this.type = 'custom',
    this.imageUrl,
    this.videoUrl,
    this.linkUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.extraData,
  });

  factory Banner.fromJson(Map<String, dynamic> json) {
    String? vUrl = json['videoUrl']?.toString() ?? json['video_url']?.toString();
    if (vUrl == null && json['code'] != null) {
      final codeStr = json['code'].toString();
      if (codeStr.startsWith('{') && codeStr.endsWith('}')) {
        try {
          final parsed = jsonDecode(codeStr);
          if (parsed is Map && parsed['videoUrl'] != null) {
            vUrl = parsed['videoUrl'].toString();
          }
        } catch (_) {}
      }
    }

    return Banner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: (json['description'] ?? json['subtitle'])?.toString() ?? '',
      code: (json['rawCode'] ?? json['code'])?.toString() ?? '',
      gradient: json['gradient']?.toString() ?? 'from-primary via-rose-500 to-orange-400',
      type: json['type']?.toString() ?? 'custom',
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      videoUrl: vUrl,
      linkUrl: (json['linkUrl'] ?? json['link'] ?? json['link_url'] ?? json['ctaUrl'] ?? json['redirectUrl'])?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      extraData: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      if (extraData != null) ...extraData!,
      'id': id,
      'title': title,
      'description': description,
      'code': code,
      'gradient': gradient,
      'type': type,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'linkUrl': linkUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
    return map;
  }
}