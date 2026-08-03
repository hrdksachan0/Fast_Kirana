import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/banner.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../widgets/hero_banner.dart';
import '../widgets/category_grid.dart';
import '../widgets/product_list.dart';
import '../widgets/section_header.dart';
import '../widgets/tab_slider.dart';
import '../widgets/floating_cart_bar.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/product_horizontal_list.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0;
  int _bottomNavIndex = 0;

  List<Product> _flashDeals = [];
  List<Product> _bestSellers = [];
  List<Product> _topPicks = [];
  List<Category> _categories = [];
  List<Banner> _banners = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.fetchCategories(),
        ApiService.fetchBanners(),
        ApiService.fetchFlashDeals(),
        ApiService.fetchBestSellers(),
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0] as List<Category>;
          _banners = results[1] as List<Banner>;
          _flashDeals = results[2] as List<Product>;
          _bestSellers = results[3] as List<Product>;
          _topPicks = _bestSellers.take(8).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            GroceryFoodTabSlider(
              initialIndex: _activeTab,
              onTabChanged: (index) {
                setState(() => _activeTab = index);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAllData,
                color: AppTheme.primary,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    if (_activeTab == 0) ...[
                      if (_isLoading) ...[
                        const ShimmerBanner(),
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: ShimmerCategoryGrid(count: 8),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 230,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: 4,
                            itemBuilder: (_, __) => const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: ShimmerProductCard(),
                            ),
                          ),
                        ),
                      ] else if (_error != null) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 16),
                                Text('Couldn\'t load data', style: TextStyle(color: AppTheme.textSecondary)),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _loadAllData,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        HeroBanner(
                          banners: _banners,
                          onBannerTap: (link) {},
                        ),
                        const SizedBox(height: 20),
                        CategoryGrid(
                          categories: _categories,
                          onCategoryTap: (slug) {},
                        ),
                        const SizedBox(height: 18),
                        _buildTimeBasedSection(),
                        const SizedBox(height: 20),
                        if (_flashDeals.isNotEmpty)
                          ProductHorizontalList(
                            products: _flashDeals,
                            title: 'Flash Deals',
                            showTimer: true,
                          ),
                        if (_flashDeals.isNotEmpty) const SizedBox(height: 20),
                        if (_bestSellers.isNotEmpty)
                          ProductHorizontalList(
                            products: _bestSellers,
                            title: 'Best Sellers',
                          ),
                        if (_bestSellers.isNotEmpty) const SizedBox(height: 20),
                        if (_topPicks.isNotEmpty)
                          ProductHorizontalList(
                            products: _topPicks,
                            title: 'Top Picks',
                          ),
                      ],
                    ] else ...[
                      _buildFoodTabContent(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          HapticFeedback.lightImpact();
          switch (index) {
            case 0:
              Navigator.popUntil(context, (route) => route.isFirst);
              break;
            case 1:
              Navigator.pushNamed(context, '/categories');
              break;
            case 2:
              Navigator.pushNamed(context, '/search');
              break;
            case 3:
              Navigator.pushNamed(context, '/account');
              break;
          }
        },
      ),
      floatingActionButton: const FloatingCartBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flash_on_rounded, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '10 min',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.primary),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.notifications_outlined, size: 20, color: AppTheme.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: () => setState(() => _bottomNavIndex = 3),
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.textSecondary),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SearchBar(
            onFocus: () => setState(() => _bottomNavIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBasedSection() {
    final hour = DateTime.now().hour;
    String emoji, title, subtitle;

    if (hour >= 6 && hour < 10) {
      emoji = '☀️';
      title = 'Good Morning!';
      subtitle = 'Start your day fresh';
    } else if (hour >= 10 && hour < 14) {
      emoji = '🍱';
      title = 'Lunch Time!';
      subtitle = 'Quick bites delivered';
    } else if (hour >= 14 && hour < 17) {
      emoji = '☕';
      title = 'Snack Time';
      subtitle = 'Chai & snacks pairing';
    } else if (hour >= 17 && hour < 21) {
      emoji = '🌙';
      title = 'Evening Cravings';
      subtitle = 'Hot snacks & cold drinks';
    } else {
      emoji = '😴';
      title = 'Late Night?';
      subtitle = 'We\'re still here for you';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
                )),
                const SizedBox(height: 1),
                Text(subtitle, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary,
                )),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
        ],
      ),
    );
  }

  Widget _buildFoodTabContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.restaurant_rounded, size: 48, color: AppTheme.cafeAccent.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('Cafe & Restaurant', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary,
            )),
            const SizedBox(height: 4),
            Text('Hot food, coffee & more coming soon', style: TextStyle(
              fontSize: 12, color: AppTheme.textMuted,
            )),
          ],
        ),
      ),
    );
  }
}
