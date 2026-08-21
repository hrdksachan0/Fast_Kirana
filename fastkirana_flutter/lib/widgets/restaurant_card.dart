import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/restaurant.dart';
import '../core/theme/design_system.dart';
import '../features/cafe/cafe_menu_screen.dart';

class RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
  });

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  bool _isFavorite = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final offer = r.discountOffer ?? 'FLAT 5% OFF';
    final isOpen = r.isOpen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
        border: Border.all(color: AppDesignSystem.border),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
          onTap: widget.onTap ??
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CafeMenuScreen(
                      restaurantId: r.id,
                      restaurantName: r.name,
                    ),
                  ),
                );
              },
          child: Opacity(
            opacity: isOpen ? 1.0 : 0.75,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Left: Restaurant Image with Favourite & Closed Overlay
                  Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 128,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                          child: (r.bannerUrl != null && r.bannerUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: r.bannerUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF97316),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Text('🍽️', style: TextStyle(fontSize: 38)),
                                  ),
                                )
                              : const Center(
                                  child: Text('🍽️', style: TextStyle(fontSize: 38)),
                                ),
                        ),
                      ),

                      // Favourite Heart Button
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isFavorite = !_isFavorite);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.35),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 15,
                              color: _isFavorite ? const Color(0xFFEF4444) : Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // Closed Overlay (if not open)
                      if (!isOpen)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE11D48),
                                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                                ),
                                child: Text(
                                  'CLOSED',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // 2. Right: Info Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Restaurant Name + 3-Dot Overflow Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppDesignSystem.textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.more_vert_rounded,
                              size: 16,
                              color: Color(0xFF9CA3AF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Badges: Top Rated & Pure Veg
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🏆', style: TextStyle(fontSize: 8.5)),
                                  const SizedBox(width: 2.5),
                                  Text(
                                    'TOP RATED',
                                    style: GoogleFonts.inter(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (r.isPureVeg)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                                  border: Border.all(color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🌿', style: TextStyle(fontSize: 8.5)),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      'PURE VEG',
                                      style: GoogleFonts.inter(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Location text
                        Row(
                          children: [
                            const Text('📍', style: TextStyle(fontSize: 9.5)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                r.address ?? 'Ghatampur Market',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppDesignSystem.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Offer Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Text(
                            '🔥 $offer',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Divider before Bottom Row
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        const SizedBox(height: 6),

                        // Bottom Row: Prep Time + Explore Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '⚡ Fast Delivery',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppDesignSystem.textMuted,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEA580C), Color(0xFFD97706)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA580C).withOpacity(0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Explore',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
