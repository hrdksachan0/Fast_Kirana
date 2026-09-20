import 'dart:convert';
import '../../core/constants/api_endpoints.dart';

/// Fully dynamic model for Category, Cuisine & Outlet Offer Cards across FastKirana
/// 100% editable from the Admin Web App with zero hardcoding.
class CategoryCardData {
  final String id;
  final String title;
  final String subtitle;
  final String? categoryName;
  final String? outletName;
  final String? imageUrl;
  final String? videoUrl;
  final String? imageAsset;
  final String? cashbackTitle;
  final String? cashbackSubtitle;
  final String? disclaimerText;
  final String? backgroundColorHex;
  final String? redirectUrl;
  final int sortOrder;
  final bool isActive;

  /// Card layout variant: 'hero' | 'dark_showcase' | 'bento_grid' | 'editorial' | 'standard'
  final String cardType;

  /// Target mode: 'food' | 'grocery' | 'all'
  final String type;

  /// Eyebrow tag above title (e.g. "🔥 CHEF SPECIAL", "🌿 DAILY HARVEST", "⚡ 10-MIN EXPRESS")
  final String? eyebrowTag;

  /// Call to action button text (e.g. "ORDER NOW", "SHOP FRESH", "EXPLORE MENU")
  final String? ctaText;

  /// Call to action destination URL (e.g. "/category/fruits-vegetables", "/restaurant/as-restaurant")
  final String? ctaUrl;

  /// CTA button background color hex (e.g. "#EF4444", "#10B981")
  final String? ctaBgColorHex;

  /// CTA button text color hex (e.g. "#FFFFFF")
  final String? ctaTextColorHex;

  /// 4 image URLs for the 2x2 Bento Grid format
  final List<String>? gridImages;

  /// Optional labels for the 4 bento grid items
  final List<String>? gridTitles;

  /// Multi-stop gradient colors for backdrops
  final List<String>? gradientColorsHex;

  // Backward compatibility getters
  String get discountTitle => title;
  String? get primaryBrand => categoryName;
  String? get secondaryBrand => outletName;
  bool get hasWireframeGrid => false;
  List<String>? get brandLogos => null;

  const CategoryCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    this.categoryName,
    this.outletName,
    this.imageUrl,
    this.videoUrl,
    this.imageAsset,
    this.cashbackTitle,
    this.cashbackSubtitle,
    this.disclaimerText,
    this.backgroundColorHex,
    this.redirectUrl,
    this.sortOrder = 0,
    this.isActive = true,
    this.cardType = 'standard',
    this.type = 'grocery',
    this.eyebrowTag,
    this.ctaText,
    this.ctaUrl,
    this.ctaBgColorHex,
    this.ctaTextColorHex,
    this.gridImages,
    this.gridTitles,
    this.gradientColorsHex,
  });

  factory CategoryCardData.fromJson(Map<String, dynamic> rawJson) {
    Map<String, dynamic> json = Map<String, dynamic>.from(rawJson);
    if (rawJson['code'] != null &&
        rawJson['code'].toString().startsWith('{') &&
        rawJson['code'].toString().endsWith('}')) {
      try {
        final decoded = jsonDecode(rawJson['code'].toString());
        if (decoded is Map<String, dynamic>) {
          json.addAll(decoded);
        }
      } catch (_) {}
    }

    List<String>? parseStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return null;
    }

    // Title resolution
    final titleStr = json['title']?.toString() ??
        json['discountTitle']?.toString() ??
        '';

    // Subtitle / description resolution
    final subtitleStr = json['subtitle']?.toString() ??
        json['description']?.toString() ??
        '';

    // Category / outlet resolution
    final catName = json['categoryName']?.toString() ??
        json['primaryBrand']?.toString() ??
        json['brand1']?.toString();

    final outName = json['outletName']?.toString() ??
        json['secondaryBrand']?.toString() ??
        json['brand2']?.toString();

    // Link resolution
    final link = json['ctaUrl']?.toString() ??
        json['linkUrl']?.toString() ??
        json['redirectUrl']?.toString() ??
        json['link']?.toString();

    // Card format resolution
    String fmt = json['cardType']?.toString() ?? json['type']?.toString() ?? 'standard';
    if (fmt == 'dark_showcase') fmt = 'hero';

    return CategoryCardData(
      id: json['id']?.toString() ?? '',
      title: titleStr,
      subtitle: subtitleStr,
      categoryName: catName,
      outletName: outName,
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString(),
      videoUrl: json['videoUrl']?.toString() ?? json['video']?.toString(),
      imageAsset: json['imageAsset']?.toString(),
      cashbackTitle: json['cashbackTitle']?.toString(),
      cashbackSubtitle: json['cashbackSubtitle']?.toString(),
      disclaimerText: json['disclaimerText']?.toString() ?? json['disclaimer']?.toString(),
      backgroundColorHex: json['backgroundColorHex']?.toString() ?? json['bgColor']?.toString(),
      redirectUrl: link,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      cardType: fmt,
      type: json['type']?.toString() ?? 'grocery',
      eyebrowTag: json['eyebrowTag']?.toString() ?? json['badge']?.toString() ?? json['tag']?.toString(),
      ctaText: json['ctaText']?.toString() ?? json['buttonText']?.toString(),
      ctaUrl: link,
      ctaBgColorHex: json['ctaBgColorHex']?.toString(),
      ctaTextColorHex: json['ctaTextColorHex']?.toString(),
      gridImages: parseStringList(json['gridImages']),
      gridTitles: parseStringList(json['gridTitles']),
      gradientColorsHex: parseStringList(json['gradientColorsHex'] ?? json['gradientColors']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'discountTitle': title,
      'subtitle': subtitle,
      'description': subtitle,
      'categoryName': categoryName,
      'primaryBrand': categoryName,
      'outletName': outletName,
      'secondaryBrand': outletName,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'imageAsset': imageAsset,
      'cashbackTitle': cashbackTitle,
      'cashbackSubtitle': cashbackSubtitle,
      'disclaimerText': disclaimerText,
      'backgroundColorHex': backgroundColorHex,
      'redirectUrl': redirectUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'cardType': cardType,
      'type': type,
      'eyebrowTag': eyebrowTag,
      'ctaText': ctaText,
      'ctaUrl': ctaUrl,
      'ctaBgColorHex': ctaBgColorHex,
      'ctaTextColorHex': ctaTextColorHex,
      'gridImages': gridImages,
      'gridTitles': gridTitles,
      'gradientColorsHex': gradientColorsHex,
    };
  }
}

/// Backward compatibility alias so existing Flutter code continues to work without disruption.
typedef BrandOfferCardData = CategoryCardData;
