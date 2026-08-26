import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/restaurant.dart';
import '../core/theme/design_system.dart';
import '../core/routes/page_transitions.dart';
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

  Widget _buildRestaurantImage(Restaurant r) {
    // 1. Check if logoUrl is a remote URL
    if (r.logoUrl != null && r.logoUrl!.isNotEmpty && r.logoUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: r.logoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildImagePlaceholder(),
        errorWidget: (_, __, ___) => _buildLocalOrFallbackImage(r),
      );
    }

    // 2. Check if bannerUrl is a remote URL and logoUrl is not available
    if (r.logoUrl == null && r.bannerUrl != null && r.bannerUrl!.isNotEmpty && r.bannerUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: r.bannerUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildImagePlaceholder(),
        errorWidget: (_, __, ___) => _buildLocalOrFallbackImage(r),
      );
    }

    // 3. Check local uploaded assets from Manage Outlets
    return _buildLocalOrFallbackImage(r);
  }

  Widget _buildLocalOrFallbackImage(Restaurant r) {
    final lower = '${r.name} ${r.slug} ${r.logoUrl ?? ""} ${r.bannerUrl ?? ""}'.toLowerCase();

    if (lower.contains('a.s') || lower.contains('as-restaurant') || lower.contains('cafe_all_menu')) {
      return Image.asset(
        'assets/categories/cafe_all_menu_category.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultFallback(),
      );
    } else if (lower.contains('wedson')) {
      return Image.asset(
        'assets/categories/wedson_restaurant_bg.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/categories/wedson_restaurant_banner.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultFallback(),
        ),
      );
    } else if (lower.contains('bal udyan') || lower.contains('thali')) {
      return Image.asset(
        'assets/categories/cafe_category.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultFallback(),
      );
    }

    return _buildDefaultFallback();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEA580C)),
        ),
      ),
    );
  }

  Widget _buildDefaultFallback() {
    return Image.asset(
      'assets/categories/cafe_category.png',
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final offer = r.discountOffer ?? '5% EXTRA OFF';
    final isOpen = r.isOpen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0).withOpacity(0.8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onTap ??
              () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  FadeSlideRoute(
                    page: CafeMenuScreen(
                      restaurantId: r.id,
                      restaurantName: r.name,
                      restaurant: r,
                    ),
                  ),
                );
              },
          child: Opacity(
            opacity: isOpen ? 1.0 : 0.75,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Left: Food / Logo Image with Heart
                      Stack(
                        children: [
                          Container(
                            width: 108,
                            height: 124,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: _buildRestaurantImage(r),
                            ),
                          ),

                          // Heart Icon
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
                                  size: 14,
                                  color: _isFavorite ? const Color(0xFFEF4444) : Colors.white,
                                ),
                              ),
                            ),
                          ),

                          // Closed Overlay
                          if (!isOpen)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE11D48),
                                      borderRadius: BorderRadius.circular(10),
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

                      // 2. Right: Restaurant Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Restaurant Name
                            Padding(
                              padding: const EdgeInsets.only(right: 22),
                              child: Text(
                                r.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Badges: 🏆 TOP RATED + 🌿 PURE VEG
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFFEDD5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🏆', style: TextStyle(fontSize: 8.5)),
                                      const SizedBox(width: 3),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🌿', style: TextStyle(fontSize: 8.5)),
                                      const SizedBox(width: 3),
                                      Text(
                                        'PURE VEG',
                                        style: GoogleFonts.inter(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF047857),
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
                                        : 'Nagar Palika Ghatampur',
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
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFEA580C),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Bottom Row: ⚡ 30m Prep + EXPLORE ➔ Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('⚡', style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '30m Prep',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEA580C).withOpacity(0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'EXPLORE',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Text(
                                        '➔',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
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

                // Top Right 3-dots
                Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 16,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
