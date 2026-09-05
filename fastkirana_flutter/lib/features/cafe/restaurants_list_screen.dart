import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../providers/restaurant_provider.dart';
import '../../widgets/restaurant_card.dart';
import '../../widgets/floating_cart_bar.dart';
import '../../widgets/unserviceable_location_banner.dart';

class RestaurantsListScreen extends ConsumerStatefulWidget {
  const RestaurantsListScreen({super.key});

  @override
  ConsumerState<RestaurantsListScreen> createState() => _RestaurantsListScreenState();
}

class _RestaurantsListScreenState extends ConsumerState<RestaurantsListScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, String>> _cuisineCategories = [
    {'id': 'all', 'label': 'All', 'emoji': '🍽️'},
    {'id': 'specials', 'label': 'Specials', 'emoji': '🔥'},
    {'id': 'rolls', 'label': 'Rolls', 'emoji': '🌯'},
    {'id': 'biryani', 'label': 'Biryani', 'emoji': '🍚'},
    {'id': 'cakes', 'label': 'Cakes', 'emoji': '🎂'},
    {'id': 'naan', 'label': 'Naan', 'emoji': '🫓'},
    {'id': 'burgers', 'label': 'Burgers', 'emoji': '🍔'},
    {'id': 'chinese', 'label': 'Chinese', 'emoji': '🥡'},
    {'id': 'pizza', 'label': 'Pizza', 'emoji': '🍕'},
    {'id': 'south-indian', 'label': 'South Indian', 'emoji': '🍛'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantsProvider);
    final filteredRestaurants = ref.watch(filteredRestaurantsProvider);
    final selectedCuisine = ref.watch(selectedCuisineProvider);
    final pureVegOnly = ref.watch(pureVegFilterProvider);
    final offersOnly = ref.watch(offersFilterProvider);
    final ratingFilter = ref.watch(ratingFilterProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restaurants',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Freshly prepared from top partner kitchens',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10),
                fontWeight: FontWeight.w600,
                color: AppDesignSystem.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 0. Location Unserviceable Banner
              const UnserviceableLocationBanner(),

              // 1. Search Bar Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                    border: Border.all(color: AppDesignSystem.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(restaurantSearchQueryProvider.notifier).state = val;
                    },
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search restaurants, rolls, burgers, biryani...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.textMuted,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.orange600),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppDesignSystem.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(restaurantSearchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),

              // 2. Cuisine Filter Chips Row
              Container(
                height: 46,
                color: Colors.white,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _cuisineCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _cuisineCategories[index];
                    final isSelected = selectedCuisine == cat['id'];

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedCuisineProvider.notifier).state = cat['id']!;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppDesignSystem.orange600 : AppDesignSystem.orange50,
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                          border: Border.all(
                            color: isSelected ? AppDesignSystem.orange600 : AppDesignSystem.orange200,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat['emoji']!, style: TextStyle(fontSize: Responsive.scaledFontSize(context, 12))),
                            const SizedBox(width: 5),
                            Text(
                              cat['label']!,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                color: isSelected ? Colors.white : AppDesignSystem.orange700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. Quick Filter Toggles Row (Pure Veg, Offers, 4.5+ Rating)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill(
                        label: 'Pure Veg 🌱',
                        isActive: pureVegOnly,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(pureVegFilterProvider.notifier).state = !pureVegOnly;
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill(
                        label: 'Great Offers 🏷️',
                        isActive: offersOnly,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(offersFilterProvider.notifier).state = !offersOnly;
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill(
                        label: 'Top Rated ⭐ 4.5+',
                        isActive: ratingFilter,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(ratingFilterProvider.notifier).state = !ratingFilter;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppDesignSystem.surfaceMuted),

              // 4. Restaurant Listing View
              Expanded(
                child: restaurantsAsync.when(
                  data: (_) {
                    if (filteredRestaurants.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 48))),
                            const SizedBox(height: 12),
                            Text(
                              'No restaurants match your filters',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14),
                                fontWeight: FontWeight.w800,
                                color: AppDesignSystem.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try clearing filters or search query',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12),
                                color: AppDesignSystem.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: filteredRestaurants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final restaurant = filteredRestaurants[index];
                        return RestaurantCard(restaurant: restaurant);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppDesignSystem.orange600),
                  ),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('⚠️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 48))),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load restaurants',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 14),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppDesignSystem.orange600,
                          ),
                          onPressed: () => ref.invalidate(restaurantsProvider),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Floating Cart Bar (Exact Homepage Design)
          const FloatingCartBar(bottomOffset: 16),
        ],
      ),
    );
  }

  Widget _buildFilterPill({required String label, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppDesignSystem.orange50 : Colors.white,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusSm),
          border: Border.all(
            color: isActive ? AppDesignSystem.orange600 : AppDesignSystem.border,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 11),
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? AppDesignSystem.orange600 : AppDesignSystem.gray600,
          ),
        ),
      ),
    );
  }
}