import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../data/models/order.dart';
import '../../widgets/brand_card.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppDesignSystem.primary,
            elevation: 0,
            title: Text(
              'Order Details',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildOrderHeader(),
                const SizedBox(height: 12),
                _buildOrderTimeline(),
                const SizedBox(height: 12),
                _buildItemsSection(),
                const SizedBox(height: 12),
                _buildBillSummary(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    return BrandCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.readableId ?? order.id.substring(0, 8).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Helpers.formatDate(order.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppDesignSystem.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.status.displayName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTimeline() {
    final steps = ['Pending', 'Confirmed', 'Packed', 'Shipped', 'Delivered'];
    final currentIndex = steps.indexOf(order.status.displayName);
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Status',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length, (index) {
              final isActive = index <= currentIndex;
              return Expanded(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (index < steps.length - 1)
                          Positioned(
                            top: 12,
                            left: 30,
                            right: 0,
                            child: Container(
                              height: 2,
                              color: isActive && index < currentIndex
                                  ? AppDesignSystem.primary
                                  : AppDesignSystem.borderLight,
                            ),
                          ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isActive ? AppDesignSystem.primary : AppDesignSystem.borderLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isActive ? Icons.check_rounded : Icons.circle_outlined,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index],
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? AppDesignSystem.textPrimary
                            : AppDesignSystem.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    if (order.items == null || order.items!.isEmpty) return const SizedBox.shrink();
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${order.items!.length})',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...order.items!.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.borderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_bag, size: 20, color: AppDesignSystem.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Qty: ${item.quantity}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Helpers.formatPrice(item.lineTotal),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildBillSummary() {
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Details',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildBillRow('Subtotal', Helpers.formatPrice(order.subtotal)),
          if (order.discount > 0)
            _buildBillRow('Discount', '-${Helpers.formatPrice(order.discount)}', color: AppDesignSystem.accent),
          _buildBillRow('Delivery', Helpers.formatPrice(order.deliveryFee)),
          _buildBillRow('Taxes', Helpers.formatPrice(order.taxes)),
          if (order.miscFee > 0)
            _buildBillRow('Misc Fee', Helpers.formatPrice(order.miscFee)),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                Helpers.formatPrice(order.total),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBillRow('Payment Method', order.paymentMethod.displayName),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppDesignSystem.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppDesignSystem.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}