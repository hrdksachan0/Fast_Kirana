import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../data/models/order.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String orderId) async {
    final message = Uri.encodeComponent('Hi FastKirana Support, I need help with my Order #$orderId');
    final uri = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusIndex = _getStatusStepIndex(order.status);
    final itemsList = order.items ?? [];
    final orderIdDisplay = order.readableId ?? order.id.substring(0, 8).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Tracking',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textDark,
                letterSpacing: -0.3,
              ),
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: orderIdDisplay));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order ID #$orderIdDisplay copied!'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Row(
                children: [
                  Text(
                    'ID: #$orderIdDisplay',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 10, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined, color: primaryRed),
            onPressed: () => _makeCall('+917054470303'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Live ETA & Status Header Card
            _buildStatusHeaderCard(),
            const SizedBox(height: 16),

            // 2. Order Tracking Timeline
            Container(
              padding: const EdgeInsets.all(18),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Order Tracker',
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getStatusBg(order.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status.displayName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _getStatusColor(order.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTimelineStep(
                    0,
                    'Order Placed',
                    'Your order has been verified by store',
                    statusIndex >= 0,
                    timeText: Helpers.formatDate(order.createdAt),
                  ),
                  _buildTimelineStep(
                    1,
                    'Order Confirmed & Packed',
                    'Items packed fresh at Ghatampur darkstore',
                    statusIndex >= 1,
                  ),
                  _buildTimelineStep(
                    2,
                    'Out for Delivery',
                    'Rider is on the way to your address',
                    statusIndex >= 2,
                  ),
                  _buildTimelineStep(
                    3,
                    order.status == OrderStatus.cancelled ? 'Order Cancelled' : 'Delivered',
                    order.status == OrderStatus.cancelled ? 'Order was cancelled' : 'Package handed over at doorstep',
                    statusIndex >= 3,
                    isLast: true,
                    isCancelled: order.status == OrderStatus.cancelled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Delivery Address & Contact Card
            Container(
              padding: const EdgeInsets.all(18),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 16, color: primaryRed),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Delivery Address',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ghatampur Market, Kanpur Nagar, UP - 209206',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Help with Order?',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                          Text(
                            '+91 70544 70303',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // WhatsApp Action Button
                          IconButton(
                            onPressed: () => _openWhatsApp('917054470303', orderIdDisplay),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFDCFCE7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Call Action Button
                          ElevatedButton.icon(
                            onPressed: () => _makeCall('+917054470303'),
                            icon: const Icon(Icons.phone, size: 13, color: Colors.white),
                            label: const Text('Call Support'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Itemized Bill Summary
            Container(
              padding: const EdgeInsets.all(18),
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
                  Text(
                    'Bill Details',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (itemsList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Items processed by store',
                        style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                      ),
                    )
                  else
                    ...itemsList.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${(item.price * item.quantity).toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                        )),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 8),
                  _buildBillRow('Item Total', '₹${order.subtotal.toInt()}'),
                  if (order.discount > 0)
                    _buildBillRow('Discount Savings', '-₹${order.discount.toInt()}', isGreen: true),
                  _buildBillRow(
                    'Delivery Fee',
                    order.deliveryFee == 0 ? 'FREE' : '₹${order.deliveryFee.toInt()}',
                    isGreen: order.deliveryFee == 0,
                  ),
                  _buildBillRow('Taxes & Packaging', '₹${order.taxes.toInt()}'),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Paid',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: textDark,
                            ),
                          ),
                          Text(
                            order.paymentMethod.displayName,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
                          ),
                        ],
                      ),
                      Text(
                        '₹${order.total.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: primaryRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Status Header Card (Adaptive for Confirmed, Delivered, and Cancelled)
  Widget _buildStatusHeaderCard() {
    if (order.status == OrderStatus.delivered) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Delivered Successfully!',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF065F46)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Delivered fresh from Ghatampur Hub',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF047857)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (order.status == OrderStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cancel_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Order was Cancelled',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF991B1B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Contact support for refund or reorder assistance',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Default Live Tracking (Pending / Confirmed / Packed / Out for Delivery)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🛵', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Delivery in 10-15 mins',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Delivering from Ghatampur Hub Store',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getStatusStepIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.packed:
      case OrderStatus.shipped:
        return 2;
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return 3;
    }
  }

  Widget _buildTimelineStep(
    int stepIndex,
    String title,
    String desc,
    bool isDone, {
    bool isLast = false,
    bool isCancelled = false,
    String? timeText,
  }) {
    Color activeColor = isCancelled ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDone ? activeColor : const Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? Icon(isCancelled ? Icons.close : Icons.check, size: 14, color: Colors.white)
                    : Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF9CA3AF), shape: BoxShape.circle)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isDone ? activeColor : const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
                        color: isDone ? textDark : const Color(0xFF9CA3AF),
                      ),
                    ),
                    if (timeText != null)
                      Text(
                        timeText,
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w500, color: textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isGreen ? const Color(0xFF16A34A) : textDark,
            ),
          ),
        ],
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