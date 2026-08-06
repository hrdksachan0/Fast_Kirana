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
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: Colors.white,
        )),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmptyOrders(context);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(ordersProvider('user_placeholder')),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) => _buildOrderCard(context, orders[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: AppDesignSystem.danger)),
        ),
      ),
    );
  }

  Widget _buildEmptyOrders(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 64, color: AppDesignSystem.primary),
          ),
          const SizedBox(height: 24),
          Text('No orders yet', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Start shopping to see your orders here', style: GoogleFonts.poppins(color: AppDesignSystem.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final statusColor = _getStatusColor(order.status);
    final statusBg = _getStatusBgColor(order.status);

    return BrandCard(
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
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (order.items != null && order.items!.isNotEmpty)
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: order.items!.length.clamp(0, 4),
                itemBuilder: (context, index) {
                  final item = order.items![index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: item.imageUrl ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: AppDesignSystem.borderLight,
                          child: const Icon(Icons.shopping_bag),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Helpers.formatDate(order.createdAt),
                style: GoogleFonts.poppins(fontSize: 12, color: AppDesignSystem.textSecondary),
              ),
              Text(
                Helpers.formatPrice(order.total),
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: AppDesignSystem.primary),
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