import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../coupons_screen.dart';

/// Interactive Voucher & Coupon Code Section
class CartCouponCard extends StatefulWidget {
  final double subtotal;
  final String? restaurantId;
  final String? appliedCoupon;
  final double couponDiscount;
  final bool isApplyingCoupon;
  final bool isBogoApplied;
  final String? bogoBadgeText;
  final String? nudgeMessage;
  final Map<String, dynamic>? freeGiftDetails;
  final TextEditingController controller;
  final Future<void> Function(String code) onApplyCoupon;
  final VoidCallback onRemoveCoupon;

  const CartCouponCard({
    super.key,
    required this.subtotal,
    this.restaurantId,
    required this.appliedCoupon,
    required this.couponDiscount,
    required this.isApplyingCoupon,
    required this.isBogoApplied,
    this.bogoBadgeText,
    this.nudgeMessage,
    this.freeGiftDetails,
    required this.controller,
    required this.onApplyCoupon,
    required this.onRemoveCoupon,
  });

  @override
  State<CartCouponCard> createState() => _CartCouponCardState();
}

class _CartCouponCardState extends State<CartCouponCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + "View offers"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.orange50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignSystem.orange200),
                    ),
                    child: const Icon(Icons.local_offer_rounded, size: 16, color: AppDesignSystem.orange600),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Apply Coupon',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: AppDesignSystem.slate900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Bounceable(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final selected = await Navigator.push<String>(
                    context,
                    FadeSlideRoute(page: CouponsScreen(currentSubtotal: widget.subtotal, restaurantId: widget.restaurantId)),
                  );
                  if (selected != null && selected.isNotEmpty) {
                    widget.controller.text = selected;
                    widget.onApplyCoupon(selected);
                  }
                },
                child: Row(
                  children: [
                    Text(
                      'View offers',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.orange600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppDesignSystem.orange600),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Applied State vs Input State
          if (widget.appliedCoupon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isBogoApplied ? const Color(0xFFFFF7ED) : AppDesignSystem.statusDelivered,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isBogoApplied ? const Color(0xFFFDBA74) : AppDesignSystem.emerald300,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.isBogoApplied ? const Color(0xFFEA580C) : AppDesignSystem.success,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isBogoApplied ? Icons.local_fire_department_rounded : Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              widget.appliedCoupon!,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w900,
                                color: widget.isBogoApplied ? const Color(0xFFC2410C) : AppDesignSystem.statusDeliveredText,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: widget.isBogoApplied ? const Color(0xFFEA580C) : AppDesignSystem.emerald700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.bogoBadgeText ?? (widget.isBogoApplied ? 'BOGO DEAL' : 'APPLIED'),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 8.5),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.freeGiftDetails != null
                              ? '🎁 Free "${widget.freeGiftDetails!['name']}" added to your cart!'
                              : (widget.nudgeMessage ?? (widget.couponDiscount > 0 ? 'You saved ₹${widget.couponDiscount.toInt()} with this coupon!' : 'Offer active on qualifying items')),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: widget.isBogoApplied ? const Color(0xFFC2410C) : AppDesignSystem.emerald700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Bounceable(
                    onTap: widget.onRemoveCoupon,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppDesignSystem.rose300),
                      ),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.rose500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // Pill Input Box with Integrated Gradient APPLY Button
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.slate300, width: 1.2),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.confirmation_number_outlined, size: 19, color: AppDesignSystem.slate400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate900,
                        letterSpacing: 0.6,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w500,
                          color: AppDesignSystem.slate400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (widget.controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        setState(() {});
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.cancel_rounded, size: 16, color: AppDesignSystem.slate400),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Bounceable(
                      onTap: () {
                        if (widget.controller.text.trim().isNotEmpty) {
                          widget.onApplyCoupon(widget.controller.text.trim());
                        }
                      },
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppDesignSystem.orange600, AppDesignSystem.cafeAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.orange600.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: widget.isApplyingCoupon
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'APPLY',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 12.5),
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
