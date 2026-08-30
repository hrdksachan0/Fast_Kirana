import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SponsoredAdCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? promoCode;
  final String? discountText;
  final String? imageUrl;
  final String? actionText;
  final VoidCallback? onTap;

  const SponsoredAdCard({
    super.key,
    this.title = '🔥 Special Offer — 20% OFF at AS Restaurant & Cafe',
    this.subtitle = 'Craving hot snacks & meals? Use coupon while ordering.',
    this.promoCode = 'FEAST20',
    this.discountText = 'FLAT 20% OFF',
    this.imageUrl,
    this.actionText = 'Order Now',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'SPONSORED PARTNER',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (discountText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Text(
                          discountText!,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFE11D48),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Content Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Text Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title ?? 'Special Partner Offer',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF78350F),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle ?? 'Discover trending local dishes & groceries.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF92400E),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.white.withOpacity(0.5),
                            child: const Center(child: Icon(Icons.restaurant_rounded, size: 20, color: Color(0xFFD97706))),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFD97706)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Action & Promo Code Row
                Row(
                  children: [
                    if (promoCode != null && promoCode!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: promoCode!));
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied coupon code "$promoCode" to clipboard!'),
                              backgroundColor: const Color(0xFF00A344),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFBBF24), style: BorderStyle.solid),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'CODE: ',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                              Text(
                                promoCode!,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF92400E),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.copy_rounded, size: 11, color: Color(0xFFB45309)),
                            ],
                          ),
                        ),
                      ),

                    const Spacer(),

                    // Order / Explore CTA
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97706).withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionText ?? 'Explore',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
