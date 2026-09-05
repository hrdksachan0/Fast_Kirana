import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/network/api_client.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/cart_provider.dart';
import '../orders/order_tracking_screen.dart';

class OrderSuccessScreen extends ConsumerStatefulWidget {
  final String? orderId;
  final double totalAmount;
  final String deliveryAddress;
  final String paymentMethod;
  final Order? order;

  const OrderSuccessScreen({
    super.key,
    this.orderId,
    this.totalAmount = 0.0,
    this.deliveryAddress = 'Ghatampur Home',
    this.paymentMethod = 'COD',
    this.order,
  });

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  static const Color primaryRed = AppDesignSystem.primary;
  static const Color successGreen = AppDesignSystem.success;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  late ConfettiController _confettiController;
  late AnimationController _animController;
  late Animation<double> _checkScaleAnim;
  late Animation<double> _titleFadeAnim;
  late Animation<Offset> _titleSlideAnim;
  late Animation<double> _trackerFadeAnim;
  late Animation<Offset> _trackerSlideAnim;
  late Animation<double> _detailsFadeAnim;
  late Animation<Offset> _detailsSlideAnim;
  late Animation<double> _buttonsFadeAnim;
  late Animation<Offset> _buttonsSlideAnim;

  Order? _liveOrder;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _checkScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
      ),
    );

    _titleFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleSlideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _trackerFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );
    _trackerSlideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _detailsFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );
    _detailsSlideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _buttonsFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );
    _buttonsSlideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
    HapticFeedback.heavyImpact();

    // Start live syncing with admin/backend order updates
    _fetchLiveOrderStatus();
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchLiveOrderStatus());

    // ─── Post-Order Cart Clear Guarantee ───
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(cartProvider.notifier).clearCart();
      } catch (e, _) { LoggerService.error('OrderSuccessScreen: silent catch', e); }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _confettiController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveOrderStatus() async {
    final displayId = widget.orderId;
    if (displayId == null || displayId.isEmpty) return;

    try {
      final repo = OrderRepository(ref.read(dioProvider));
      final order = await repo.getOrder(displayId);
      if (mounted) {
        setState(() {
          _liveOrder = order;
        });
      }
    } catch (e, _) { LoggerService.error('OrderSuccessScreen: silent catch', e); }
  }

  // Map backend OrderStatus to 5-stage integer step (0 to 4)
  int _getStageIndex(OrderStatus? status) {
    if (status == null) return 1; // Default to Confirmed if freshly placed
    switch (status) {
      case OrderStatus.pending:
        return 0; // Placed
      case OrderStatus.confirmed:
        return 1; // Confirmed
      case OrderStatus.packed:
        return 2; // Packed
      case OrderStatus.shipped:
        return 3; // On the Way
      case OrderStatus.delivered:
        return 4; // Delivered
      case OrderStatus.cancelled:
        return -1;
    }
  }

  String _getStatusTitle(int stage) {
    switch (stage) {
      case 0:
        return 'Live Status: Order Placed';
      case 1:
        return 'Live Status: Order Confirmed';
      case 2:
        return 'Live Status: Order Packed';
      case 3:
        return 'Live Status: On the Way 🛵';
      case 4:
        return 'Live Status: Delivered ✨';
      default:
        return 'Live Status: In Progress';
    }
  }

  String _getBadgeText(int stage) {
    switch (stage) {
      case 0:
        return 'PLACED';
      case 1:
        return 'CONFIRMED';
      case 2:
        return 'PACKED';
      case 3:
        return 'ON THE WAY';
      case 4:
        return 'DELIVERED';
      default:
        return 'PROCESSING';
    }
  }

  Color _getBadgeColor(int stage) {
    switch (stage) {
      case 0:
        return AppDesignSystem.amber600; // Amber
      case 1:
        return AppDesignSystem.cyan600; // Sky Blue
      case 2:
        return AppDesignSystem.violet600; // Purple
      case 3:
        return AppDesignSystem.orange600; // Orange
      case 4:
        return AppDesignSystem.green600; // Green
      default:
        return AppDesignSystem.green600;
    }
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isHighlight = false, Widget? customValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w500,
                color: slateMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: customValue ??
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: isBold || isHighlight ? FontWeight.w800 : FontWeight.w600,
                      color: isHighlight ? successGreen : slateDark,
                      height: 1.3,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayId = widget.orderId ?? 'FK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final currentStatus = _liveOrder?.status ?? (widget.order?.status ?? OrderStatus.confirmed);
    final isCancelled = currentStatus == OrderStatus.cancelled;
    final stageIndex = _getStageIndex(currentStatus);
    final badgeColor = isCancelled ? AppDesignSystem.red600 : _getBadgeColor(stageIndex);

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (!isCancelled)
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppDesignSystem.primary,
                AppDesignSystem.success,
                AppDesignSystem.warning,
                AppDesignSystem.info,
                AppDesignSystem.violet500,
              ],
              numberOfParticles: 40,
              gravity: 0.14,
            ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // 1. ANIMATED TOP STATUS BADGE (Green Check / Red Cross)
                  ScaleTransition(
                    scale: _checkScaleAnim,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? AppDesignSystem.statusCancelled
                            : successGreen.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: isCancelled
                                ? AppDesignSystem.danger.withValues(alpha: 0.2)
                                : successGreen.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCancelled
                                  ? [AppDesignSystem.danger, AppDesignSystem.red600]
                                  : [AppDesignSystem.success, AppDesignSystem.emerald600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCancelled ? Icons.close_rounded : Icons.check_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. STATUS TITLE & SUBTITLE
                  FadeTransition(
                    opacity: _titleFadeAnim,
                    child: SlideTransition(
                      position: _titleSlideAnim,
                      child: Column(
                        children: [
                          Text(
                            isCancelled ? 'Order Cancelled' : 'Order Placed Successfully! 🎉',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 21),
                              fontWeight: FontWeight.w900,
                              color: isCancelled ? AppDesignSystem.red600 : slateDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isCancelled
                                ? 'This order has been cancelled by store or customer.'
                                : 'Your order has been received & is being synced with store.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12.5),
                              fontWeight: FontWeight.w500,
                              color: slateMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 3. LIVE 5-STAGE PROGRESS TRACKER OR CANCELLED NOTICE CARD
                  FadeTransition(
                    opacity: _trackerFadeAnim,
                    child: SlideTransition(
                      position: _trackerSlideAnim,
                      child: isCancelled
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.statusCancelled,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppDesignSystem.red200, width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.cancel_outlined, size: 18, color: AppDesignSystem.red600),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Order Status: Cancelled',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 13),
                                            fontWeight: FontWeight.w900,
                                            color: AppDesignSystem.statusCancelledText,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppDesignSystem.statusCancelled,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppDesignSystem.red300),
                                        ),
                                        child: Text(
                                          'CANCELLED',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9.5),
                                            fontWeight: FontWeight.w900,
                                            color: AppDesignSystem.red600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No amount was charged for this order. If you paid online, your refund will be credited back in 2-4 business days.',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w500,
                                      color: AppDesignSystem.red900,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 15))),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _getStatusTitle(stageIndex),
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 13),
                                            fontWeight: FontWeight.w800,
                                            color: slateDark,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: badgeColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _getBadgeText(stageIndex),
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 9.5),
                                                fontWeight: FontWeight.w900,
                                                color: badgeColor,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),

                                  // 5-Stage Stepper Flow
                                  Row(
                                    children: [
                                      _buildProgressStep('Placed', stageIndex >= 0),
                                      _buildProgressLine(stageIndex >= 1),
                                      _buildProgressStep('Confirmed', stageIndex >= 1),
                                      _buildProgressLine(stageIndex >= 2),
                                      _buildProgressStep('Packed', stageIndex >= 2),
                                      _buildProgressLine(stageIndex >= 3),
                                      _buildProgressStep('On Way', stageIndex >= 3),
                                      _buildProgressLine(stageIndex >= 4),
                                      _buildProgressStep('Delivered', stageIndex >= 4),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. ORDER SUMMARY DETAILS CARD
                  FadeTransition(
                    opacity: _detailsFadeAnim,
                    child: SlideTransition(
                      position: _detailsSlideAnim,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.slate900.withValues(alpha: 0.03),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow(
                              'Order ID',
                              displayId,
                              customValue: Row(
                                children: [
                                  Text(
                                    displayId.length > 20 ? '${displayId.substring(0, 20)}...' : displayId,
                                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w800, color: slateDark),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: displayId));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Order ID copied to clipboard!'),
                                          duration: Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppDesignSystem.slate100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.copy_rounded, size: 13, color: AppDesignSystem.slate500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 18, color: AppDesignSystem.slate100),
                            _buildDetailRow('Total Amount', '₹${widget.totalAmount.toInt()}', isBold: true),
                            const Divider(height: 18, color: AppDesignSystem.slate100),
                            _buildDetailRow(
                              'Payment Mode',
                              widget.paymentMethod,
                              customValue: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.statusCancelled,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppDesignSystem.statusCancelled),
                                ),
                                child: Text(
                                  widget.paymentMethod,
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w800, color: primaryRed),
                                ),
                              ),
                            ),
                            const Divider(height: 18, color: AppDesignSystem.slate100),
                            _buildDetailRow(
                              'Deliver To',
                              widget.deliveryAddress.isNotEmpty ? widget.deliveryAddress : 'Ghatampur Delivery Address',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 5. BOTTOM ACTION BUTTONS
                  FadeTransition(
                    opacity: _buttonsFadeAnim,
                    child: SlideTransition(
                      position: _buttonsSlideAnim,
                      child: Column(
                        children: [
                          if (!isCancelled) ...[
                            // Track Live Order Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                final effectiveOrder = _liveOrder ?? widget.order;
                                final trackingId = effectiveOrder?.id ?? effectiveOrder?.readableId ?? widget.orderId ?? displayId;
                                Navigator.push(
                                  context,
                                  FadeSlideRoute(
                                    page: OrderTrackingScreen(
                                      orderId: trackingId,
                                      initialOrder: effectiveOrder,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppDesignSystem.primary, AppDesignSystem.primaryLight],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryRed.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.location_searching_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Track Live Order Status',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 14.5),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Continue Shopping Button
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isCancelled ? AppDesignSystem.primary : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isCancelled ? AppDesignSystem.primary : AppDesignSystem.slate200),
                              ),
                              child: Center(
                                child: Text(
                                  isCancelled ? 'Continue Shopping 🛍️' : 'Continue Shopping 🛍️',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13.5),
                                    fontWeight: FontWeight.w800,
                                    color: isCancelled ? Colors.white : AppDesignSystem.slate700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(String label, bool isDone) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? successGreen : AppDesignSystem.slate200,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppDesignSystem.slate400,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 8.5),
            fontWeight: isDone ? FontWeight.w900 : FontWeight.w500,
            color: isDone ? slateDark : AppDesignSystem.slate400,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine(bool isDone) {
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 14),
        color: isDone ? successGreen : AppDesignSystem.slate200,
      ),
    );
  }
}
