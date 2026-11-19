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

    // Card-level visibility is governed by card.enabled and hub rules
    if (!card.enabled) {
      return const SizedBox.shrink();
    }

    // Resolve colors and styling from card config (with elegant fallbacks)
    final bg = card.backgroundColor ?? const Color(0xFFFDF2F4);
    final borderColor = card.borderColor ?? const Color(0xFFFCE7F3);
    final roseInk = card.textColor ?? const Color(0xFF831843);
    final roseSubtle = (card.textColor ?? const Color(0xFF831843)).withValues(alpha: 0.72);
    final maroonPill = card.accentColor ?? const Color(0xFF881337);

    // Dynamic Title & Subtitle from Admin Bento Card Editor (fallback to rich defaults)
    final title = card.title.trim().isNotEmpty
        ? card.title.trim()
        : (config != null && config.bannerTitle.trim().isNotEmpty
            ? config.bannerTitle.trim()
            : 'Little things, big feelings.');

    final subtitle = card.subtitle.trim().isNotEmpty
        ? card.subtitle.trim()
        : (config != null && config.bannerSubtitle.trim().isNotEmpty
            ? config.bannerSubtitle.trim()
            : 'Flowers, cakes & thoughtful surprises.');

    final badgeText = (card.badge.trim().isNotEmpty && card.badge.trim() != '04') ? card.badge.trim() : '';

    final bannerUrl = (card.heroImage != null && card.heroImage!.trim().isNotEmpty)
        ? card.heroImage!.trim()
        : (config?.bannerImageUrl.trim().isNotEmpty == true
            ? config!.bannerImageUrl.trim()
            : '');

    // Only suppress Flutter text overlay if the banner is explicitly the marketing banner with baked-in lettering
    final hasBakedArtTypography = bannerUrl.contains('perfect-gifting-banner');

    return GestureDetector(
      onTap: () => _openGiftingPage(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: (MediaQuery.sizeOf(context).width * 0.46 * (MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.25) > 1.0 ? 1.06 : 1.0)).clamp(172.0, 198.0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bg,
              bg.withValues(alpha: 0.94),
              const Color(0xFFFCE7F3).withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: maroonPill.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Full-bleed HD Gifting Boutique hero artwork (aligned right to leave space for copy)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: MediaQuery.sizeOf(context).width * 0.52,
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

            // Subtle gradient scrim from left to protect text legibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.45, 0.65, 1.0],
                    colors: [
                      bg,
                      bg.withValues(alpha: 0.95),
                      bg.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Left-side editorial copy + Explore Gifts CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (badgeText.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor, width: 1),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w800,
                                    color: roseInk,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: maroonPill,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'GIFTING BOUTIQUE',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'NotoSerif',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: roseInk,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3.5),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10.0,
                            fontWeight: FontWeight.w500,
                            color: roseSubtle,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                      decoration: BoxDecoration(
                        color: maroonPill,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: maroonPill.withValues(alpha: 0.28),
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
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
