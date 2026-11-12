import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../campaign_bento_models.dart';
import '../../../core/routes/page_transitions.dart';
import '../../gifting/send_gift_screen.dart';

/// The Gifting Boutique Bento Zone Card (Rose & Gift Special)
/// Exactly matching the premium editorial design reference
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
    const borderColor = Color(0xFFEFC6D0);
    const roseInk = Color(0xFF52101F);
    const roseSubtle = Color(0xFF7D4856);
    const maroonPill = Color(0xFF6B1728);

    return GestureDetector(
      onTap: () => _openGiftingPage(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 224,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDECEF),
              Color(0xFFF9D8E0),
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
            // Full-bleed HD Gifting Boutique hero artwork (clean pink left + roses/chocolates/cake right)
            Positioned.fill(
              child: Image.asset(
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
                        child: Text(
                          card.title.isNotEmpty ? card.title : 'Gifting Boutique',
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        card.title.isNotEmpty ? card.title : 'Little things,\nbig feelings.',
                        style: const TextStyle(
                          fontFamily: 'NotoSerif',
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: roseInk,
                          height: 1.12,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.subtitle.isNotEmpty
                            ? card.subtitle
                            : 'Flowers, cakes &\nthoughtful surprises.',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: roseSubtle,
                          height: 1.3,
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
