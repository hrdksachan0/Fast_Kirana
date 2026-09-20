import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/routes/page_transitions.dart';
import '../../../../data/models/brand_offer_card_data.dart';
import '../../../../data/models/restaurant.dart';
import '../../../../providers/banner_provider.dart';
import '../../../../providers/restaurant_provider.dart';
import '../../../../widgets/curated_brand_offer_card.dart';
import '../../../../widgets/restaurant_card.dart';
import '../../cafe/cafe_menu_screen.dart';

class HomeFoodStorefront extends ConsumerWidget {
  const HomeFoodStorefront({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantsAsync = ref.watch(homeRestaurantsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Top Restaurants & Cafes Simple Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Text('🍽️', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Restaurants & Cafes',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Order food from your favorite spots in Ghatampur',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                    const SizedBox(width: 2),
                    Text(
                      'FAST FOOD',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 8.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Restaurant Cards List
        restaurantsAsync.when(
          data: (restaurants) => ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: restaurants.length,
            itemBuilder: (context, index) => RestaurantCard(restaurant: restaurants[index]),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: AppDesignSystem.cafeAccent),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
