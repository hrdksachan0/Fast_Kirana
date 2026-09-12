class Banner {
  final String id;
  final String title;
  final String description;
  final String code;
  final String gradient;
  final String type;
  final String? imageUrl;
  final String? linkUrl;
  final int sortOrder;
  final bool isActive;

  // Backwards-compatibility getters
  String? get subtitle => description.isNotEmpty ? description : null;
  String? get link => linkUrl;

  const Banner({
    required this.id,
    required this.title,
    this.description = '',
    this.code = '',
    this.gradient = 'from-primary via-rose-500 to-orange-400',
    this.type = 'custom',
    this.imageUrl,
    this.linkUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Banner.fromJson(Map<String, dynamic> json) {
    return Banner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: (json['description'] ?? json['subtitle'])?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      gradient: json['gradient']?.toString() ?? 'from-primary via-rose-500 to-orange-400',
      type: json['type']?.toString() ?? 'custom',
      imageUrl: json['imageUrl']?.toString(),
      linkUrl: (json['linkUrl'] ?? json['link'])?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'code': code,
      'gradient': gradient,
      'type': type,
      'imageUrl': imageUrl,
      'linkUrl': linkUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}