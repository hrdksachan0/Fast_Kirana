import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/utils/validators.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';
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
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

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
        const SnackBar(
          content: Text('No items to reorder in this order'),
          behavior: SnackBarBehavior.floating,
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
        content: Text('Reordered ${items.length} items to cart!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Open Cart Screen directly
    Navigator.push(context, FadeSlideRoute(page: const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final ordersAsync = ref.watch(ordersProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Orders',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: textDark,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: primaryRed),
            onPressed: () {
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
                // 1. Dual Sub-Tabs (Active Orders vs Past History)
                _buildSubTabs(activeOrders.length, pastOrders.length),
                const SizedBox(height: 14),

                // 2. Search Box
                _buildSearchBox(),
                const SizedBox(height: 12),

                // 3. Status Filters (ALL / DELIVERED / CANCELLED) for History tab
                if (_selectedTab == 'HISTORY') ...[
                  _buildStatusFilterPills(),
                  const SizedBox(height: 14),
                ],

                // 4. Order List
                if (currentList.isEmpty)
                  _buildEmptyState()
                else
                  AnimationLimiter(
                    child: Column(
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 375),
                        childAnimationBuilder: (widget) => SlideAnimation(
                          verticalOffset: 30.0,
                          child: FadeInAnimation(child: widget),
                        ),
                        children: currentList
                            .map((order) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
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
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Unable to load orders', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(ordersProvider(userId)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryRed),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  // 1. Sub-Tabs Capsule
  Widget _buildSubTabs(int activeCount, int historyCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 'ACTIVE');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'ACTIVE' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 'ACTIVE'
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Live Orders',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _selectedTab == 'ACTIVE' ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedTab == 'ACTIVE' ? textDark : textMuted,
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$activeCount',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = 'HISTORY');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 'HISTORY' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 'HISTORY'
                      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Order History',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _selectedTab == 'HISTORY' ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedTab == 'HISTORY' ? textDark : textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$historyCount',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textDark),
                      ),
                    ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: textDark),
        decoration: InputDecoration(
          hintText: 'Search by item name or order ID...',
          hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Color(0xFF9CA3AF)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _statusFilter = f);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? primaryRed : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? primaryRed : const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  f,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 4. Order Card (1:1 with Web)
  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    final statusBg = _getStatusBg(order.status);
    final items = order.items ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Order ID + Date + Status Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${order.readableId ?? order.id.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: textDark,
                          ),
                        ),
                        if (order.shopName != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.shopName!,
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Helpers.formatDate(order.createdAt),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textMuted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status.displayName.toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Items Preview List
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: items.isEmpty
                ? Text('1 order batch', style: GoogleFonts.inter(fontSize: 12, color: textMuted))
                : Column(
                    children: items.take(2).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            children: [
                              Text('${item.quantity}x', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF4B5563))),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('₹${(item.price * item.quantity).toInt()}', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: textDark)),
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
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
              ),
            ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Footer Row: Total Price + Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: textMuted)),
                    Text(
                      '₹${order.total.toInt()}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: textDark),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Reorder Button
                    OutlinedButton.icon(
                      onPressed: () => _reorderItems(context, order),
                      icon: const Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF374151)),
                      label: const Text('Reorder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Track Order Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, FadeSlideRoute(page: OrderDetailScreen(order: order)));
                      },
                      icon: const Icon(Icons.location_on_outlined, size: 13, color: Colors.white),
                      label: const Text('Track'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text('🛍️', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 'ACTIVE' ? 'No Live Active Orders' : 'No Order History Found',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Your placed orders will appear here in real-time',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFD97706);
      case OrderStatus.confirmed:
        return const Color(0xFF2563EB);
      case OrderStatus.packed:
      case OrderStatus.shipped:
        return const Color(0xFF059669);
      case OrderStatus.delivered:
        return const Color(0xFF16A34A);
      case OrderStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  Color _getStatusBg(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFEF3C7);
      case OrderStatus.confirmed:
        return const Color(0xFFDBEAFE);
      case OrderStatus.packed:
      case OrderStatus.shipped:
        return const Color(0xFFD1FAE5);
      case OrderStatus.delivered:
        return const Color(0xFFDCFCE7);
      case OrderStatus.cancelled:
        return const Color(0xFFFEE2E2);
    }
  }
}
