import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/responsive.dart';
import '../../../data/models/order.dart';

class TrackingStatusStepper extends StatelessWidget {
  final Order? order;
  final int statusStep;
  final bool isDelivered;
  final bool isCancelled;
  final String cleanDisplayId;
  final String etaText;
  final String distanceText;

  const TrackingStatusStepper({
    super.key,
    required this.order,
    required this.statusStep,
    required this.isDelivered,
    required this.isCancelled,
    required this.cleanDisplayId,
    required this.etaText,
    required this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    const slateDark = Color(0xFF0F172A);
    const slateMuted = Color(0xFF64748B);
    const slateBorder = Color(0xFFE2E8F0);

    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
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
                  'Live Order Status',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: slateDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'CANCELLED',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFDC2626),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFDC2626),
                  ),
                  child: const Center(
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Closed & Cancelled',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: const Color(0xFF991B1B)),
                      ),
                      Text(
                        'Items were returned to stock. You can place a new order anytime.',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final steps = [
      {'title': 'Order Confirmed', 'subtitle': 'Store has accepted your order', 'icon': Icons.check_circle_outline_rounded},
      {'title': 'Preparing Fresh', 'subtitle': 'Packing fresh items from warehouse', 'icon': Icons.inventory_2_outlined},
      {'title': 'Ready for Pickup', 'subtitle': 'Rider assigned and picking up', 'icon': Icons.storefront_outlined},
      {'title': 'Out for Delivery', 'subtitle': 'Rider on the way to your door', 'icon': Icons.two_wheeler_rounded},
      {'title': 'Delivered', 'subtitle': 'Delivered safely at your location', 'icon': Icons.done_all_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slateBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Order Status',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: slateDark),
                  ),
                  if (!isDelivered && (etaText.isNotEmpty || distanceText.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (etaText.isNotEmpty) 'Estimated: $etaText',
                          if (distanceText.isNotEmpty) distanceText,
                        ].join(' • '),
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A344),
                        ),
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelivered
                      ? const Color(0xFFDCFCE7)
                      : (statusStep == -2 ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDelivered
                      ? 'COMPLETED'
                      : (statusStep == -2 ? 'VERIFYING' : 'IN TRANSIT'),
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w900,
                    color: isDelivered
                        ? const Color(0xFF15803D)
                        : (statusStep == -2 ? const Color(0xFFC2410C) : const Color(0xFF1D4ED8)),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (statusStep == -2) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFFEA580C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Admin call confirmation in progress. Once confirmed, your order will proceed to preparation.',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (order?.isCombined == true && order?.subOrders != null && order!.subOrders!.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        'COMBINED MULTI-OUTLET ORDER',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...order!.subOrders!.map((sub) {
                    final subIsDelivered = sub.status == OrderStatus.delivered;
                    final isRest = sub.restaurantId != null || (sub.readableId != null && sub.readableId!.toUpperCase().endsWith('-R'));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          Text(
                            isRest ? '🍽️' : '🏪',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sub.shopName ?? (isRest ? 'Restaurant' : 'FastKirana Darkstore'),
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w600,
                                color: slateDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (subIsDelivered ? const Color(0xFF00A344) : const Color(0xFF2563EB)).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              sub.status.displayName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10),
                                fontWeight: FontWeight.w800,
                                color: subIsDelivered ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          ...List.generate(steps.length, (index) {
            final item = steps[index];
            final isCompleted = statusStep > index;
            final isCurrent = statusStep == index;
            final isLast = index == steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedStepNode(
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      icon: item['icon'] as IconData,
                      activeColor: const Color(0xFF00A344),
                      completedColor: const Color(0xFF00A344),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: isCompleted ? const Color(0xFF00A344) : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: (isCurrent || isCompleted) ? FontWeight.w800 : FontWeight.w500,
                                color: isCurrent
                                    ? const Color(0xFF00A344)
                                    : (isCompleted ? slateDark : slateMuted),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'NOW',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                            color: isCurrent ? const Color(0xFF475569) : slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class AnimatedStepNode extends StatefulWidget {
  final bool isCompleted;
  final bool isCurrent;
  final IconData icon;
  final Color activeColor;
  final Color completedColor;

  const AnimatedStepNode({
    super.key,
    required this.isCompleted,
    required this.isCurrent,
    required this.icon,
    this.activeColor = const Color(0xFF00A344),
    this.completedColor = const Color(0xFF00A344),
  });

  @override
  State<AnimatedStepNode> createState() => _AnimatedStepNodeState();
}

class _AnimatedStepNodeState extends State<AnimatedStepNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isCurrent) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedStepNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isCompleted ? widget.completedColor : const Color(0xFFF1F5F9),
          border: Border.all(
            color: widget.isCompleted ? Colors.transparent : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: 14,
            color: widget.isCompleted ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      );
    }

    return SizedBox(
      width: 38,
      height: 38,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 28 * _pulseAnimation.value,
                height: 28 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.activeColor.withValues(alpha: (1.35 - _pulseAnimation.value).clamp(0.08, 0.35)),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.activeColor,
                  boxShadow: [
                    BoxShadow(
                      color: widget.activeColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
