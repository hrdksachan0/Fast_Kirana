import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../widgets/empty_state.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import 'order_tracking_screen.dart';

final ordersProvider = FutureProvider.family<List<Order>, String>((ref, userId) async {
  return OrderRepository(ref.read(dioProvider)).getOrders(userId);
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const Color primaryRed = AppDesignSystem.primary;
  static const Color primaryRedLight = AppDesignSystem.primaryLight;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

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
        backgroundColor: AppDesignSystem.green600,
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
      backgroundColor: AppDesignSystem.slate50,
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
            fontSize: Responsive.scaledFontSize(context, 18),
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedTab = 'HISTORY');
              });
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
                padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), Responsive.scale(context, 12), Responsive.horizontalPadding(context), 40),
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
          loading: () => ListView.builder(
            padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), Responsive.scale(context, 12), Responsive.horizontalPadding(context), 40),
            itemCount: 4,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: OrderCardSkeleton(),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppDesignSystem.danger),
                  const SizedBox(height: 12),
                  Text('Failed to load orders',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w800, color: slateDark)),
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
        color: AppDesignSystem.slate100,
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
                          color: AppDesignSystem.green600,
                        ),
                      ),
                    Text(
                      'Live Orders',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: _selectedTab == 'ACTIVE' ? FontWeight.w900 : FontWeight.w600,
                        color: _selectedTab == 'ACTIVE' ? slateDark : slateMuted,
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.green100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$activeCount',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.green700,
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
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: _selectedTab == 'HISTORY' ? FontWeight.w900 : FontWeight.w600,
                        color: _selectedTab == 'HISTORY' ? slateDark : slateMuted,
                      ),
                    ),
                    if (historyCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$historyCount',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
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
        border: Border.all(color: AppDesignSystem.slate200),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600, color: slateDark),
        decoration: InputDecoration(
          hintText: 'Search items or order ID...',
          hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate400),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppDesignSystem.slate400),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: AppDesignSystem.slate400),
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
                    color: isSelected ? slateDark : AppDesignSystem.slate200,
                  ),
                ),
                child: Text(
                  f,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppDesignSystem.slate600,
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

    Color statusColor = AppDesignSystem.blue600;
    Color statusBg = AppDesignSystem.blue50;
    String statusText = order.status.displayName.toUpperCase();

    if (isDelivered) {
      statusColor = AppDesignSystem.green600;
      statusBg = AppDesignSystem.green100;
    } else if (isCancelled) {
      statusColor = AppDesignSystem.red600;
      statusBg = AppDesignSystem.statusCancelled;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? AppDesignSystem.blue200 : AppDesignSystem.slate100,
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
                        fontSize: Responsive.scaledFontSize(context, 15.5),
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
                              fontSize: Responsive.scaledFontSize(context, 10),
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
                              ? AppDesignSystem.orange50
                              : AppDesignSystem.statusPending,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: shopName.contains('Restaurant') || shopName.contains('Cafe')
                                ? AppDesignSystem.orange200
                                : AppDesignSystem.yellow200,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shopName.contains('Restaurant') || shopName.contains('Cafe') ? '🍽️ ' : '🏪 ',
                              style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10)),
                            ),
                            Flexible(
                              child: Text(
                                shopName,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: shopName.contains('Restaurant') || shopName.contains('Cafe')
                                      ? AppDesignSystem.orange700
                                      : AppDesignSystem.statusPendingText,
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
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: slateMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // Items Preview List
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: items.isEmpty
                ? Text('1 order batch', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted))
                : Column(
                    children: items.take(2).map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.slate100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.slate600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12),
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
                                  fontSize: Responsive.scaledFontSize(context, 12),
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
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: slateMuted),
              ),
            ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // Footer: Total Bill + Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Bill', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w500, color: slateMuted)),
                    Text(
                      '₹${order.total.toInt()}',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: slateDark),
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
                          border: Border.all(color: AppDesignSystem.slate300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 14, color: AppDesignSystem.slate700),
                            const SizedBox(width: 4),
                            Text(
                              'Reorder',
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.slate700),
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
                                  colors: [AppDesignSystem.green700, AppDesignSystem.accentDark],
                                )
                              : const LinearGradient(
                                  colors: [primaryRed, primaryRedLight],
                                ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: (isActive ? AppDesignSystem.green700 : primaryRed).withValues(alpha: 0.25),
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
                              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w900, color: Colors.white),
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
          bgTint: isActive ? AppDesignSystem.orange50 : AppDesignSystem.sky50,
          onCta: () {
            if (isActive) {
              Navigator.pop(context);
            } else {
              final nav = Navigator.of(context);
              while (nav.canPop()) {
                nav.pop();
              }
            }
          },
        ),
      ),
    );
  }
}

// ─── Skeleton Loading for Order Cards ───────────────────────────────────────
class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppDesignSystem.slate100,
      highlightColor: AppDesignSystem.background,
      period: const Duration(milliseconds: 1200),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignSystem.slate100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row skeleton
            Row(
              children: [
                _shimmerBox(80, 14),
                const Spacer(),
                _shimmerBox(60, 12),
              ],
            ),
            const SizedBox(height: 12),
            // Items row skeleton
            Row(
              children: [
                _shimmerBox(44, 44, radius: 8),
                const SizedBox(width: 10),
                Expanded(child: _shimmerBox(double.infinity, 14)),
              ],
            ),
            const SizedBox(height: 10),
            // Bottom row skeleton
            Row(
              children: [
                Expanded(child: _shimmerBox(120, 12)),
                _shimmerBox(70, 28, radius: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double width, double height, {double radius = 6}) {
    return Container(
      width: width == double.infinity ? double.infinity : width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
