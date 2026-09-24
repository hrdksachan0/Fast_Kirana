import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/restaurant.dart';
import '../core/theme/design_system.dart';
import '../core/config/app_config.dart';
import '../core/routes/page_transitions.dart';
import '../providers/address_provider.dart';
import '../providers/store_settings_provider.dart';
import '../core/utils/restaurant_utils.dart';
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

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favList = prefs.getStringList('favorite_restaurants') ?? [];
      if (mounted && favList.contains(widget.restaurant.id)) {
        setState(() => _isFavorite = true);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.selectionClick();
    setState(() => _isFavorite = !_isFavorite);
    try {
      final prefs = await SharedPreferences.getInstance();
      final favList = prefs.getStringList('favorite_restaurants') ?? [];
      if (_isFavorite) {
        if (!favList.contains(widget.restaurant.id)) {
          favList.add(widget.restaurant.id);
          await prefs.setStringList('favorite_restaurants', favList);
        }
      } else {
        favList.remove(widget.restaurant.id);
        await prefs.setStringList('favorite_restaurants', favList);
      }
    } catch (_) {}
  }

  static const Set<String> _bundledCategoryAssets = {
    'as_restaurant_banner.webp',
    'wedson_restaurant_bg.webp',
    'wedson_restaurant_banner.webp',
    'cafe_all_menu_category.webp',
    'cafe_banner.webp',
    'food_banner_bg.webp',
    'food_promo_banner.webp',
    'food_promo_banner_premium.webp',
    'cafe_category.webp',
    'dairy_breakfast_category.webp',
  };

  Widget _buildRestaurantImage(Restaurant r) {
    // 1. Check if bannerUrl is a remote URL (PRIORITY: Banner goes into card hero, matching Web app!)
    if (r.bannerUrl != null && r.bannerUrl!.isNotEmpty && r.bannerUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: r.bannerUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 600,
        memCacheHeight: 400,
        placeholder: (_, __) => _buildImagePlaceholder(),
        errorWidget: (_, __, ___) => _buildLocalOrFallbackImage(r),
      );
    }

    // 2. If bannerUrl is a local asset path or relative web path starting with '/'
    if (r.bannerUrl != null && r.bannerUrl!.isNotEmpty && r.bannerUrl!.startsWith('/')) {
      final assetName = r.bannerUrl!.substring(1);
      final webpName = assetName.endsWith('.png') ? '${assetName.substring(0, assetName.length - 4)}.webp' : assetName;
      if (_bundledCategoryAssets.contains(webpName)) {
        return Image.asset(
          'assets/categories/$webpName',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLocalOrFallbackImage(r),
        );
      }
      return CachedNetworkImage(
        imageUrl: 'https://www.fastkirana.in${r.bannerUrl}',
        fit: BoxFit.cover,
        memCacheWidth: 600,
        memCacheHeight: 400,
        placeholder: (_, __) => _buildImagePlaceholder(),
        errorWidget: (_, __, ___) => _buildLocalOrFallbackImage(r),
      );
    }

    // 3. Check if logoUrl is a remote URL (only if bannerUrl is not available)
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

    // 4. Check local uploaded assets or fallbacks
    return _buildLocalOrFallbackImage(r);
  }

  Widget _buildLocalOrFallbackImage(Restaurant r) {
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

  static String _formatDisplayAddress(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Ghatampur Market';
    var cleaned = raw.trim();
    // Strip pincodes or state patterns like ", UP 209206", ", Uttar Pradesh 209206"
    cleaned = cleaned.replaceAll(RegExp(r',\s*(?:UP|Uttar Pradesh)?\s*\d{6}\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b\d{6}\b'), '');
    // Strip trailing ", UP" or ", Uttar Pradesh"
    cleaned = cleaned.replaceAll(RegExp(r',\s*(?:UP|Uttar Pradesh)\s*$', caseSensitive: false), '');
    // Clean trailing commas and spaces
    cleaned = cleaned.replaceAll(RegExp(r'[\s,]+$'), '').trim();
    return cleaned.isNotEmpty ? cleaned : 'Ghatampur Market';
  }

  String _getDeliveryEta(double distanceKm, String rawDeliveryTime) {
    if (rawDeliveryTime.isNotEmpty &&
        rawDeliveryTime != 'Hot & Fresh' &&
        !rawDeliveryTime.toLowerCase().contains('fresh')) {
      return rawDeliveryTime;
    }
    if (distanceKm <= 1.5) return '20-25 mins';
    if (distanceKm <= 3.5) return '25-30 mins';
    return '30-40 mins';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final isOpen = RestaurantScheduleHelper.isRestaurantOpen(restaurant: r, storeSettings: settings);
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

    final rawOffer = (r.discountOffer != null && r.discountOffer!.trim().isNotEmpty)
        ? r.discountOffer!.trim()
        : (r.discountBadge != null && r.discountBadge!.trim().isNotEmpty
            ? r.discountBadge!.trim()
            : '');
    final hasOffer = rawOffer.isNotEmpty;
    final offer = rawOffer;
    final isSurgeAlert = r.activeOrdersCount >= 6;

    final addressText = _formatDisplayAddress(r.address);
    final ratingVal = r.rating > 0 ? r.rating : 4.8;
    final etaText = _getDeliveryEta(distanceKm, r.deliveryTime);

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
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
                // 1. TOP HERO IMAGE (Full-Width, 168px height)
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 168,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: _buildRestaurantImage(r),
                      ),
                    ),

                    // Top Gradient Shadow for badge contrast
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.50),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                      ),
                    ),

                    // Bottom Gradient Shadow for offer & ETA banner
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 65,
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

                    // Top Left Badges (Pure Veg & Surge Alert)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 52,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (r.isPureVeg) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFDCFCE7),
                                  width: 0.8,
                                ),
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
                                  const SizedBox(width: 4.5),
                                  Text(
                                    'PURE VEG',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF15803D),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (isSurgeAlert)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('⚡', style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        'HIGH DEMAND SURGE',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: Responsive.scaledFontSize(context, 8.5),
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Favorite Button (Top Right - Dynamic Persistent Bookmark)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(7.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 16.5,
                            color: _isFavorite ? const Color(0xFFEF4444) : Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Offer Ribbon (Bottom Left of Image - Dynamic Offer from Restaurant)
                    if (hasOffer)
                      Positioned(
                        bottom: 10,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                            ),
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEA580C).withValues(alpha: 0.40),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 10.5)),
                              const SizedBox(width: 4),
                              Text(
                                offer.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 9.5),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Delivery ETA & Prep Pill (Bottom Right of Image - Dynamic Real-Time ETA & Distance)
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                            width: 0.7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 3.5),
                            Text(
                              '${etaText.toUpperCase()} • ${distanceKm.toStringAsFixed(1)} KM',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
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
                            color: const Color(0xFF0F172A).withValues(alpha: 0.72),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'CLOSED FOR ORDERS',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    RestaurantScheduleHelper.getScheduleDescription(
                                      openTime: r.openTime,
                                      closeTime: r.closeTime,
                                    ),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withValues(alpha: 0.95),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // 2. BOTTOM DETAILS SECTION (Clean, Editorial, Truncation-Free)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 17.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Rating Badge (e.g. 5.0 ★)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF15803D),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ratingVal.toStringAsFixed(1),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.star_rounded, size: 12.5, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Cuisines / Category Tags (Bullet-Separated: 100% Truncation-Free)
                      Text(
                        (r.cuisineTags.isNotEmpty
                                ? r.cuisineTags.take(4)
                                : ['North Indian', 'Biryani', 'Chinese', 'Tandoori'])
                            .join(' • '),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Location & Distance Row (Sanitized Address: Zero "20..." Truncation)
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              addressText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 12),
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
                                const Icon(Icons.near_me_rounded, size: 10.5, color: Color(0xFF0284C7)),
                                const SizedBox(width: 3),
                                Text(
                                  '${distanceKm.toStringAsFixed(1)} km',
                                  style: GoogleFonts.plusJakartaSans(
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

                      // Bottom Action Row: Free Delivery Tag + Explore CTA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.delivery_dining_rounded, size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4.5),
                                Text(
                                  'FREE DELIVERY',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 9.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1D4ED8),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Explore Menu Button (Sleek Gradient Pill)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isOpen
                                    ? [const Color(0xFFEA580C), const Color(0xFFF97316)]
                                    : [const Color(0xFF64748B), const Color(0xFF475569)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isOpen
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFEA580C).withValues(alpha: 0.28),
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
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 10.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 12.5, color: Colors.white),
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
