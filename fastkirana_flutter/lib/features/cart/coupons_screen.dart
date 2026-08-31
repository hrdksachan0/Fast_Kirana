import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/coupon.dart';
import '../../providers/coupon_provider.dart';

class CouponsScreen extends ConsumerStatefulWidget {
  final double currentSubtotal;
  const CouponsScreen({super.key, this.currentSubtotal = 0.0});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  String? _inlineError;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applyCode(String code) {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      setState(() => _inlineError = 'Please enter a coupon code');
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context, clean);
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(couponsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: slateDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apply Coupons & Vouchers',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Save extra on your FastKirana order',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: slateMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: slateMuted, size: 20),
            onPressed: () => ref.invalidate(couponsProvider),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: slateBorder),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: Responsive.defaultMaxContentWidth,
        fillHeight: true,
        child: RefreshIndicator(
          color: primaryRed,
          onRefresh: () async => ref.refresh(couponsProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Manual Coupon Input Bar
                _buildManualInputCard(),

                const SizedBox(height: 20),

                // 2. Section Header
                Row(
                  children: [
                    const Text('🎟️', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(
                      'Available Coupons for You',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 3. Coupons List / Empty State
                couponsAsync.when(
                  data: (coupons) {
                    final validCoupons = coupons.where((c) => c.isValid).toList();
                    if (validCoupons.isEmpty) {
                      return _buildZeroCouponState();
                    }
                    return Column(
                      children: validCoupons.map((coupon) => _buildCouponCard(coupon)).toList(),
                    );
                  },
                  loading: () => _buildLoadingShimmer(),
                  error: (_, __) => _buildZeroCouponState(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Top Manual Coupon Code Input Box
  Widget _buildManualInputCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _inlineError != null ? primaryRed : slateBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: slateDark,
                    letterSpacing: 1.0,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    hintText: 'ENTER COUPON CODE',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                    icon: const Icon(Icons.local_offer_outlined, color: primaryRed, size: 20),
                  ),
                  onSubmitted: (val) => _applyCode(val),
                  onChanged: (_) {
                    if (_inlineError != null) {
                      setState(() => _inlineError = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Bounceable(
                onTap: () => _applyCode(_inputController.text),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryRed,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'APPLY',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_inlineError != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                _inlineError!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primaryRed,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 2. World-Class Ticket Notch Coupon Card
  Widget _buildCouponCard(Coupon coupon) {
    final discountTitle = coupon.discountType == DiscountType.percent
        ? 'FLAT ${coupon.value.toInt()}% OFF'
        : 'FLAT ₹${coupon.value.toInt()} OFF';

    String conditionText = '';
    if (coupon.minOrder > 0) {
      conditionText = 'Valid on orders above ₹${coupon.minOrder.toInt()}';
    } else {
      conditionText = 'Valid on all orders. No minimum cart value.';
    }

    if (coupon.maxDiscount > 0 && coupon.discountType == DiscountType.percent) {
      conditionText += ' (Max ₹${coupon.maxDiscount.toInt()})';
    }

    final isEligible = widget.currentSubtotal == 0.0 || widget.currentSubtotal >= coupon.minOrder;
    final diff = coupon.minOrder - widget.currentSubtotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEligible ? const Color(0xFFFECDD3) : slateBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Ticket Area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Coupon Code Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              coupon.code,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: primaryRed,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: primaryRed),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        discountTitle,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: slateDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conditionText,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: slateMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Apply Action Button
                Bounceable(
                  onTap: () => _applyCode(coupon.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isEligible ? const Color(0xFFDC2626) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'APPLY',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isEligible ? Colors.white : const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dashed Divider Tear Line
          Row(
            children: List.generate(
              30,
              (index) => Expanded(
                child: Container(
                  color: index % 2 == 0 ? Colors.transparent : const Color(0xFFE2E8F0),
                  height: 1.2,
                ),
              ),
            ),
          ),

          // Bottom Terms / Eligibility Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isEligible ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  isEligible ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 13,
                  color: isEligible ? const Color(0xFFEA580C) : slateMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isEligible
                        ? 'Tap APPLY to save with this coupon'
                        : 'Add ₹${diff.toInt()} more items to unlock this coupon',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isEligible ? const Color(0xFF9A3412) : slateMuted,
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

  /// 3. Zero Coupons / Empty State Card
  Widget _buildZeroCouponState() {
    return Container(
      padding: const EdgeInsets.all(28),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: slateBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF1F2),
            ),
            child: const Center(
              child: Text('🎟️', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Public Coupons Right Now',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: slateDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'If you have a private coupon or promo code, enter it in the box above to apply your discount.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: slateMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Bounceable(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                'Back to Cart',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: slateDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Shimmer Loading Placeholders
  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: slateBorder),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryRed.withOpacity(0.6)),
            ),
          ),
        ),
      ),
    );
  }
}
