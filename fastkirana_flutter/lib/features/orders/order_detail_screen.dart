import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/order.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF10B981);

  bool get isPickupOrder {
    final method = (order.deliveryMethod ?? '').toUpperCase();
    return method.contains('PICKUP');
  }

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

  int _getStatusStepIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.packed:
        return 2;
      case OrderStatus.shipped:
        return 3;
      case OrderStatus.delivered:
        return 4;
      case OrderStatus.cancelled:
        return -1;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFD97706);
      case OrderStatus.confirmed:
        return const Color(0xFF0284C7);
      case OrderStatus.packed:
        return const Color(0xFF7C3AED);
      case OrderStatus.shipped:
        return const Color(0xFFEA580C);
      case OrderStatus.delivered:
        return const Color(0xFF16A34A);
      case OrderStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }

  Color _getStatusBg(OrderStatus status) {
    return _getStatusColor(status).withOpacity(0.12);
  }

  @override
  Widget build(BuildContext context) {
    final statusIndex = _getStatusStepIndex(order.status);
    final itemsList = order.items ?? [];
    final orderIdDisplay = order.readableId ?? order.id.substring(0, 8).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
              isPickupOrder ? 'Store Pickup Tracking' : 'Live Order Tracking',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 16),
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
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 10, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.headset_mic_rounded, color: primaryRed, size: 18),
            ),
            onPressed: () => _makeCall('+918112849854'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Premium Live Express ETA & Status Header Card
            _buildStatusHeaderCard(),
            const SizedBox(height: 14),

            // Pay Online Banner (if COD)
            if (order.paymentStatus != 'PAID' && order.status != OrderStatus.cancelled) ...[
              _buildPayOnlineCard(context),
              const SizedBox(height: 14),
            ],

            // 2. Premium 5-Stage Live Order Tracker Card (NO Timing clutter)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                          const SizedBox(width: 6),
                          Text(
                            isPickupOrder ? 'Store Pickup Status' : 'Live Order Tracker',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14.5),
                              fontWeight: FontWeight.w900,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBg(order.status),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getStatusColor(order.status).withOpacity(0.3)),
                        ),
                        child: Text(
                          order.status.displayName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w900,
                            color: _getStatusColor(order.status),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (isPickupOrder) ...[
                    // Self-Pickup 4-Step Flow
                    _buildTimelineStep(
                      0,
                      '1. Order Placed',
                      'Order registered at Ghatampur store',
                      statusIndex >= 0,
                    ),
                    _buildTimelineStep(
                      1,
                      '2. Order Confirmed',
                      'Store accepted and verified items',
                      statusIndex >= 1,
                    ),
                    _buildTimelineStep(
                      2,
                      '3. Ready for Self Pickup',
                      'Collect at Ghatampur Hub Counter (Show Order ID)',
                      statusIndex >= 2,
                    ),
                    _buildTimelineStep(
                      3,
                      order.status == OrderStatus.cancelled ? 'Order Cancelled' : '4. Order Picked Up',
                      order.status == OrderStatus.cancelled ? 'Order was cancelled' : 'Handed over to customer',
                      statusIndex >= 3,
                      isLast: true,
                      isCancelled: order.status == OrderStatus.cancelled,
                    ),
                  ] else ...[
                    // Doorstep Delivery 5-Step Flow (NO Timings)
                    _buildTimelineStep(
                      0,
                      '1. Order Placed',
                      'Your order has been registered in store system',
                      statusIndex >= 0,
                    ),
                    _buildTimelineStep(
                      1,
                      '2. Order Confirmed',
                      'Store accepted and verified items',
                      statusIndex >= 1,
                    ),
                    _buildTimelineStep(
                      2,
                      '3. Packed & Sealed',
                      'Items packed fresh in safe tamper-proof bag',
                      statusIndex >= 2,
                    ),
                    _buildTimelineStep(
                      3,
                      '4. On the Way',
                      'Delivery partner is on the way to your address',
                      statusIndex >= 3,
                    ),
                    _buildTimelineStep(
                      4,
                      order.status == OrderStatus.cancelled ? 'Order Cancelled' : '5. Delivered Successfully',
                      order.status == OrderStatus.cancelled ? 'Order was cancelled' : 'Package handed over at doorstep',
                      statusIndex >= 4,
                      isLast: true,
                      isCancelled: order.status == OrderStatus.cancelled,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Delivery Address & Store Help Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 18, color: primaryRed),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isPickupOrder ? 'Pickup Hub Point' : 'Delivery Address',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPickupOrder
                        ? 'FastKirana Express Darkstore Hub'
                        : (order.customerAddress ?? 'Express Delivery Address'),
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Help with Order?',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '+91 81128 49854',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _openWhatsApp('918112849854', orderIdDisplay),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF16A34A), size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFDCFCE7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.all(10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _makeCall('+918112849854'),
                            icon: const Icon(Icons.phone, size: 13, color: Colors.white),
                            label: const Text('Call Store'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Itemized Bill Summary
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bill Details',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14),
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${itemsList.length} ${itemsList.length == 1 ? 'ITEM' : 'ITEMS'}',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (itemsList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'Items processed by darkstore',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: textMuted),
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
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.quantity}x',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: FontWeight.w600,
                                    color: textDark,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${(item.price * item.quantity).toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12.5),
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                        )),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  _buildBillRow('Item Total', '₹${order.subtotal.toInt()}'),
                  if (order.discount > 0)
                    _buildBillRow('Discount Savings', '-₹${order.discount.toInt()}', isGreen: true),
                  _buildBillRow(
                    'Delivery Fee',
                    isPickupOrder ? 'FREE (Store Pickup)' : (order.deliveryFee == 0 ? 'FREE' : '₹${order.deliveryFee.toInt()}'),
                    isGreen: order.deliveryFee == 0 || isPickupOrder,
                  ),
                  _buildBillRow(
                    'Packaging Charge',
                    order.miscFee > 0 ? '₹${order.miscFee.toInt()}' : '₹5',
                  ),
                  _buildBillRow('Handling & Taxes', '₹0', isGreen: true),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFFE2E8F0)),
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
                              fontSize: Responsive.scaledFontSize(context, 14.5),
                              fontWeight: FontWeight.w900,
                              color: textDark,
                            ),
                          ),
                          Text(
                            order.paymentMethod.displayName,
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w600, color: textMuted),
                          ),
                        ],
                      ),
                      Text(
                        '₹${order.total.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 18),
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

  // Premium Status Header Card
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
                    isPickupOrder ? 'Order Picked Up Successfully!' : 'Order Delivered Successfully!',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: const Color(0xFF065F46)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPickupOrder ? 'Collected from Ghatampur Store counter' : 'Delivered fresh to your doorstep',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, color: const Color(0xFF047857)),
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
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: const Color(0xFF991B1B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Contact store support for refund or reorder assistance',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, color: const Color(0xFFB91C1C)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Live In-Transit / Preparation Header
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE20A22), Color(0xFFFF2D4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                isPickupOrder ? '🏬' : '🛵',
                style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 22)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isPickupOrder ? 'Ready for Store Pickup' : 'Express Delivery In Progress',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isPickupOrder
                      ? 'Collect at Ghatampur Darkstore Counter'
                      : 'Live tracking from Ghatampur Hub Store',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pay Online Banner
  Widget _buildPayOnlineCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 10))),
                    const SizedBox(width: 4),
                    Text(
                      'PAY ONLINE NOW',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
              Text(
                '100% Safe & Instant',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Avoid Cash Hassle at Doorstep 💳',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          Text(
            'Order is currently set to Cash on Delivery. Switch to Online Payment via UPI, GPay, PhonePe or Cards.',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: const Color(0xFF475569), height: 1.35),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening secure UPI gateway...'),
                  backgroundColor: Color(0xFF16A34A),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF059669).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Pay ₹${order.total.toInt()} Online Now',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: Colors.white),
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

  // 5-Stage Timeline Step (NO Timestamps)
  Widget _buildTimelineStep(
    int stepIndex,
    String title,
    String desc,
    bool isDone, {
    bool isLast = false,
    bool isCancelled = false,
  }) {
    Color activeColor = isCancelled ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? activeColor : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? Icon(isCancelled ? Icons.close : Icons.check, size: 13, color: Colors.white)
                    : Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF94A3B8), shape: BoxShape.circle)),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isDone ? activeColor : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
                    color: isDone ? textDark : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w500,
                    color: isDone ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
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
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w500,
              color: textMuted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12.5),
              fontWeight: isGreen ? FontWeight.w800 : FontWeight.w600,
              color: isGreen ? const Color(0xFF16A34A) : textDark,
            ),
          ),
        ],
      ),
    );
  }
}