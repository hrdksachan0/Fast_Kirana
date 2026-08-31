import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../data/models/restaurant.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import 'admin_orders_list.dart';
import 'admin_products.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _currentIndex = 0;
  final bool _isStoreOpen = true;

  static const Color primaryRed = Color(0xFFE20A22);

  final List<Widget> _screens = const [
    AdminOrdersScreen(showAppBar: false),
    AdminProductsScreen(showAppBar: false),
  ];

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: primaryRed, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout Admin?',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 17, color: const Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Text(
          'You will be signed out from the Ghatampur Store Operations portal.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await ref.read(authProvider.notifier).clear();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _openOperationsModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _OperationsBottomSheet(),
    );
  }

  void _handleBackPress() {
    HapticFeedback.lightImpact();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              // Top Executive Header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: _handleBackPress,
                      child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Brand & Store Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'FastKirana',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: primaryRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OPS',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1.5),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Color(0xFF10B981), blurRadius: 3, spreadRadius: 0.5),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ghatampur · Live',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Store Operations Modal Trigger (Open/Closed Pill)
                  GestureDetector(
                    onTap: _openOperationsModal,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isStoreOpen ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isStoreOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isStoreOpen ? const Color(0xFF34D399) : const Color(0xFFF87171),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isStoreOpen ? 'OPEN' : 'CLOSED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: _isStoreOpen ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 13,
                            color: _isStoreOpen ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Exit / Logout Button (Compact & Aesthetic Icon Button)
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: const Center(
                        child: Icon(Icons.power_settings_new_rounded, color: Color(0xFFEF4444), size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!_isStoreOpen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: const Color(0xFFDC2626),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Store is CLOSED. Customers will see Store Closed banner.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

            // Main Content Area
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ),
          ],
        ),
      ),

      // Modern Floating Pill Navigation Dock (Zero Overflow)
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: _buildDockItem(
                  index: 0,
                  label: 'Orders',
                  sub: 'Live & History',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDockItem(
                  index: 1,
                  label: 'Products',
                  sub: 'Grocery & Outlets',
                  icon: Icons.inventory_2_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem({
    required int index,
    required String label,
    required String sub,
    required IconData icon,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                Text(
                  sub,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationsBottomSheet extends ConsumerStatefulWidget {
  const _OperationsBottomSheet();

  @override
  ConsumerState<_OperationsBottomSheet> createState() => _OperationsBottomSheetState();
}

class _OperationsBottomSheetState extends ConsumerState<_OperationsBottomSheet> {
  bool _masterOpen = true;
  bool _martOpen = true;
  final Map<String, bool> _outletsOpen = {};
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settings = ref.read(storeSettingsProvider).valueOrNull;
    if (settings != null) {
      _masterOpen = settings.groceryMartOpen || settings.restaurantOpen;
      _martOpen = settings.groceryMartOpen;
    }
  }

  Future<void> _updateMart(bool val) async {
    HapticFeedback.selectionClick();
    setState(() => _martOpen = val);

    final sb = SupabaseService.client;
    if (sb != null) {
      try {
        await sb.from('store_settings').upsert({
          'key': 'grocery_mart_open',
          'value': val.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    try {
      await ref.read(dioProvider).post('/api/admin/store-status', data: {
        'groceryMartOpen': val,
      });
    } catch (_) {}

    ref.refresh(storeSettingsProvider);
  }

  Future<void> _updateRestaurant(Restaurant rest, bool val) async {
    HapticFeedback.selectionClick();
    setState(() => _outletsOpen[rest.id] = val);

    final sb = SupabaseService.client;
    if (sb != null) {
      try {
        await sb.from('restaurants').update({
          'isOpen': val,
        }).eq('id', rest.id);
      } catch (_) {}
    }

    try {
      await ref.read(dioProvider).patch('/api/restaurants/${rest.id}', data: {
        'isOpen': val,
      });
    } catch (_) {}

    ref.refresh(restaurantsProvider);
  }

  Future<void> _updateMaster(bool val) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _masterOpen = val;
      _martOpen = val;
    });

    final sb = SupabaseService.client;
    if (sb != null) {
      try {
        await sb.from('store_settings').upsert({
          'key': 'store_open',
          'value': val.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        await sb.from('store_settings').upsert({
          'key': 'grocery_mart_open',
          'value': val.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    try {
      await ref.read(dioProvider).post('/api/admin/store-status', data: {
        'isOpen': val,
        'groceryMartOpen': val,
      });
    } catch (_) {}

    ref.refresh(storeSettingsProvider);
    ref.refresh(restaurantsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(restaurantsProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store & Outlet Operations',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Control live ordering for Mart & Restaurants',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Master Emergency Hub Switch
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _masterOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _masterOpen ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _masterOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _masterOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: _masterOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚨 Master Hub Switch',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _masterOpen
                                    ? 'All customer ordering is active'
                                    : 'Emergency: Entire store & all outlets paused',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _masterOpen ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _masterOpen,
                          activeColor: const Color(0xFF16A34A),
                          activeTrackColor: const Color(0xFFDCFCE7),
                          onChanged: _updateMaster,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section Title: Grocery Mart
                  Text(
                    'GROCERY MART & DARKSTORE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2. FastKirana Grocery Mart
                  _buildOutletTile(
                    title: 'FastKirana Mart',
                    subtitle: 'Kirana, dairy, daily essentials delivery',
                    icon: Icons.shopping_basket_rounded,
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    isOpen: _martOpen,
                    onChanged: _updateMart,
                  ),

                  const SizedBox(height: 16),

                  // Section Title: Restaurants
                  Text(
                    'RESTAURANT FOOD OUTLETS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 4. Dynamic Restaurant Outlets (Wedson, A.S., Bal Udyan, etc.)
                  restaurantsAsync.when(
                    data: (restaurants) {
                      if (restaurants.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No restaurants configured',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        );
                      }
                      return Column(
                        children: restaurants.map((rest) {
                          final isOpen = _outletsOpen[rest.id] ?? rest.isOpen;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildOutletTile(
                              title: rest.name,
                              subtitle: rest.cuisineTags.isNotEmpty
                                  ? rest.cuisineTags.take(2).join(', ')
                                  : 'Fresh meals & dining',
                              icon: Icons.restaurant_rounded,
                              iconColor: const Color(0xFFE20A22),
                              bgColor: const Color(0xFFFEF2F2),
                              isOpen: isOpen,
                              onChanged: (val) => _updateRestaurant(rest, val),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE20A22)),
                      ),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isOpen,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isOpen ? 'OPEN' : 'CLOSED',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isOpen ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: isOpen,
            activeColor: const Color(0xFF16A34A),
            activeTrackColor: const Color(0xFFDCFCE7),
            inactiveThumbColor: const Color(0xFF94A3B8),
            inactiveTrackColor: const Color(0xFFE2E8F0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}