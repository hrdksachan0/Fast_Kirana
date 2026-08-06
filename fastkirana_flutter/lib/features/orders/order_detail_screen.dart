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
      appBar: AppBar(
        title: Text('Order Details', style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: Colors.white,
        )),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderHeader(),
            const SizedBox(height: 16),
            _buildOrderTimeline(),
            const SizedBox(height: 16),
            _buildItemsSection(),
            const SizedBox(height: 16),
            _buildBillSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.readableId ?? order.id.substring(0, 8).toUpperCase(),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                order.status.displayName,
                style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppDesignSystem.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Helpers.formatDate(order.createdAt),
            style: GoogleFonts.poppins(fontSize: 12, color: AppDesignSystem.textSecondary),
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
          Text('Order Status', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length, (index) {
              final isActive = index <= currentIndex;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isActive ? AppDesignSystem.primary : AppDesignSystem.borderLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.check : Icons.circle_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index],
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppDesignSystem.textPrimary : AppDesignSystem.textTertiary,
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
          Text('Items', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
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
                  child: const Icon(Icons.shopping_bag, color: AppDesignSystem.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Qty: ${item.quantity}', style: GoogleFonts.poppins(fontSize: 11, color: AppDesignSystem.textSecondary)),
                    ],
                  ),
                ),
                Text(
                  Helpers.formatPrice(item.lineTotal),
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
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
          Text('Bill Summary', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildBillRow('Subtotal', Helpers.formatPrice(order.subtotal)),
          _buildBillRow('Discount', '-${Helpers.formatPrice(order.discount)}'),
          _buildBillRow('Delivery Fee', Helpers.formatPrice(order.deliveryFee)),
          _buildBillRow('Taxes', Helpers.formatPrice(order.taxes)),
          const Divider(height: 24),
          _buildBillRow('Total', Helpers.formatPrice(order.total), isBold: true),
          const SizedBox(height: 8),
          _buildBillRow('Payment Method', order.paymentMethod.displayName),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w400,
            color: isBold ? AppDesignSystem.textPrimary : AppDesignSystem.textSecondary,
          )),
          Text(value, style: GoogleFonts.poppins(
            fontSize: isBold ? 18 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? AppDesignSystem.primary : AppDesignSystem.textPrimary,
          )),
        ],
      ),
    );
  }
}