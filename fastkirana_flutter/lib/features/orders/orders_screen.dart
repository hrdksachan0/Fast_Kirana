import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../widgets/brand_card.dart';
import 'order_detail_screen.dart';

final ordersProvider = FutureProvider.family<List<Order>, String>((ref, userId) async {
  return OrderRepository(ref.read(dioProvider)).getOrders(userId);
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  static const Color primaryGreen = Color(0xFF047857);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider('user_placeholder'));

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppDesignSystem.surface,
            elevation: 0,
            title: Text(
              'My Orders',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
            ),
            iconTheme: const IconThemeData(color: textDark),
          ),
          SliverToBoxAdapter(
            child: ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) return _buildEmptyOrders(context);
                return Column(
                  children: [
                    _buildUnifiedTracker(),
                    const SizedBox(height: 16),
                    ...orders.map((order) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: _buildOrderCard(context, order),
                    )),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator(color: primaryGreen)),
              ),
              error: (e, _) => _buildEmptyOrders(context, message: 'Error loading orders: $e'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildUnifiedTracker() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF047857), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: primaryGreen.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Horizontal tracker timeline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTrackerStep('Confirmed', true, Icons.check_circle_rounded, true),
              _buildTrackerStep('Packed', true, Icons.inventory_2_rounded, true),
              _buildTrackerStep('Out', true, Icons.delivery_dining_rounded, false),
              _buildTrackerStep('Delivered', false, Icons.home_rounded, false),
            ],
          ),
          // Connecting line
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24),
            child: Stack(
              children: [
                Container(height: 3, color: Colors.white.withOpacity(0.2)),
                Container(
                  height: 3,
                  width: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerStep(String label, bool isActive, IconData icon, bool isFilled) {
    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isFilled ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isFilled ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.15), width: 2),
          ),
          child: Icon(icon, size: 20, color: isFilled ? Colors.white : Colors.white.withOpacity(0.4)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: isFilled ? FontWeight.w700 : FontWeight.w500,
            color: isFilled ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final statusColor = _getStatusColor(order.status);
    final statusBg = _getStatusBgColor(order.status);
    final statusName = order.status.displayName;

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => OrderDetailScreen(order: order),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppDesignSystem.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignSystem.borderLight),
          boxShadow: AppDesignSystem.shadowSm,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.borderLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${order.readableId ?? order.id.substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusName,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                ],
              ),
              if (order.items != null && order.items!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: order.items!.length.clamp(0, 5),
                    itemBuilder: (context, index) {
                      final item = order.items![index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppDesignSystem.borderLight),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(imageUrl: item.imageUrl!, fit: BoxFit.cover, width: 64, height: 64)
                              : Center(child: Text(_getEmoji(item.name), style: const TextStyle(fontSize: 28))),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppDesignSystem.divider),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: textMuted),
                      const SizedBox(width: 6),
                      Text(
                        Helpers.formatDate(order.createdAt),
                        style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${order.items?.length ?? 0} items',
                        style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Helpers.formatPrice(order.total),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: primaryGreen),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrders(BuildContext context, {String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(Icons.receipt_long_outlined, size: 60, color: primaryGreen.withOpacity(0.3)),
            ),
            const SizedBox(height: 28),
            Text(
              message ?? 'No orders yet',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
            ),
            const SizedBox(height: 8),
            Text(
              message == null ? 'Start shopping to see your orders here' : 'Please try again later',
              style: GoogleFonts.inter(fontSize: 14, color: textMuted),
              textAlign: TextAlign.center,
            ),
            if (message == null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: AppDesignSystem.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.shopping_bag_rounded, size: 18, color: Colors.white),
                  label: Text('Start Shopping', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return AppDesignSystem.statusPendingText;
      case OrderStatus.confirmed: return AppDesignSystem.statusConfirmedText;
      case OrderStatus.packed: return AppDesignSystem.statusPackedText;
      case OrderStatus.shipped: return AppDesignSystem.statusShippedText;
      case OrderStatus.delivered: return AppDesignSystem.statusDeliveredText;
      case OrderStatus.cancelled: return AppDesignSystem.statusCancelledText;
    }
  }

  Color _getStatusBgColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending: return AppDesignSystem.statusPending;
      case OrderStatus.confirmed: return AppDesignSystem.statusConfirmed;
      case OrderStatus.packed: return AppDesignSystem.statusPacked;
      case OrderStatus.shipped: return AppDesignSystem.statusShipped;
      case OrderStatus.delivered: return AppDesignSystem.statusDelivered;
      case OrderStatus.cancelled: return AppDesignSystem.statusCancelled;
    }
  }

  String _getEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('egg')) return '🥚';
    return '🛒';
  }
}
