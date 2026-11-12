import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'campaign_bento_models.dart';
import '../../core/network/api_client.dart';
import '../../providers/cart_provider.dart';
import '../../providers/store_hub_provider.dart';
import '../../data/models/product.dart';

class CampaignBentoNotifier extends StateNotifier<CampaignBentoConfig> {
  final Ref ref;
  bool _disposed = false;

  CampaignBentoNotifier(this.ref) : super(CampaignBentoConfig.defaultProductionConfig()) {
    _init();
  }

  Future<void> _init() async {
    await _tryLoadBundledOverrides();
    await syncFromCloud();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _tryLoadBundledOverrides() async {
    try {
      final jsonString = await rootBundle.loadString('assets/navratri/campaign_bento.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (!_disposed) {
        state = CampaignBentoConfig.fromJson(data);
      }
    } catch (_) {
      // Keep rich default configuration
    }
  }

  String _normalizeImage(String? raw, String fallback) {
    final val = (raw ?? '').trim();
    if (val.isEmpty) return fallback;
    if (val.startsWith('http://') || val.startsWith('https://')) return val;
    if (val.startsWith('/navratri/')) return val.substring('/navratri/'.length);
    return val;
  }

  CampaignBentoItemConfig _mapWebSlot(
    Map<String, dynamic> slot,
    Map<String, Product> linkedById, {
    String? tabId,
  }) {
    final slotId = (slot['id'] as String? ?? '').trim();
    final productId = (slot['productId'] as String?)?.trim();
    final realProduct = (productId != null && productId.isNotEmpty) ? linkedById[productId] : null;
    final customTitle = (slot['customTitle'] as String?)?.trim();
    final fallbackName = (slot['fallbackName'] as String? ?? '').trim();
    final fallbackUnit = (slot['fallbackUnit'] as String? ?? '').trim();
    final fallbackPrice = (slot['fallbackPrice'] as num?)?.toDouble() ?? 0.0;
    final fallbackMrp = (slot['fallbackMrp'] as num?)?.toDouble();
    final fallbackImage = _normalizeImage(slot['fallbackImage'] as String?, 'daily-vegetables.svg');

    final name = (customTitle != null && customTitle.isNotEmpty)
        ? customTitle
        : (realProduct?.name ?? (fallbackName.isNotEmpty ? fallbackName : 'Item'));
    final weight = realProduct?.unit ?? fallbackUnit;
    final price = realProduct?.price ?? fallbackPrice;
    final originalPrice = realProduct != null
        ? (realProduct.mrp > realProduct.price ? realProduct.mrp : null)
        : fallbackMrp;
    final image = _normalizeImage(realProduct?.imageUrl, fallbackImage);

    String? discountTag = (slot['badge'] as String?)?.trim();
    if ((discountTag == null || discountTag.isEmpty) &&
        originalPrice != null &&
        originalPrice > price) {
      final saved = (originalPrice - price).round();
      if (saved > 0) discountTag = '₹$saved OFF';
    }

    return CampaignBentoItemConfig(
      id: (realProduct?.id ?? productId ?? slotId).isNotEmpty
          ? (realProduct?.id ?? productId ?? slotId)
          : DateTime.now().microsecondsSinceEpoch.toString(),
      productId: realProduct?.id ?? productId,
      realProduct: realProduct,
      name: name,
      weight: weight,
      price: price,
      originalPrice: originalPrice,
      discountTag: discountTag,
      image: image,
      tabId: tabId,
      unitPriceComparison: (slot['perUnitLabel'] as String?)?.trim(),
      checkedByDefault: slot['checkedByDefault'] as bool? ?? true,
    );
  }

  /// Sync live 6-Card Bento config & linked real DB products from Web Admin API.
  /// Silently retains bundled defaults if offline or server unreachable.
  Future<void> syncFromCloud([String? overrideStoreId]) async {
    try {
      final hub = ref.read(currentStoreHubProvider);
      final storeId = overrideStoreId ?? hub.id;
      final dio = ref.read(dioProvider);

      final response = await dio.get(
        '/api/campaign-bento',
        queryParameters: {'storeId': storeId},
        options: Options(
          connectTimeout: const Duration(milliseconds: 4000),
          receiveTimeout: const Duration(milliseconds: 4000),
        ),
      );
      if (_disposed) return;

      final body = response.data;
      if (body is! Map || body['campaign'] is! Map) return;
      final campaign = Map<String, dynamic>.from(body['campaign'] as Map);

      final Map<String, Product> linkedById = {};
      if (body['linkedProducts'] is List) {
        for (final raw in body['linkedProducts'] as List) {
          if (raw is Map) {
            try {
              final prod = Product.fromJson(Map<String, dynamic>.from(raw));
              linkedById[prod.id] = prod;
            } catch (_) {}
          }
        }
      }

      final base = state;
      final updatedCards = base.cards.map((card) {
        if (card.type == CampaignCardType.freshMarket && campaign['freshMarket'] is Map) {
          final fm = Map<String, dynamic>.from(campaign['freshMarket'] as Map);
          final List<CampaignBentoItemConfig> items = [];
          if (fm['tabs'] is List) {
            for (final tab in fm['tabs'] as List) {
              if (tab is Map && tab['items'] is List) {
                final tabId = tab['id'] as String?;
                for (final slot in tab['items'] as List) {
                  if (slot is Map) {
                    items.add(_mapWebSlot(Map<String, dynamic>.from(slot), linkedById, tabId: tabId));
                  }
                }
              }
            }
          }
          return card.copyWith(
            enabled: fm['enabled'] as bool? ?? card.enabled,
            sortOrder: (fm['sortOrder'] as num?)?.toInt() ?? card.sortOrder,
            badge: (fm['badge'] as String?)?.trim().isNotEmpty == true ? (fm['badge'] as String).trim() : card.badge,
            backgroundColor: CampaignBentoCardConfig.parseColor(fm['backgroundColor'], card.backgroundColor),
            borderColor: CampaignBentoCardConfig.parseColor(fm['borderColor'], card.borderColor),
            accentColor: CampaignBentoCardConfig.parseColor(fm['accentColor'], card.accentColor),
            textColor: CampaignBentoCardConfig.parseColor(fm['textColor'], card.textColor),
            minInStockItems: (fm['minInStockItems'] as num?)?.toInt() ?? card.minInStockItems,
            scheduleEnabled: fm['scheduleEnabled'] as bool? ?? card.scheduleEnabled,
            startDate: fm['startDate'] as String? ?? card.startDate,
            endDate: fm['endDate'] as String? ?? card.endDate,
            timeSlot: fm['timeSlot'] as String? ?? card.timeSlot,
            targetHubs: (fm['targetHubs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? card.targetHubs,
            title: (fm['title'] as String?)?.trim().isNotEmpty == true
                ? (fm['title'] as String).trim()
                : card.title,
            subtitle: (fm['subtitle'] as String?)?.trim() ?? card.subtitle,
            items: items.isNotEmpty ? items : card.items,
          );
        }

        if (card.type == CampaignCardType.dailyRestock && campaign['dailyRestock'] is Map) {
          final dr = Map<String, dynamic>.from(campaign['dailyRestock'] as Map);
          final items = (dr['items'] as List? ?? const [])
              .whereType<Map>()
              .map((s) => _mapWebSlot(Map<String, dynamic>.from(s), linkedById))
              .toList();
          return card.copyWith(
            enabled: dr['enabled'] as bool? ?? card.enabled,
            sortOrder: (dr['sortOrder'] as num?)?.toInt() ?? card.sortOrder,
            badge: (dr['badge'] as String?)?.trim().isNotEmpty == true ? (dr['badge'] as String).trim() : card.badge,
            backgroundColor: CampaignBentoCardConfig.parseColor(dr['backgroundColor'], card.backgroundColor),
            borderColor: CampaignBentoCardConfig.parseColor(dr['borderColor'], card.borderColor),
            accentColor: CampaignBentoCardConfig.parseColor(dr['accentColor'], card.accentColor),
            textColor: CampaignBentoCardConfig.parseColor(dr['textColor'], card.textColor),
            minInStockItems: (dr['minInStockItems'] as num?)?.toInt() ?? card.minInStockItems,
            scheduleEnabled: dr['scheduleEnabled'] as bool? ?? card.scheduleEnabled,
            startDate: dr['startDate'] as String? ?? card.startDate,
            endDate: dr['endDate'] as String? ?? card.endDate,
            timeSlot: dr['timeSlot'] as String? ?? card.timeSlot,
            targetHubs: (dr['targetHubs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? card.targetHubs,
            title: (dr['title'] as String?)?.trim() ?? card.title,
            subtitle: (dr['subtitle'] as String?)?.trim() ?? card.subtitle,
            items: items.isNotEmpty ? items : card.items,
          );
        }

        if (card.type == CampaignCardType.valuePicks && campaign['valuePicks'] is Map) {
          final vp = Map<String, dynamic>.from(campaign['valuePicks'] as Map);
          final items = (vp['items'] as List? ?? const [])
              .whereType<Map>()
              .map((s) => _mapWebSlot(Map<String, dynamic>.from(s), linkedById))
              .toList();
          return card.copyWith(
            enabled: vp['enabled'] as bool? ?? card.enabled,
            sortOrder: (vp['sortOrder'] as num?)?.toInt() ?? card.sortOrder,
            badge: (vp['badge'] as String?)?.trim().isNotEmpty == true ? (vp['badge'] as String).trim() : card.badge,
            backgroundColor: CampaignBentoCardConfig.parseColor(vp['backgroundColor'], card.backgroundColor),
            borderColor: CampaignBentoCardConfig.parseColor(vp['borderColor'], card.borderColor),
            accentColor: CampaignBentoCardConfig.parseColor(vp['accentColor'], card.accentColor),
            textColor: CampaignBentoCardConfig.parseColor(vp['textColor'], card.textColor),
            minInStockItems: (vp['minInStockItems'] as num?)?.toInt() ?? card.minInStockItems,
            scheduleEnabled: vp['scheduleEnabled'] as bool? ?? card.scheduleEnabled,
            startDate: vp['startDate'] as String? ?? card.startDate,
            endDate: vp['endDate'] as String? ?? card.endDate,
            timeSlot: vp['timeSlot'] as String? ?? card.timeSlot,
            targetHubs: (vp['targetHubs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? card.targetHubs,
            title: (vp['title'] as String?)?.trim() ?? card.title,
            subtitle: (vp['subtitle'] as String?)?.trim() ?? card.subtitle,
            items: items.isNotEmpty ? items : card.items,
          );
        }

        if (card.type == CampaignCardType.giftingBoutique && campaign['giftingBoutique'] is Map) {
          final gb = Map<String, dynamic>.from(campaign['giftingBoutique'] as Map);
          final List<CampaignBentoItemConfig> items = [];
          if (gb['heroItem'] is Map) {
            items.add(_mapWebSlot(Map<String, dynamic>.from(gb['heroItem'] as Map), linkedById,
                tabId: 'anniversary'));
          }
          if (gb['miniItem'] is Map) {
            items.add(_mapWebSlot(Map<String, dynamic>.from(gb['miniItem'] as Map), linkedById,
                tabId: 'birthday'));
          }
          return card.copyWith(
            enabled: gb['enabled'] as bool? ?? card.enabled,
            sortOrder: (gb['sortOrder'] as num?)?.toInt() ?? card.sortOrder,
            badge: (gb['badge'] as String?)?.trim().isNotEmpty == true ? (gb['badge'] as String).trim() : card.badge,
            backgroundColor: CampaignBentoCardConfig.parseColor(gb['backgroundColor'], card.backgroundColor),
            borderColor: CampaignBentoCardConfig.parseColor(gb['borderColor'], card.borderColor),
            accentColor: CampaignBentoCardConfig.parseColor(gb['accentColor'], card.accentColor),
            textColor: CampaignBentoCardConfig.parseColor(gb['textColor'], card.textColor),
            minInStockItems: (gb['minInStockItems'] as num?)?.toInt() ?? card.minInStockItems,
            scheduleEnabled: gb['scheduleEnabled'] as bool? ?? card.scheduleEnabled,
            startDate: gb['startDate'] as String? ?? card.startDate,
            endDate: gb['endDate'] as String? ?? card.endDate,
            timeSlot: gb['timeSlot'] as String? ?? card.timeSlot,
            targetHubs: (gb['targetHubs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? card.targetHubs,
            title: (gb['title'] as String?)?.trim() ?? card.title,
            subtitle: (gb['subtitle'] as String?)?.trim() ?? card.subtitle,
            items: items.isNotEmpty ? items : card.items,
          );
        }

        if (card.type == CampaignCardType.movieNight && campaign['movieNight'] is Map) {
          final mn = Map<String, dynamic>.from(campaign['movieNight'] as Map);
          final items = (mn['items'] as List? ?? const [])
              .whereType<Map>()
              .map((s) => _mapWebSlot(Map<String, dynamic>.from(s), linkedById))
              .toList();
          return card.copyWith(
            enabled: mn['enabled'] as bool? ?? card.enabled,
            sortOrder: (mn['sortOrder'] as num?)?.toInt() ?? card.sortOrder,
            badge: (mn['badge'] as String?)?.trim().isNotEmpty == true ? (mn['badge'] as String).trim() : card.badge,
            backgroundColor: CampaignBentoCardConfig.parseColor(mn['backgroundColor'], card.backgroundColor),
            borderColor: CampaignBentoCardConfig.parseColor(mn['borderColor'], card.borderColor),
            accentColor: CampaignBentoCardConfig.parseColor(mn['accentColor'], card.accentColor),
            textColor: CampaignBentoCardConfig.parseColor(mn['textColor'], card.textColor),
            minInStockItems: (mn['minInStockItems'] as num?)?.toInt() ?? card.minInStockItems,
            scheduleEnabled: mn['scheduleEnabled'] as bool? ?? card.scheduleEnabled,
            startDate: mn['startDate'] as String? ?? card.startDate,
            endDate: mn['endDate'] as String? ?? card.endDate,
            timeSlot: mn['timeSlot'] as String? ?? card.timeSlot,
            targetHubs: (mn['targetHubs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? card.targetHubs,
            title: (mn['title'] as String?)?.trim() ?? card.title,
            subtitle: (mn['subtitle'] as String?)?.trim() ?? card.subtitle,
            heroImage: _normalizeImage(mn['heroImage'] as String?, card.heroImage ?? 'ref-movie-cinema-scene.png'),
            items: items.isNotEmpty ? items : card.items,
          );
        }

        if (card.type == CampaignCardType.breakfastClub && campaign['breakfastClub'] is Map) {
          final bc = Map<String, dynamic>.from(campaign['breakfastClub'] as Map);
          final items = (bc['items'] as List? ?? const [])
              .whereType<Map>()
              .map((s) => _mapWebSlot(Map<String, dynamic>.from(s), linkedById))
              .toList();
          return card.copyWith(
            enabled: bc['enabled'] as bool? ?? card.enabled,
            sortOrder: (bc['sortOrder'] as num?)?.toInt() ?? card.sortOrder,
            badge: (bc['badge'] as String?)?.trim().isNotEmpty == true ? (bc['badge'] as String).trim() : card.badge,
            backgroundColor: CampaignBentoCardConfig.parseColor(bc['backgroundColor'], card.backgroundColor),
            borderColor: CampaignBentoCardConfig.parseColor(bc['borderColor'], card.borderColor),
            accentColor: CampaignBentoCardConfig.parseColor(bc['accentColor'], card.accentColor),
            textColor: CampaignBentoCardConfig.parseColor(bc['textColor'], card.textColor),
            minInStockItems: (bc['minInStockItems'] as num?)?.toInt() ?? card.minInStockItems,
            scheduleEnabled: bc['scheduleEnabled'] as bool? ?? card.scheduleEnabled,
            startDate: bc['startDate'] as String? ?? card.startDate,
            endDate: bc['endDate'] as String? ?? card.endDate,
            timeSlot: bc['timeSlot'] as String? ?? card.timeSlot,
            targetHubs: (bc['targetHubs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? card.targetHubs,
            title: (bc['title'] as String?)?.trim() ?? card.title,
            subtitle: (bc['subtitle'] as String?)?.trim() ?? card.subtitle,
            heroImage: _normalizeImage(bc['heroImage'] as String?, card.heroImage ?? 'ref-breakfast-toast.png'),
            items: items.isNotEmpty ? items : card.items,
          );
        }

        return card;
      }).toList();

      updatedCards.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (!_disposed) {
        state = state.copyWith(
          enabled: campaign['enabled'] as bool? ?? state.enabled,
          cards: updatedCards,
        );
      }
    } catch (_) {
      // Cloud sync optional; bundled defaults remain active
    }
  }

  void setConfig(CampaignBentoConfig newConfig) {
    state = newConfig;
  }

  void updateCard(String cardId, CampaignBentoCardConfig updated) {
    state = state.copyWith(
      cards: state.cards.map((c) => c.id == cardId ? updated : c).toList(),
    );
  }

  void toggleCard(String cardId, [bool? enabled]) {
    state = state.copyWith(
      cards: state.cards.map((c) {
        if (c.id == cardId) {
          return c.copyWith(enabled: enabled ?? !c.enabled);
        }
        return c;
      }).toList(),
    );
  }

  void resetToDefaults() {
    state = CampaignBentoConfig.defaultProductionConfig();
  }

  void updateItemPrice(String cardId, String itemId, double newPrice) {
    state = state.copyWith(
      cards: state.cards.map((card) {
        if (card.id != cardId) return card;
        final updatedItems = card.items.map((item) {
          if (item.id != itemId) return item;
          return item.copyWith(price: newPrice);
        }).toList();
        return card.copyWith(items: updatedItems);
      }).toList(),
    );
  }

  /// Dispatch an item directly into the real customer cart (prefers linked DB Product)
  void addItemToCart(CampaignBentoItemConfig item, {int quantity = 1}) {
    HapticFeedback.lightImpact();

    if (item.realProduct != null) {
      ref.read(cartProvider.notifier).addProduct(item.realProduct!, quantity);
      return;
    }

    final mrpVal = item.originalPrice ?? (item.price * 1.2);
    final discountVal = item.originalPrice != null && item.originalPrice! > 0
        ? (((item.originalPrice! - item.price) / item.originalPrice!) * 100)
        : 0.0;

    final resolvedId = (item.productId != null && item.productId!.isNotEmpty)
        ? item.productId!
        : item.id;

    final product = Product(
      id: resolvedId,
      name: item.name,
      slug: resolvedId,
      description: item.weight,
      imageUrl: item.image,
      mrp: mrpVal,
      price: item.price,
      discount: discountVal,
      unit: item.weight,
      stock: 99,
      isAvailable: true,
      tags: const ['campaign', 'bento'],
      minStock: 1,
      costPrice: item.price * 0.8,
      isFlashDeal: false,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: 1,
      createdAt: DateTime.now(),
    );

    ref.read(cartProvider.notifier).addProduct(product, quantity);
  }
}

final campaignBentoProvider =
    StateNotifierProvider<CampaignBentoNotifier, CampaignBentoConfig>((ref) {
  final notifier = CampaignBentoNotifier(ref);
  ref.listen(currentStoreHubProvider, (prev, next) {
    if (prev?.id != next.id) {
      notifier.syncFromCloud(next.id);
    }
  });
  return notifier;
});
