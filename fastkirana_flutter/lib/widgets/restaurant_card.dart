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

  String _getFallbackAsset(String name, String slug) {
    final lower = '$name $slug'.toLowerCase();
    if (lower.contains('a.s') || lower.contains('burger')) {
      return 'assets/categories/cafe_burgers_category.png';
    } else if (lower.contains('wedson') || lower.contains('pizza')) {
      return 'assets/categories/cafe_pizza_category.png';
    } else if (lower.contains('bal udyan') || lower.contains('thali') || lower.contains('cafe')) {
      return 'assets/categories/cafe_category.png';
    }
    return 'assets/categories/cafe_category.png';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final offer = r.discountOffer ?? 'FLAT 5% OFF';
    final isOpen = r.isOpen;
    final fallbackAsset = _getFallbackAsset(r.name, r.slug);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: widget.onTap ??
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CafeMenuScreen(
                      restaurantId: r.id,
                      restaurantName: r.name,
                      restaurant: r,
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
                  // 1. Left: Restaurant Image with Favourite & Clean Surface
                  Stack(
                    children: [
                      Container(
                        width: 114,
                        height: 134,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: (r.bannerUrl != null && r.bannerUrl!.isNotEmpty && r.bannerUrl!.startsWith('http'))
                              ? CachedNetworkImage(
                                  imageUrl: r.bannerUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Image.asset(
                                    fallbackAsset,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/categories/cafe_category.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Image.asset(
                                  fallbackAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/categories/cafe_category.png',
                                    fit: BoxFit.cover,
                                  ),
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
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
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
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE11D48),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'CLOSED',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
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
                        // Restaurant Name + Verified Badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.name,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: Color(0xFF0284C7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Badges: Rating & Top Rated & Pure Veg
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            // Clean Star Rating
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 11, color: Color(0xFFD97706)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${r.rating > 0 ? r.rating : 4.5}',
                                    style: GoogleFonts.inter(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                  if (r.totalRatings > 0)
                                    Text(
                                      ' (${r.totalRatings})',
                                      style: GoogleFonts.inter(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFEDD5)),
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
                                      color: const Color(0xFFC2410C),
                                      letterSpacing: 0.2,
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
                                  borderRadius: BorderRadius.circular(6),
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
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF15803D),
                                        letterSpacing: 0.2,
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
                                r.address != null && r.address!.isNotEmpty
                                    ? r.address!
                                    : 'Nagar Palika, Ghatampur',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),

                        // Offer Badge with Flame
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Text(
                            '🔥 $offer',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFEA580C),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Bottom Row: Free Delivery + Explore CTA
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFF16A34A)),
                                Text(
                                  'Fast Delivery',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEA580C).withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Explore',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 12,
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
