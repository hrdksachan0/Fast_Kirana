import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../campaign_bento_models.dart';
import '../../../core/routes/page_transitions.dart';
import '../../gifting/send_gift_screen.dart';
import '../../../providers/gifting_store_provider.dart';

/// The Gifting Boutique Bento Zone Card (Rose & Gift Special)
/// Dynamically synced with Web Admin Gifting Store configuration.
class GiftingBoutiqueCard extends ConsumerWidget {
  final CampaignBentoCardConfig card;

  const GiftingBoutiqueCard({super.key, required this.card});

  void _openGiftingPage(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      FadeSlideRoute(page: const SendGiftScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Live Web Admin Gifting Configuration
    final giftingConfigAsync = ref.watch(giftingStoreConfigProvider);
    final config = giftingConfigAsync.valueOrNull;

    // If Admin disabled the gifting store, hide card from home screen automatically
    if (config != null && !config.enabled) {
      return const SizedBox.shrink();
    }

    const borderColor = Color(0xFFF2D1DA);
    const roseInk = Color(0xFF4C0E1E);
    const roseSubtle = Color(0xFF8C5362);
    final maroonPill = config?.gradientEnd ?? const Color(0xFF881337);

    final title = config != null && config.bannerTitle.trim().isNotEmpty
        ? config.bannerTitle.trim()
        : 'Thoughtful Gifts,\nDelivered With Love';

    final subtitle = config != null && config.bannerSubtitle.trim().isNotEmpty
        ? config.bannerSubtitle.trim()
        : 'Little things, big feelings.\nFresh blooms, cakes & treats.';

    final bannerUrl = config?.bannerImageUrl.trim() ?? '';

    return GestureDetector(
      onTap: () => _openGiftingPage(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 224,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              config?.gradientStart.withValues(alpha: 0.18) ?? const Color(0xFFFDECEF),
              config?.gradientEnd.withValues(alpha: 0.25) ?? const Color(0xFFF9D8E0),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF881337).withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Full-bleed HD Gifting Boutique hero artwork (or uploaded image from Admin)
            Positioned.fill(
              child: bannerUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/navratri/gifting-boutique-hero-hd.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                      ),
                    )
                  : Image.asset(
                      'assets/navratri/gifting-boutique-hero-hd.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
            ),

            // Left-side editorial copy + Explore Gifts CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: maroonPill,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Gifting Boutique',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'NotoSerif',
                          fontSize: 18.5,
                          fontWeight: FontWeight.w700,
                          color: roseInk,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: roseSubtle,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: maroonPill,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: maroonPill.withValues(alpha: 0.26),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore Gifts',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
