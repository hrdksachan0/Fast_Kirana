import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/utils/validators.dart';
import '../../core/network/api_client.dart';
import '../../widgets/empty_state.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import 'order_tracking_screen.dart';
import 'order_detail_screen.dart';

final ordersProvider = FutureProvider.family<List<Order>, String>((ref, userId) async {
  return OrderRepository(ref.read(dioProvider)).getOrders(userId);
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const Color primaryRed = Color(0xFFE20A22);
  static const Color primaryRedLight = Color(0xFFFF2D4B);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  // Sub-tabs: 'ACTIVE' | 'HISTORY'
  String _selectedTab = 'ACTIVE';
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reorderItems(BuildContext context, Order order) {
    HapticFeedback.heavyImpact();
    final items = order.items ?? [];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No items in this order to reorder'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final cartNotifier = ref.read(cartProvider.notifier);
    for (final item in items) {
      final pid = item.productId ?? item.id;
      final product = Product.fromJson({
        'id': pid,
        'name': item.name,
        'slug': pid,
        'price': item.price,
        'mrp': item.price,
        'imageUrl': item.imageUrl,
        'categoryId': 'grocery',
        'unit': '1 unit',
        'stock': 50,
      });
      cartNotifier.addProduct(product, item.quantity, item.selectedVariant);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Text('Added ${items.length} items to your cart!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.push(context, FadeSlideRoute(page: const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final ordersAsync = ref.watch(ordersProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: slateDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Orders',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: slateDark,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryRed),
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.invalidate(ordersProvider(userId));
            },
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: Responsive.wideMaxContentWidth,
        fillHeight: true,
        child: ordersAsync.when(
          data: (allOrders) {
            // Separate Active vs Completed/Cancelled orders
            final activeOrders = allOrders.where((o) =>
                o.status == OrderStatus.pending ||
                o.status == OrderStatus.confirmed ||
                o.status == OrderStatus.packed ||
                o.status == OrderStatus.shipped).toList();

            final pastOrders = allOrders.where((o) =>
                o.status == OrderStatus.delivered ||
                o.status == OrderStatus.cancelled).toList();

            // Default to HISTORY tab if there are no active orders
            if (_selectedTab == 'ACTIVE' && activeOrders.isEmpty && pastOrders.isNotEmpty) {
              _selectedTab = 'HISTORY';
            }

            List<Order> currentList = _selectedTab == 'ACTIVE' ? activeOrders : pastOrders;

            // Filter by search query
            if (_searchQuery.trim().isNotEmpty) {
              final q = _searchQuery.trim().toLowerCase();
              currentList = currentList.where((o) {
                final idMatch = (o.readableId ?? o.id).toLowerCase().contains(q);
                final itemMatch = (o.items ?? []).any((item) => item.name.toLowerCase().contains(q));
                return idMatch || itemMatch;
              }).toList();
            }

            // Filter by status pill
            if (_statusFilter != 'ALL') {
              currentList = currentList.where((o) => o.status.name.toUpperCase() == _statusFilter).toList();
            }

            return RefreshIndicator(
              color: primaryRed,
              onRefresh: () async {
                ref.invalidate(ordersProvider(userId));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  // 1. Premium Segmented Tab Switcher
                  _buildSegmentedTabs(activeOrders.length, pastOrders.length),
                  const SizedBox(height: 12),

                  // 2. Ultra-clean Search Bar
                  _buildSearchBox(),
                  const SizedBox(height: 10),

                  // 3. Status Filters (ALL / DELIVERED / CANCELLED)
                  if (_selectedTab == 'HISTORY') ...[
                    _buildStatusFilterPills(),
                    const SizedBox(height: 12),
                  ],

                  // 4. Order List
                  if (currentList.isEmpty)
                    _buildEmptyState()
                  else
                    AnimationLimiter(
                      child: Column(
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 320),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 20.0,
                            child: FadeInAnimation(child: widget),
                          ),
                          children: currentList
                              .map((order) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildOrderCard(order),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: primaryRed),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                  const SizedBox(height: 12),
                  Text('Failed to load orders',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: slateDark)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(ordersProvider(userId)),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
                    child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. Segmented Tabs Switcher
  Widget _buildSegmentedTabs(int activeCount, int historyCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Live Orders Tab
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 'ACTIVE');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'ACTIVE' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _selectedTab == 'ACTIVE'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (activeCount > 0)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    Text(
                      'Live Orders',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _selectedTab == 'ACTIVE' ? FontWeight.w900 : FontWeight.w600,
                        color: _selectedTab == 'ACTIVE' ? slateDark : slateMuted,
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$activeCount',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Order History Tab
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 'HISTORY');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'HISTORY' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _selectedTab == 'HISTORY'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Order History',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _selectedTab == 'HISTORY' ? FontWeight.w900 : FontWeight.w600,
                        color: _selectedTab == 'HISTORY' ? slateDark : slateMuted,
                      ),
                    ),
                    if (historyCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$historyCount',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: slateDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Search Box
  Widget _buildSearchBox() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: slateDark),
        decoration: InputDecoration(
          hintText: 'Search items or order ID...',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // 3. Status Filter Pills
  Widget _buildStatusFilterPills() {
    final filters = ['ALL', 'DELIVERED', 'CANCELLED'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _statusFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _statusFilter = f);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5.5),
                decoration: BoxDecoration(
                  color: isSelected ? slateDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? slateDark : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  f,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 4. Ultra-Premium Order Card
  Widget _buildOrderCard(Order order) {
    final isDelivered = order.status == OrderStatus.delivered;
    final isCancelled = order.status == OrderStatus.cancelled;
    final isActive = !isDelivered && !isCancelled;
    final items = order.items ?? [];
    final shopName = order.shopName?.isNotEmpty == true ? order.shopName! : 'FastKirana Darkstore';

    Color statusColor = const Color(0xFF2563EB);
    Color statusBg = const Color(0xFFEFF6FF);
    String statusText = order.status.displayName.toUpperCase();

    if (isDelivered) {
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
    } else if (isCancelled) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFFBFDBFE) : const Color(0xFFF1F5F9),
          width: isActive ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.06 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID + Status on top, Store + Date below
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Order ID + Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '#${order.displayId}',
                      style: GoogleFonts.inter(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                          Text(
                            statusText,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Sub-Row: Store Badge + Date Time (Guaranteed Zero Truncation)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: shopName.contains('Restaurant') || shopName.contains('Cafe')
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: shopName.contains('Restaurant') || shopName.contains('Cafe')
                                ? const Color(0xFFFFEDD5)
                                : const Color(0xFFFDE68A),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shopName.contains('Restaurant') || shopName.contains('Cafe') ? '🍽️ ' : '🏪 ',
                              style: const TextStyle(fontSize: 10),
                            ),
                            Flexible(
                              child: Text(
                                shopName,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: shopName.contains('Restaurant') || shopName.contains('Cafe')
                                      ? const Color(0xFFC2410C)
                                      : const Color(0xFF92400E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM, hh:mm a').format(order.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: slateMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Items Preview List
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: items.isEmpty
                ? Text('1 order batch', style: GoogleFonts.inter(fontSize: 12, color: slateMuted))
                : Column(
                    children: items.take(2).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: slateDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₹${(item.price * item.quantity).toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: slateDark,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                  ),
          ),

          if (items.length > 2)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                '+${items.length - 2} more items',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: slateMuted),
              ),
            ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Footer: Total Bill + Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Bill', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: slateMuted)),
                    Text(
                      '₹${order.total.toInt()}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: slateDark),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Reorder Button
                    Bounceable(
                      onTap: () => _reorderItems(context, order),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF334155)),
                            const SizedBox(width: 4),
                            Text(
                              'Reorder',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Track / View Details Button
                    Bounceable(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          FadeSlideRoute(
                            page: OrderTrackingScreen(orderId: order.id),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [Color(0xFF00A344), Color(0xFF008736)],
                                )
                              : const LinearGradient(
                                  colors: [primaryRed, primaryRedLight],
                                ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: (isActive ? const Color(0xFF00A344) : primaryRed).withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? Icons.navigation_rounded : Icons.receipt_long_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'Track Live' : 'Details',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Empty State
  Widget _buildEmptyState() {
    final isActive = _selectedTab == 'ACTIVE';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: EmptyState(
          emoji: isActive ? '📦' : '🗂️',
          title: isActive ? 'No Live Active Orders' : 'No Order History Found',
          subtitle: isActive
              ? 'You don\'t have any active orders right now.\nOrder something delicious fresh!'
              : 'You haven\'t placed any orders yet.\nYour orders will appear here.',
          ctaLabel: isActive ? 'Browse Products' : 'Start Shopping',
          bgTint: isActive ? const Color(0xFFFFF7ED) : const Color(0xFFF0F9FF),
          onCta: () {
            if (isActive) {
              Navigator.pop(context);
            } else {
              final nav = Navigator.of(context);
              while (nav.canPop()) nav.pop();
            }
          },
        ),
      ),
    );
  }
}
