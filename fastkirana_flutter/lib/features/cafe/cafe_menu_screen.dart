import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import 'table_booking_screen.dart';

class CafeMenuScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  final String restaurantName;
  const CafeMenuScreen({super.key, required this.restaurantId, required this.restaurantName});

  @override
  ConsumerState<CafeMenuScreen> createState() => _CafeMenuScreenState();
}

class _CafeMenuScreenState extends ConsumerState<CafeMenuScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = ['All', 'Coffee', 'Snacks', 'Desserts', 'Beverages'];

  final List<Map<String, dynamic>> _menuItems = [
    {'name': 'Cappuccino', 'price': 120, 'image': '☕', 'category': 'Coffee', 'veg': true, 'rating': 4.5, 'desc': 'Freshly brewed with foam'},
    {'name': 'Masala Chai', 'price': 30, 'image': '🍵', 'category': 'Beverages', 'veg': true, 'rating': 4.7, 'desc': 'Authentic Indian chai'},
    {'name': 'Veg Burger', 'price': 89, 'image': '🍔', 'category': 'Snacks', 'veg': true, 'rating': 4.3, 'desc': 'Loaded with veggies'},
    {'name': 'French Fries', 'price': 79, 'image': '🍟', 'category': 'Snacks', 'veg': true, 'rating': 4.4, 'desc': 'Crispy golden fries'},
    {'name': 'Cold Coffee', 'price': 99, 'image': '🥤', 'category': 'Coffee', 'veg': true, 'rating': 4.5, 'desc': 'Chilled with ice cream'},
    {'name': 'Brownie', 'price': 149, 'image': '🍰', 'category': 'Desserts', 'veg': true, 'rating': 4.8, 'desc': 'Chocolate fudge'},
    {'name': 'Paneer Roll', 'price': 89, 'image': '🌯', 'category': 'Snacks', 'veg': true, 'rating': 4.2, 'desc': 'Spicy paneer wrap'},
    {'name': 'Chocolate Shake', 'price': 129, 'image': '🍫', 'category': 'Beverages', 'veg': true, 'rating': 4.6, 'desc': 'Rich & creamy'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: AppDesignSystem.cafeAccent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppDesignSystem.cafeAccent, const Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(widget.restaurantName, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('⭐ 4.5', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                            const SizedBox(width: 12),
                            Text('20-25 mins', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                            const SizedBox(width: 12),
                            Text('₹300 for two', style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_rounded, size: 12, color: AppDesignSystem.primary),
                              const SizedBox(width: 4),
                              Text('Reserve a Table', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppDesignSystem.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: Text(widget.restaurantName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            actions: [
              IconButton(icon: const Icon(Icons.book_rounded, color: Colors.white), onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TableBookingScreen(restaurantId: widget.restaurantId, restaurantName: widget.restaurantName),
                ));
              }),
              IconButton(icon: const Icon(Icons.favorite_border_rounded, color: Colors.white), onPressed: () {}),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryHeaderDelegate(_categories, _tabController),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _categories.map((cat) => _buildMenuList(cat)).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuList(String category) {
    final items = category == 'All' ? _menuItems : _menuItems.where((m) => m['category'] == category).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildMenuItem(items[index]),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Row(
        children: [
          // Veg dot
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: item['veg'] ? Colors.green : Colors.red, width: 2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item['veg'] ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary)),
                const SizedBox(height: 4),
                Text(item['desc'], style: GoogleFonts.inter(fontSize: 12, color: AppDesignSystem.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('₹${item['price']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                    const SizedBox(width: 8),
                    Text('⭐ ${item['rating']}', style: GoogleFonts.inter(fontSize: 11, color: AppDesignSystem.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppDesignSystem.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(item['image'], style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              ref.read(cartProvider.notifier).addItem(item['name'], 1);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item['name']} added'),
                  backgroundColor: AppDesignSystem.success,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('ADD', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final TabController controller;
  _CategoryHeaderDelegate(this.categories, this.controller);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppDesignSystem.background,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        labelColor: AppDesignSystem.primary,
        unselectedLabelColor: AppDesignSystem.textSecondary,
        indicatorColor: AppDesignSystem.primary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800),
        tabs: categories.map((c) => Tab(text: c)).toList(),
      ),
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) => false;
}