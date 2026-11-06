import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../cafe/cafe_menu_screen.dart';
import '../coupons_screen.dart';

/// Swiggy-Style Contextual Micro Action Sheet for Coupon Conditions & Failures
class SwiggyCouponActionSheet extends StatelessWidget {
  final String rawMessage;
  final double subtotal;
  final String? restaurantId;
  final String? restaurantName;
  final VoidCallback? onDismiss;

  const SwiggyCouponActionSheet({
    super.key,
    required this.rawMessage,
    required this.subtotal,
    this.restaurantId,
    this.restaurantName,
    this.onDismiss,
  });

  static Future<void> show(
    BuildContext context, {
    required String message,
    required double subtotal,
    String? restaurantId,
    String? restaurantName,
    VoidCallback? onDismiss,
  }) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SwiggyCouponActionSheet(
        rawMessage: message,
        subtotal: subtotal,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Analyze error message intent
    final lowerMsg = rawMessage.toLowerCase();

    // Check menu section restriction
    String? extractedSection;
    final sectionMatch = RegExp(r"'([^']+)'\s+menu section", caseSensitive: false).firstMatch(rawMessage);
    if (sectionMatch != null && sectionMatch.groupCount >= 1) {
      extractedSection = sectionMatch.group(1);
    } else if (lowerMsg.contains('pizza')) {
      extractedSection = 'pizza';
    } else if (lowerMsg.contains('burger')) {
      extractedSection = 'burger';
    } else if (lowerMsg.contains('sandwich')) {
      extractedSection = 'sandwich';
    } else if (lowerMsg.contains('beverage') || lowerMsg.contains('drink') || lowerMsg.contains('shake')) {
      extractedSection = 'beverages';
    } else if (lowerMsg.contains('dessert') || lowerMsg.contains('ice cream')) {
      extractedSection = 'desserts';
    }

    // Check min order restriction
    double? minOrderRequirement;
    final minMatch = RegExp(r"Minimum order of ₹?([\d.]+)", caseSensitive: false).firstMatch(rawMessage);
    if (minMatch != null && minMatch.groupCount >= 1) {
      minOrderRequirement = double.tryParse(minMatch.group(1) ?? '');
    }

    // Determine visual style & CTAs
    final String emoji;
    final String tagText;
    final Color tagColor;
    final Color tagBg;
    final String title;
    final String primaryActionText;
    final IconData primaryActionIcon;
    final VoidCallback primaryAction;

    if (extractedSection != null && extractedSection.isNotEmpty) {
      final capSection = _capitalize(extractedSection);
      emoji = _getSectionEmoji(extractedSection);
      tagText = 'OFFER REQUIREMENT';
      tagColor = const Color(0xFFEA580C);
      tagBg = const Color(0xFFFFF7ED);
      title = 'Valid Only on ${capSection}s';
      primaryActionText = 'Explore ${capSection}s';
      primaryActionIcon = Icons.arrow_forward_rounded;
      primaryAction = () {
        Navigator.pop(context);

        // USER COMMAND: Redirect explore to Hot Pizza Lovers' pizza
        final isPizza = (extractedSection?.toLowerCase().contains('pizza') ?? false) || lowerMsg.contains('pizza');
        final targetRestId = isPizza ? 'REST-104' : (restaurantId ?? 'REST-104');
        final targetRestName = isPizza ? 'Hot Pizza Lovers' : (restaurantName ?? 'Hot Pizza Lovers');
        final targetTag = isPizza ? 'pizza' : (extractedSection ?? 'all');

        Navigator.push(
          context,
          FadeSlideRoute(
            page: CafeMenuScreen(
              restaurantId: targetRestId,
              restaurantName: targetRestName,
              initialCategoryTag: targetTag,
            ),
          ),
        );
      };
    } else if (minOrderRequirement != null && minOrderRequirement > subtotal) {
      final shortage = (minOrderRequirement - subtotal).toInt();
      emoji = '🛍️';
      tagText = 'CART VALUE SHORT';
      tagColor = const Color(0xFFD97706);
      tagBg = const Color(0xFFFEF3C7);
      title = 'Add ₹$shortage More to Unlock';
      primaryActionText = 'Add More Items';
      primaryActionIcon = Icons.add_shopping_cart_rounded;
      primaryAction = () {
        Navigator.pop(context);
        final isPizza = lowerMsg.contains('pizza') || (restaurantName?.toLowerCase().contains('pizza') ?? false);
        final targetRestId = isPizza ? 'REST-104' : (restaurantId ?? 'REST-104');
        final targetRestName = isPizza ? 'Hot Pizza Lovers' : (restaurantName ?? 'Hot Pizza Lovers');

        Navigator.push(
          context,
          FadeSlideRoute(
            page: CafeMenuScreen(
              restaurantId: targetRestId,
              restaurantName: targetRestName,
              initialCategoryTag: isPizza ? 'pizza' : null,
            ),
          ),
        );
      };
    } else {
      emoji = '🏷️';
      tagText = 'COUPON NOTICE';
      tagColor = const Color(0xFFE11D48);
      tagBg = const Color(0xFFFFF1F2);
      title = 'Coupon Not Applicable';
      final isPizza = lowerMsg.contains('pizza');
      primaryActionText = isPizza ? 'Explore Pizzas' : 'View All Offers';
      primaryActionIcon = isPizza ? Icons.arrow_forward_rounded : Icons.local_offer_rounded;
      primaryAction = () {
        Navigator.pop(context);
        if (isPizza) {
          Navigator.push(
            context,
            FadeSlideRoute(
              page: const CafeMenuScreen(
                restaurantId: 'REST-104',
                restaurantName: 'Hot Pizza Lovers',
                initialCategoryTag: 'pizza',
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            FadeSlideRoute(
              page: CouponsScreen(
                currentSubtotal: subtotal,
                restaurantId: restaurantId,
              ),
            ),
          );
        }
      };
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Swiggy Top Grabber Pill
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Soft Squircle Visual Anchor
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Status Tag Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: tagColor.withValues(alpha: 0.25), width: 1),
            ),
            child: Text(
              tagText,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: tagColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 4. Headline Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 17),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.slate900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // 5. Friendly Context Explanation Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rawMessage,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 6. Primary Action CTA Button (Swiggy High-Conversion Button)
          Bounceable(
            onTap: () {
              HapticFeedback.mediumImpact();
              primaryAction();
            },
            child: Container(
              height: 48,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFFF8A00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    primaryActionText,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    primaryActionIcon,
                    color: Colors.white,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 7. Secondary Dismiss Button
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              if (onDismiss != null) onDismiss!();
            },
            child: Container(
              height: 42,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: Center(
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _getSectionEmoji(String section) {
    final s = section.toLowerCase();
    if (s.contains('pizza')) return '🍕';
    if (s.contains('burger')) return '🍔';
    if (s.contains('sandwich')) return '🥪';
    if (s.contains('beverage') || s.contains('drink') || s.contains('shake') || s.contains('chai')) return '🥤';
    if (s.contains('biryani') || s.contains('rice')) return '🍗';
    if (s.contains('dessert') || s.contains('cake') || s.contains('ice cream')) return '🍨';
    if (s.contains('munchies') || s.contains('fries') || s.contains('snack')) return '🍟';
    if (s.contains('roll') || s.contains('wrap')) return '🌯';
    return '🍽️';
  }
}
