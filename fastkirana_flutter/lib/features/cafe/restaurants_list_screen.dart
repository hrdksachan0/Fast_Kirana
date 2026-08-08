import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';

class RestaurantsListScreen extends StatelessWidget {
  const RestaurantsListScreen({super.key});

  final List<Map<String, dynamic>> _restaurants = const [
    {'name': 'Chai Wai', 'image': '☕', 'rating': 4.5, 'time': '15 min', 'price': '₹300 for two', 'cuisine': 'Cafe, Snacks'},
    {'name': 'Pizza Hub', 'image': '🍕', 'rating': 4.3, 'time': '25 min', 'price': '₹400 for two', 'cuisine': 'Pizza, Italian'},
    {'name': 'Dosa Point', 'image': '🥞', 'rating': 4.7, 'time': '20 min', 'price': '₹250 for two', 'cuisine': 'South Indian'},
    {'name': 'Burger King Local', 'image': '🍔', 'rating': 4.2, 'time': '18 min', 'price': '₹350 for two', 'cuisine': 'Burger, American'},
    {'name': 'Sweet Tooth', 'image': '🍰', 'rating': 4.6, 'time': '12 min', 'price': '₹200 for two', 'cuisine': 'Desserts, Ice Cream'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Cafes & Restaurants',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final r = _restaurants[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => CafeMenuScreen(restaurantId: 'rest_$index', restaurantName: r['name'] as String),
            )),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.background,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Center(child: Text(r['image'] as String, style: const TextStyle(fontSize: 64))),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: AppDesignSystem.warning),
                              const SizedBox(width: 4),
                              Text('${r['rating']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['name'] as String, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                        const SizedBox(height: 4),
                        Text(r['cuisine'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 14, color: AppDesignSystem.textSecondary),
                            const SizedBox(width: 4),
                            Text(r['time'], style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                            const SizedBox(width: 12),
                            Icon(Icons.currency_rupee_rounded, size: 14, color: AppDesignSystem.textSecondary),
                            const SizedBox(width: 4),
                            Text(r['price'], style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}