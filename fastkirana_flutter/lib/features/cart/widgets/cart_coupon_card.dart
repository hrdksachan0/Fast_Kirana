import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/coupon.dart';
import '../../../providers/coupon_provider.dart';
import '../coupons_screen.dart';

/// Ultra-Modern Voucher & Coupon Code Section
class CartCouponCard extends ConsumerStatefulWidget {
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
  ConsumerState<CartCouponCard> createState() => _CartCouponCardState();
}

class _CartCouponCardState extends ConsumerState<CartCouponCard> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onStateChange);
    widget.controller.addListener(_onStateChange);
  }

  @override
  void didUpdateWidget(covariant CartCouponCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChange);
      widget.controller.addListener(_onStateChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onStateChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final isFocused = _focusNode.hasFocus;

    // Retrieve active coupons if no coupon is currently applied
    final couponsAsync = widget.appliedCoupon == null
        ? (widget.restaurantId != null && widget.restaurantId!.isNotEmpty
            ? ref.watch(restaurantCouponsProvider(widget.restaurantId!))
            : ref.watch(couponsProvider))
        : null;

    final availableCoupons = (couponsAsync?.valueOrNull ?? [])
        .where((c) => c.isActive && c.expiresAt.isAfter(DateTime.now()))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Gradient Squircle Icon + Title (Expanded) + Modern Pill "View offers"
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA), width: 1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.confirmation_number_rounded,
                    size: 18,
                    color: AppDesignSystem.orange600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apply Coupon',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Save extra with promo codes',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.slate500,
                      ),
                      maxLines: 2,
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Bounceable(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final selected = await Navigator.push<String>(
                    context,
                    FadeSlideRoute(
                      page: CouponsScreen(
                        currentSubtotal: widget.subtotal,
                        restaurantId: widget.restaurantId,
                      ),
                    ),
                  );
                  if (selected != null && selected.isNotEmpty) {
                    widget.controller.text = selected;
                    widget.onApplyCoupon(selected);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFED7AA), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View offers',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.orange600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 3.5),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9,
                        color: AppDesignSystem.orange600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Applied State vs Interactive Input State
          if (widget.appliedCoupon != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isBogoApplied ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isBogoApplied ? const Color(0xFFFDBA74) : const Color(0xFF86EFAC),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.isBogoApplied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isBogoApplied ? Icons.local_fire_department_rounded : Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w900,
                                color: widget.isBogoApplied ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                                letterSpacing: 0.6,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget.isBogoApplied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.bogoBadgeText ?? (widget.isBogoApplied ? 'BOGO DEAL' : 'APPLIED'),
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 9),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.freeGiftDetails != null
                              ? '🎁 Free "${widget.freeGiftDetails!['name']}" added to your cart!'
                              : (widget.nudgeMessage ??
                                  (widget.couponDiscount > 0
                                      ? '🎉 You saved ₹${widget.couponDiscount.toInt()} with this coupon!'
                                      : 'Offer active on qualifying items')),
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w700,
                            color: widget.isBogoApplied ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Bounceable(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onRemoveCoupon();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        'Remove',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Tactile Modern Voucher Slot (Elevated & Unified)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFocused
                      ? const Color(0xFFE11D48)
                      : (hasText ? const Color(0xFFE11D48).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
                  width: isFocused ? 1.5 : 1.1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
              child: Row(
                children: [
                  // Squircle Voucher Badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: (isFocused || hasText)
                          ? const LinearGradient(
                              colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFF1F5F9), Color(0xFFF8FAFC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (isFocused || hasText) ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.confirmation_number_rounded,
                        size: 16,
                        color: (isFocused || hasText) ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter coupon code',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (code) {
                        if (code.trim().isNotEmpty && !widget.isApplyingCoupon) {
                          HapticFeedback.mediumImpact();
                          widget.onApplyCoupon(code.trim());
                        }
                      },
                    ),
                  ),
                  if (hasText)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.controller.clear();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 13, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  hasText
                      ? Bounceable(
                          onTap: () {
                            if (!widget.isApplyingCoupon) {
                              HapticFeedback.mediumImpact();
                              widget.onApplyCoupon(widget.controller.text.trim());
                            }
                          },
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE11D48).withValues(alpha: 0.32),
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
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'APPLY',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: Responsive.scaledFontSize(context, 11.5),
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                                      ],
                                    ),
                            ),
                          ),
                        )
                      : Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'APPLY',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // Optional Quick-Apply Recommendation Strip
            if (availableCoupons.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: availableCoupons.take(3).map((coupon) {
                    final isEligible = widget.subtotal >= coupon.minOrder;
                    final discountLabel = coupon.discountType == DiscountType.percent
                        ? '${coupon.value.toInt()}% OFF'
                        : coupon.discountType == DiscountType.bogo
                            ? 'BOGO FREE'
                            : coupon.discountType == DiscountType.freeDelivery
                                ? 'FREE DEL'
                                : '₹${coupon.value.toInt()} OFF';

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Bounceable(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.controller.text = coupon.code;
                          widget.onApplyCoupon(coupon.code);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isEligible ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isEligible ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_offer_rounded,
                                size: 12,
                                color: isEligible ? AppDesignSystem.orange600 : AppDesignSystem.slate400,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                coupon.code,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w900,
                                  color: isEligible ? AppDesignSystem.orange600 : AppDesignSystem.slate700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: isEligible ? const Color(0xFFF97316) : AppDesignSystem.slate300,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                discountLabel,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 10),
                                  fontWeight: FontWeight.w700,
                                  color: isEligible ? const Color(0xFFC2410C) : AppDesignSystem.slate500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isEligible ? AppDesignSystem.orange600 : AppDesignSystem.slate200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'APPLY',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 8.5),
                                    fontWeight: FontWeight.w900,
                                    color: isEligible ? Colors.white : AppDesignSystem.slate500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
