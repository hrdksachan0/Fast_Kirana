import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/restaurant.dart';
import '../core/theme/design_system.dart';
import '../core/config/app_config.dart';
import '../core/routes/page_transitions.dart';
import '../providers/address_provider.dart';
import '../features/cafe/cafe_menu_screen.dart';

class RestaurantCard extends ConsumerStatefulWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
  });

  @override
  ConsumerState<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends ConsumerState<RestaurantCard> {
  bool _isFavorite = false;

  Widget _buildRestaurantImage(Restaurant r) {
    // 1. Check if logoUrl is a remote URL
    if (r.logoUrl != null && r.logoUrl!.isNotEmpty && r.logoUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: r.logoUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        memCacheHeight: 400,
        placeholder: (_, __) => _buildImagePlaceholder(),
        errorWidget: (_, __, ___) => _buildLocalOrFallbackImage(r),
      );
    }

    // 2. Check if bannerUrl is a remote URL and logoUrl is not available
    if (r.logoUrl == null && r.bannerUrl != null && r.bannerUrl!.isNotEmpty && r.bannerUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: r.bannerUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        memCacheHeight: 400,
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
        'assets/categories/cafe_all_menu_category.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultFallback(),
      );
    } else if (lower.contains('wedson')) {
      return Image.asset(
        'assets/categories/wedson_restaurant_bg.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/categories/wedson_restaurant_banner.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDefaultFallback(),
        ),
      );
    } else if (lower.contains('bal udyan') || lower.contains('thali')) {
      return Image.asset(
        'assets/categories/cafe_category.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultFallback(),
      );
    } else if (lower.contains('pari') || lower.contains('dairy') || lower.contains('sweet')) {
      return Image.asset(
        'assets/categories/dairy_breakfast_category.webp',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultFallback(),
      );
    }

    return _buildDefaultFallback();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppDesignSystem.slate100,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.orange600),
        ),
      ),
    );
  }

  Widget _buildDefaultFallback() {
    return Image.asset(
      'assets/categories/cafe_category.webp',
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final isOpen = r.isOpen;
    final selectedAddress = ref.watch(selectedAddressProvider);

    // Dynamic distance calculation between user's chosen location and restaurant
    final userLat = (selectedAddress?.latitude != null && selectedAddress!.latitude != 0.0)
        ? selectedAddress.latitude!
        : AppConfig.darkstoreLat;
    final userLng = (selectedAddress?.longitude != null && selectedAddress!.longitude != 0.0)
        ? selectedAddress.longitude!
        : AppConfig.darkstoreLng;
    final restLat = r.lat ?? AppConfig.darkstoreLat;
    final restLng = r.lng ?? AppConfig.darkstoreLng;

    final distanceMeters = Geolocator.distanceBetween(userLat, userLng, restLat, restLng);
    final distanceKm = distanceMeters / 1000.0;

    final hasOffer = r.discountOffer != null && r.discountOffer!.trim().isNotEmpty;
    final offer = hasOffer ? r.discountOffer!.trim() : '';

    final addressText = (r.address != null && r.address!.isNotEmpty)
        ? r.address!
        : 'Ghatampur Market, UP';
    final ratingVal = r.rating > 0 ? r.rating : 4.8;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
                    FadeSlideRoute(
                      page: CafeMenuScreen(
                        restaurantId: r.id,
                        restaurantName: r.name,
                        restaurant: r,
                      ),
                    ),
                  );
                },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. TOP HERO IMAGE (Full-Width, 160px height)
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        child: _buildRestaurantImage(r),
                      ),
                    ),

                    // Top Gradient Shadow for badge contrast
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        ),
                      ),
                    ),

                    // Bottom Gradient Shadow for offer banner
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // Pure Veg Badge (Top Left)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PURE VEG',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF15803D),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Favorite Button (Top Right)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isFavorite = !_isFavorite);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 16,
                            color: _isFavorite ? const Color(0xFFEF4444) : Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Offer Ribbon (Bottom Left) - Only shown if restaurant has real offer
                    if (hasOffer)
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                offer.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Closed Overlay
                    if (!isOpen)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                'CLOSED FOR ORDERS',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // 2. BOTTOM DETAILS SECTION (Spacious, Zero-Squeeze)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Restaurant Title & Rating Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              r.name,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 17),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Rating Badge (e.g. ⭐ 4.8)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF15803D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ratingVal.toStringAsFixed(1),
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Cuisines / Category Tags (Optimized layout - chips/pills without ugly truncation)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: (r.cuisineTags.isNotEmpty
                                  ? r.cuisineTags
                                  : ['North Indian', 'Chinese', 'Fast Food', 'Biryani'])
                              .map((tag) => Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tag,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 11),
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Location & Real Distance Row (No "250 for two")
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              addressText,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Dynamic Distance Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me_rounded, size: 11, color: Color(0xFF0284C7)),
                                const SizedBox(width: 3),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0369A1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 12),

                      // Bottom Action Row: Free Delivery Tag + Clean Full Explore CTA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.delivery_dining_rounded, size: 13, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'FREE DELIVERY',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 9),
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF1D4ED8),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Explore Button (Fits easily with zero cut-off)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isOpen
                                    ? [const Color(0xFFF97316), const Color(0xFFEA580C)]
                                    : [const Color(0xFF64748B), const Color(0xFF475569)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isOpen
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isOpen ? 'EXPLORE MENU' : 'VIEW MENU',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
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
    );
  }
}
