import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _orders = _getMockOrders();
        _isLoading = false;
      });
    }
  }

  List<Order> _getMockOrders() {
    return [
      Order(
        id: '1',
        readableId: '#FK-2401',
        status: 'out_for_delivery',
        paymentMethod: 'COD',
        paymentStatus: 'pending',
        subtotal: 245,
        discount: 20,
        deliveryFee: 0,
        total: 245,
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        estimatedDelivery: DateTime.now().add(const Duration(minutes: 5)),
        items: [
          OrderItem(id: '1', name: 'Amul Toned Milk', imageUrl: '', price: 42, quantity: 2, unit: '1L'),
          OrderItem(id: '2', name: 'Himalaya Cookies', imageUrl: '', price: 65, quantity: 1, unit: '300g'),
        ],
      ),
      Order(
        id: '2',
        readableId: '#FK-2398',
        status: 'delivered',
        paymentMethod: 'UPI',
        paymentStatus: 'paid',
        subtotal: 340,
        discount: 50,
        deliveryFee: 0,
        total: 340,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        estimatedDelivery: DateTime.now().subtract(const Duration(days: 2)),
        items: [
          OrderItem(id: '3', name: 'Organic Rice', imageUrl: '', price: 290, quantity: 1, unit: '1kg'),
        ],
      ),
      Order(
        id: '3',
        readableId: '#FK-2390',
        status: 'delivered',
        paymentMethod: 'Wallet',
        paymentStatus: 'paid',
        subtotal: 180,
        discount: 0,
        deliveryFee: 0,
        total: 180,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        estimatedDelivery: DateTime.now().subtract(const Duration(days: 5)),
        items: [
          OrderItem(id: '4', name: 'Bread Sandwich', imageUrl: '', price: 45, quantity: 2, unit: '400g'),
          OrderItem(id: '5', name: 'Butter Cube', imageUrl: '', price: 90, quantity: 1, unit: '100g'),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                      size: 22, color: AppTheme.textPrimary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'My Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Active'),
                  Tab(text: 'Delivered'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Orders list
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList(
                    _orders.where((o) => o.status != 'delivered' && o.status != 'cancelled').toList()
                  ),
                  _buildOrdersList(
                    _orders.where((o) => o.status == 'delivered').toList()
                  ),
                  _buildOrdersList([]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Order> orders) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text('No orders here', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(order: order);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  Color get _statusColor {
    switch (order.status) {
      case 'delivered': return const Color(0xFF4ADE80);
      case 'out_for_delivery': return const Color(0xFFF59E0B);
      case 'confirmed': return const Color(0xFF60A5FA);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return AppTheme.textSecondary;
    }
  }

  String get _statusText {
    switch (order.status) {
      case 'delivered': return 'Delivered';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'confirmed': return 'Confirmed';
      case 'cancelled': return 'Cancelled';
      default: return 'Processing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.readableId ?? '#FK-${order.id}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Items preview
            ...order.items.take(2).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(item.imageUrl!,
                                fit: BoxFit.cover, width: 36, height: 36),
                            )
                          : Icon(Icons.shopping_bag_outlined,
                            size: 16, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.name} x${item.quantity}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toInt()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (order.items.length > 2)
              Padding(
                padding: const EdgeInsets.only(left: 44, top: 4),
                child: Text(
                  '+${order.items.length - 2} more items',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),

            const SizedBox(height: 10),
            Divider(color: AppTheme.border.withOpacity(0.5), height: 1),
            const SizedBox(height: 8),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                Text(
                  '₹${order.total.toInt()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Actions
            Row(
              children: [
                if (order.status == 'delivered')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton(
                        side: BorderSide(color: AppTheme.border.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(AppTheme.surface),
                      ),
                      child: const Text('Reorder',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (order.status == 'delivered') const SizedBox(width: 8),
                if (order.status == 'out_for_delivery')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(AppTheme.primaryDark),
                      ),
                      child: const Text('Track Order',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (order.status == 'out_for_delivery') const SizedBox(width: 8),
                if (order.status == 'confirmed' || order.status == 'out_for_delivery')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton(
                        side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(AppTheme.surface),
                      ),
                      child: Text('Cancel',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444))),
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
