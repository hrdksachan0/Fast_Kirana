import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../data/models/product.dart';
import '../../providers/store_hub_provider.dart';
import 'campaign_block.dart';

/// The same versioned manifest is served by the web application.
final navratriDataProvider = FutureProvider<NavratriData>((ref) async {
  final hub = ref.watch(currentStoreHubProvider);
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio
        .get('/api/homepage-campaign', queryParameters: {'storeId': hub.id});
    final body = response.data;
    if (body is Map && body['campaign'] is Map) {
      return NavratriData.fromJson(
          Map<String, dynamic>.from(body['campaign'] as Map));
    }
  } catch (_) {
    // Published configuration is optional; a failed request never blocks home.
  }
  final source = await rootBundle.loadString('assets/navratri/navratri.json');
  return NavratriData.fromJson(jsonDecode(source) as Map<String, dynamic>);
});

class NavratriLabels {
  final String sectionLabel, specialsHeading, curvedTabLabel, loadingText;
  final String emptyText, demoLabel, resultsDemoLabel;
  const NavratriLabels({
    this.sectionLabel = 'Celebrate Navratri',
    this.specialsHeading = 'Navratri Specials',
    this.curvedTabLabel = 'Top Picks',
    this.loadingText = 'Loading this store’s festive picks…',
    this.emptyText =
        'No matching products in this collection yet. Try another tab or search the catalogue.',
    this.demoLabel = 'Demo prices',
    this.resultsDemoLabel = 'Demo collection · illustrative prices',
  });
  factory NavratriLabels.fromJson(Map<String, dynamic> json) {
    const fallback = NavratriLabels();
    String value(String key, String defaultValue) =>
        json[key] is String ? json[key] as String : defaultValue;
    return NavratriLabels(
      sectionLabel: value('sectionLabel', fallback.sectionLabel),
      specialsHeading: value('specialsHeading', fallback.specialsHeading),
      curvedTabLabel: value('curvedTabLabel', fallback.curvedTabLabel),
      loadingText: value('loadingText', fallback.loadingText),
      emptyText: value('emptyText', fallback.emptyText),
      demoLabel: value('demoLabel', fallback.demoLabel),
      resultsDemoLabel: value('resultsDemoLabel', fallback.resultsDemoLabel),
    );
  }
}

class NavratriAppearance {
  final Color background, card, text, smallText, headerText, headerOutline;
  final Color underline, tabSurface;
  const NavratriAppearance({
    this.background = const Color(0xFFFF831F),
    this.card = const Color(0xFFFFF8DF),
    this.text = const Color(0xFF985F39),
    this.smallText = const Color(0xFF5E2E16),
    this.headerText = const Color(0xFFFFF8DF),
    this.headerOutline = const Color(0xFF713D21),
    this.underline = const Color(0xFF832F27),
    this.tabSurface = const Color(0xFFFFF8DF),
  });
  factory NavratriAppearance.fromJson(Map<String, dynamic> json) {
    const fallback = NavratriAppearance();
    Color value(String key, Color defaultValue) {
      final hex = json[key];
      if (hex is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
        return defaultValue;
      }
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }

    return NavratriAppearance(
      background: value('background', fallback.background),
      card: value('card', fallback.card),
      text: value('text', fallback.text),
      smallText: value('smallText', fallback.smallText),
      headerText: value('headerText', fallback.headerText),
      headerOutline: value('headerOutline', fallback.headerOutline),
      underline: value('underline', fallback.underline),
      tabSurface: value('tabSurface', fallback.tabSurface),
    );
  }
}

class NavratriTimings {
  final Duration header, product, search, crossfade;
  const NavratriTimings({
    required this.header,
    required this.product,
    required this.search,
    required this.crossfade,
  });

  factory NavratriTimings.fromJson(Map<String, dynamic> json) {
    Duration duration(String key) {
      final value = json[key];
      if (value is! int || (key == 'crossfadeMs' ? value < 0 : value <= 0)) {
        throw FormatException('Navratri timing $key must be positive');
      }
      return Duration(milliseconds: value);
    }

    return NavratriTimings(
      header: duration('headerMs'),
      product: duration('productMs'),
      search: duration('searchMs'),
      crossfade: duration('crossfadeMs'),
    );
  }
}

class NavratriHeaderSlide {
  final String id, kind, eyebrow, title, subtitle;
  final String? image;
  const NavratriHeaderSlide({
    required this.id,
    required this.kind,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.image,
  });
  factory NavratriHeaderSlide.fromJson(Map<String, dynamic> json) =>
      NavratriHeaderSlide(
        id: json['id'] as String,
        kind: json['kind'] as String,
        eyebrow: json['eyebrow'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        image: json['image'] as String?,
      );
}

class NavratriProduct {
  final String id, name, image, currency, categoryId, destinationId;
  final String? productId;
  final double originalPrice, price;
  const NavratriProduct({
    required this.id,
    required this.name,
    required this.image,
    required this.currency,
    required this.categoryId,
    required this.destinationId,
    required this.originalPrice,
    required this.price,
    this.productId,
  });
  factory NavratriProduct.fromJson(Map<String, dynamic> json) =>
      NavratriProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        image: json['image'] as String,
        currency: json['currency'] as String,
        categoryId: json['categoryId'] as String,
        destinationId: json['destinationId'] as String,
        originalPrice: (json['originalPrice'] as num).toDouble(),
        price: (json['price'] as num).toDouble(),
        productId: json['productId'] as String?,
      );
}

class NavratriCategory {
  final String id, label, image, destinationId;
  final List<String> keywords;
  const NavratriCategory({
    required this.id,
    required this.label,
    required this.image,
    required this.destinationId,
    required this.keywords,
  });
  factory NavratriCategory.fromJson(Map<String, dynamic> json) =>
      NavratriCategory(
        id: json['id'] as String,
        label: json['label'] as String,
        image: json['image'] as String,
        destinationId: json['destinationId'] as String,
        keywords: List<String>.from(json['keywords'] as List),
      );
}

class NavratriTab {
  final String id, label, image;
  final List<String> keywords;
  final List<String> productIds;
  const NavratriTab({
    required this.id,
    required this.label,
    required this.image,
    required this.keywords,
    this.productIds = const [],
  });
  factory NavratriTab.fromJson(Map<String, dynamic> json) => NavratriTab(
        id: json['id'] as String,
        label: json['label'] as String,
        image: json['image'] as String,
        keywords: List<String>.from(json['keywords'] as List? ?? []),
        productIds: List<String>.from(json['productIds'] as List? ?? []),
      );
}

class NavratriNavigationItem {
  final String id, label;
  final String? destinationId;
  const NavratriNavigationItem({
    required this.id,
    required this.label,
    required this.destinationId,
  });
  factory NavratriNavigationItem.fromJson(Map<String, dynamic> json) =>
      NavratriNavigationItem(
        id: json['id'] as String,
        label: json['label'] as String,
        destinationId: json['destinationId'] as String?,
      );
}

class NavratriDestination {
  final String id, kind, query;
  const NavratriDestination({
    required this.id,
    required this.kind,
    required this.query,
  });
  factory NavratriDestination.fromJson(Map<String, dynamic> json) =>
      NavratriDestination(
        id: json['id'] as String,
        kind: json['kind'] as String,
        query: json['query'] as String,
      );
}

class NavratriData {
  final int version;
  final String layout;
  final String composition;
  final List<CampaignBlock> blocks;
  final bool demo;
  final NavratriTimings timings;
  final List<String> searchSuggestions;
  final List<NavratriNavigationItem> navigation;
  final List<NavratriHeaderSlide> headers;
  final List<NavratriProduct> products;
  final List<NavratriCategory> categories;
  final List<NavratriTab> tabs;
  final List<NavratriDestination> destinations;
  final bool enabled, autoplay;
  final String searchPrefix;
  final NavratriLabels labels;
  final NavratriAppearance appearance;
  final String? decorationImage;

  const NavratriData({
    required this.version,
    this.layout = 'classic',
    this.composition = 'template',
    this.blocks = const [],
    required this.demo,
    required this.timings,
    required this.searchSuggestions,
    required this.navigation,
    required this.headers,
    required this.products,
    required this.categories,
    required this.tabs,
    required this.destinations,
    this.enabled = true,
    this.autoplay = true,
    this.searchPrefix = 'Search for',
    this.labels = const NavratriLabels(),
    this.appearance = const NavratriAppearance(),
    this.decorationImage = 'string-lights.svg',
  });

  factory NavratriData.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported Navratri manifest version');
    }
    final layout = json.containsKey('layout') ? json['layout'] : 'classic';
    final composition =
        json.containsKey('composition') ? json['composition'] : 'template';
    if (!const ['template', 'blocks'].contains(composition)) {
      throw const FormatException('Unsupported campaign composition');
    }
    final rawBlocks = json.containsKey('blocks') ? json['blocks'] : <dynamic>[];
    if (rawBlocks is! List || rawBlocks.length > 16) {
      throw const FormatException('Invalid campaign blocks');
    }
    if (!const ['classic', 'banner', 'split', 'grid', 'deals']
        .contains(layout)) {
      throw const FormatException('Unsupported campaign layout');
    }
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) fromJson) =>
        (json[key] as List? ?? [])
            .map((item) => fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false);
    final data = NavratriData(
      version: 1,
      layout: layout as String,
      composition: composition as String,
      blocks: rawBlocks
          .map((value) =>
              CampaignBlock.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false),
      demo: json['demo'] as bool? ?? true,
      timings: NavratriTimings.fromJson(
          json['timings'] as Map<String, dynamic>? ??
              {
                'headerMs': 4000,
                'productMs': 2500,
                'searchMs': 3000,
                'crossfadeMs': 400
              }),
      searchSuggestions:
          List<String>.from(json['searchSuggestions'] as List? ?? ['Milk']),
      navigation: parse('navigation', NavratriNavigationItem.fromJson),
      headers: parse('headers', NavratriHeaderSlide.fromJson),
      products: parse('products', NavratriProduct.fromJson),
      categories: parse('categories', NavratriCategory.fromJson),
      tabs: parse('tabs', NavratriTab.fromJson),
      destinations: parse('destinations', NavratriDestination.fromJson),
      enabled: json['enabled'] as bool? ?? true,
      autoplay: json['autoplay'] as bool? ?? true,
      searchPrefix: json['searchPrefix'] as String? ?? 'Search for',
      labels: NavratriLabels.fromJson(
          Map<String, dynamic>.from(json['labels'] as Map? ?? {})),
      appearance: NavratriAppearance.fromJson(
          Map<String, dynamic>.from(json['appearance'] as Map? ?? {})),
      decorationImage: json.containsKey('decorationImage')
          ? json['decorationImage'] as String?
          : 'string-lights.svg',
    );
    if (data.blocks.map((block) => block.id).toSet().length !=
        data.blocks.length) {
      throw const FormatException('Duplicate campaign block IDs');
    }
    if (data.composition == 'blocks' &&
        !data.blocks.any((block) => block.enabled)) {
      throw const FormatException('Add at least one visible campaign block');
    }
    for (final block in data.blocks) {
      final source = block.type == 'banner'
          ? data.headers.map((item) => item.id)
          : block.type == 'categories'
              ? data.categories.map((item) => item.id)
              : block.type == 'spotlight'
                  ? data.products.map((item) => item.id)
                  : <String>[];
      if (block.itemIds.any((id) => !source.contains(id))) {
        throw const FormatException('Unknown campaign block item');
      }
      if (block.type == 'collection'
          ? !data.tabs.any((tab) => tab.id == block.tabId)
          : block.tabId != null) {
        throw const FormatException('Invalid campaign block collection');
      }
      if (block.destinationId != null) data.destination(block.destinationId!);
      if (block.image != null && !validNavratriImage(block.image)) {
        throw const FormatException('Invalid campaign block image');
      }
    }
    if (!data.enabled) return data;
    if (data.headers.isEmpty ||
        data.headers.length > 8 ||
        data.products.isEmpty ||
        data.products.length > 12 ||
        data.searchSuggestions.isEmpty ||
        data.categories.length != 4 ||
        data.tabs.isEmpty ||
        data.tabs.length > 8) {
      throw const FormatException('Navratri manifest has incomplete sections');
    }
    if (!data.demo &&
        data.products.any((item) =>
            (data.composition == 'template' ||
                data.blocks.any((block) =>
                    block.enabled &&
                    block.type == 'spotlight' &&
                    (block.itemIds.isEmpty ||
                        block.itemIds.contains(item.id)))) &&
            item.productId?.trim().isNotEmpty != true)) {
      throw const FormatException(
          'Live campaigns require catalogue product links');
    }
    for (final id in [
      ...data.navigation.map((item) => item.destinationId),
      ...data.categories.map((item) => item.destinationId),
      ...data.products.map((item) => item.destinationId),
    ]) {
      if (id != null) data.destination(id);
    }
    return data;
  }

  NavratriDestination destination(String id) => destinations.firstWhere(
        (item) => item.id == id && item.kind == 'search',
        orElse: () => throw FormatException('Unknown Navratri destination $id'),
      );

  /// Explicit product IDs are prioritized first; remaining slots match keywords.
  List<Product> filterProducts(List<Product> catalog, NavratriTab tab) {
    final catalogById = {
      for (final product in catalog)
        if (product.restaurantId == null || product.restaurantId!.isEmpty)
          product.id: product,
    };

    final explicitProducts = tab.productIds
        .map((id) => catalogById[id])
        .whereType<Product>()
        .toList(growable: false);

    final explicitIds = explicitProducts.map((p) => p.id).toSet();

    final allKeywords = [
      ...categories.expand((category) => category.keywords),
      ...tabs.expand((item) => item.keywords),
    ];
    final keywords = tab.keywords.isEmpty
        ? (tab.productIds.isEmpty ? allKeywords : <String>[])
        : tab.keywords;
    final keywordMatches = catalog.where((product) {
      if (explicitIds.contains(product.id)) return false;
      if (product.restaurantId != null && product.restaurantId!.isNotEmpty) {
        return false;
      }
      final text = [
        product.name,
        product.slug,
        product.description ?? '',
        product.category?.name ?? '',
        product.category?.slug ?? '',
        ...product.tags,
      ].join(' ').toLowerCase();
      return matchesNavratriKeywords(text, keywords);
    }).toList(growable: false);

    return [...explicitProducts, ...keywordMatches];
  }

  List<NavratriProduct> demoProductsFor(NavratriTab tab) {
    if (tab.keywords.isEmpty) return products;
    final keywords = tab.keywords.map((value) => value.toLowerCase());
    return products.where((product) {
      final category = categories.firstWhere(
        (item) => item.id == product.categoryId,
      );
      final text =
          '${product.name} ${category.label} ${category.keywords.join(' ')}'
              .toLowerCase();
      return matchesNavratriKeywords(text, keywords);
    }).toList(growable: false);
  }
}

String navratriAsset(String image) {
  if (image.startsWith('https://')) return image;
  if (image.startsWith('/')) {
    return Uri.parse(AppConfig.webStorefrontUrl).resolve(image).toString();
  }
  return 'assets/navratri/$image';
}

bool navratriImageIsSvg(String image) =>
    Uri.parse(image).path.toLowerCase().endsWith('.svg');

/// Catalogue emoji and malformed media values must retain authored slot art.
bool validNavratriImage(String? image) {
  if (image == null ||
      image.isEmpty ||
      image.length > 2048 ||
      RegExp(r'[\x00-\x1f\\]').hasMatch(image)) {
    return false;
  }
  try {
    final decoded = Uri.decodeComponent(image);
    if (decoded.contains('\\') ||
        decoded.split('/').any((part) => part == '.' || part == '..')) {
      return false;
    }
  } catch (_) {
    return false;
  }
  if (!image.startsWith('https://') && image.contains('..')) return false;
  if (RegExp(r'^[\w.-]+\.(svg|png|jpe?g|webp|avif)$', caseSensitive: false)
      .hasMatch(image)) {
    return true;
  }
  if (RegExp(r'^/(?!/)[\w/%.@-]+\.(svg|png|jpe?g|webp|avif)$',
          caseSensitive: false)
      .hasMatch(image)) {
    return true;
  }
  final uri = Uri.tryParse(image);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

class NavratriPromotion {
  final NavratriProduct configured;
  final Product? live;
  const NavratriPromotion(this.configured, this.live);
  factory NavratriPromotion.resolve(
      NavratriProduct item, List<Product> catalog) {
    final matches = catalog.where((product) =>
        product.id == item.productId &&
        (product.restaurantId == null || product.restaurantId!.isEmpty));
    return NavratriPromotion(item, matches.isEmpty ? null : matches.first);
  }
  bool get linked => configured.productId?.isNotEmpty ?? false;
  bool get available => live != null && live!.isAvailable && live!.stock > 0;
  bool get showPrice => !linked || available;
  bool get demo => !linked;
  String get name => live?.name ?? configured.name;
  String get image =>
      validNavratriImage(live?.imageUrl) ? live!.imageUrl! : configured.image;
  double get originalPrice => live != null
      ? math.max(live!.mrp, live!.price)
      : configured.originalPrice;
  double get price => live?.price ?? configured.price;
}

/// Prefixes match plurals, while token boundaries keep diya out of dandiya.
/// Multi-word keywords must match contiguous words in the catalogue metadata.
bool matchesNavratriKeywords(String text, Iterable<String> keywords) {
  final separators = RegExp(r'[\s\-_/.,&()]+');
  List<String> words(String value) => value
      .toLowerCase()
      .split(separators)
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  final tokens = words(text);
  return keywords.any((keyword) {
    final parts = words(keyword);
    if (parts.isEmpty || parts.length > tokens.length) return false;
    for (var start = 0; start <= tokens.length - parts.length; start++) {
      var matches = true;
      for (var offset = 0; offset < parts.length; offset++) {
        if (!tokens[start + offset].startsWith(parts[offset])) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
    return false;
  });
}
