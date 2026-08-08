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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider('user_placeholder'));

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppDesignSystem.surface,
            elevation: 0,
            title: Text(
              'My Orders',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.textPrimary,
              ),
            ),
            iconTheme: const IconThemeData(color: AppDesignSystem.textPrimary),
          ),
          ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyOrders(),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildOrderCard(context, orders[index]),
                  childCount: orders.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error: $e', style: const TextStyle(color: AppDesignSystem.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 60, color: AppDesignSystem.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'No orders yet',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start shopping to see your orders here',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppDesignSystem.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final statusColor = _getStatusColor(order.status);
    final statusBg = _getStatusBgColor(order.status);

    return BrandCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.readableId ?? order.id.substring(0, 8).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (order.items != null && order.items!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: order.items!.length.clamp(0, 4),
                itemBuilder: (context, index) {
                  final item = order.items![index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.borderLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              width: 50,
                              height: 50,
                            )
                          : const Icon(Icons.shopping_bag, size: 20, color: AppDesignSystem.textMuted),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Helpers.formatDate(order.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
              Text(
                Helpers.formatPrice(order.total),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.primary,
                ),
              ),
            ],
          ),
        ],
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
}