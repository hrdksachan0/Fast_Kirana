import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// Exact 1:1 Delivery Payment & Handover Modal (Matching Screenshots 1, 2, 3, 4)
class DeliveryPaymentSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final String orderNum;
  final double total;
  final bool isCod;
  final double cashInHand;
  final double cashLimit;
  final double lat;
  final double lng;
  final Function(Map<String, dynamic> extra) onConfirmDelivery;
  final VoidCallback onOpenDoorstepQr;

  const DeliveryPaymentSheet({
    super.key,
    required this.order,
    required this.orderNum,
    required this.total,
    required this.isCod,
    required this.cashInHand,
    required this.cashLimit,
    required this.lat,
    required this.lng,
    required this.onConfirmDelivery,
    required this.onOpenDoorstepQr,
  });

  @override
  State<DeliveryPaymentSheet> createState() => _DeliveryPaymentSheetState();
}

class _DeliveryPaymentSheetState extends State<DeliveryPaymentSheet> {
  String _step = 'choose';
  late TextEditingController _cashReceivedController;
  late TextEditingController _cashPortionController;
  bool _hasSplitOnline = false;

  @override
  void initState() {
    super.initState();
    _cashReceivedController = TextEditingController(text: widget.total.toInt().toString());
    _cashPortionController = TextEditingController();
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    _cashPortionController.dispose();
    super.dispose();
  }

  List<int> _getQuickPresets(int total) {
    final List<int> presets = [total];
    for (final r in [10, 50, 100, 500]) {
      final rounded = (total / r).ceil() * r;
      if (!presets.contains(rounded) && rounded <= total + 700) {
        presets.add(rounded);
      }
    }
    for (final note in [500, 1000, 2000]) {
      if (!presets.contains(note) && note > total && note <= total + 1500) {
        presets.add(note);
      }
    }
    return presets.take(6).toList();
  }

  List<int> _getSplitPresets(int total) {
    final List<int> presets = [];
    for (final s in [100, 200, 300, 500]) {
      if (s < total) {
        presets.add(s);
      }
    }
    return presets.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: widget.isCod ? _buildCodContent() : _buildPrepaidContent(),
    );
  }

  // 1. PREPAID HANDOVER MODAL (Screenshot 1)
  Widget _buildPrepaidContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppDesignSystem.slate200, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppDesignSystem.success, AppDesignSystem.emerald600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.success.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text('📦', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 26))),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Confirm Parcel Handover',
          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Order #${widget.orderNum} • ',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.emerald600),
            ),
            Text(
              '₹${widget.total.toInt()}',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: AppDesignSystem.emerald600),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppDesignSystem.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppDesignSystem.slate100, width: 1.2),
          ),
          child: Text(
            'Kya aapne customer ko parcel safely handover kar diya hai?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w600, color: AppDesignSystem.slate600, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppDesignSystem.slate200, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w800, color: AppDesignSystem.slate500)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => widget.onConfirmDelivery({
                  'deliveryLat': widget.lat,
                  'deliveryLng': widget.lng,
                  'paymentStatus': 'PAID',
                  'isRiderCash': false,
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.emeraldBrand,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text('Yes, Delivered ✅', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. COD MODAL (Screenshots 2, 3, 4)
  Widget _buildCodContent() {
    final orderTotalInt = widget.total.toInt();
    final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
    final changeToGive = math.max(0.0, cashReceived - widget.total);
    final cashPortion = double.tryParse(_cashPortionController.text) ?? 0.0;
    final netCashInHand = _hasSplitOnline ? cashPortion : math.min(cashReceived, widget.total);
    final onlinePortion = _hasSplitOnline ? math.max(0.0, widget.total - cashPortion) : 0.0;
    final walletAfter = widget.cashInHand + netCashInHand;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: AppDesignSystem.slate200, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppDesignSystem.success, AppDesignSystem.emerald600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppDesignSystem.success.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '₹',
                style: TextStyle(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Payment Collection',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 18), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
          ),
          const SizedBox(height: 3),
          Text(
            'Order #${widget.orderNum} • Collect: ₹$orderTotalInt',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate600),
          ),
          const SizedBox(height: 16),

          // STEP 1: Choice Screen (Screenshot 2)
          if (_step == 'choose') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppDesignSystem.slate200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 16, color: AppDesignSystem.slate500),
                  const SizedBox(width: 8),
                  Text(
                    'Jeb mein: ₹${widget.cashInHand.toInt()}',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate700),
                  ),
                  Text(
                    ' | ',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: AppDesignSystem.slate300),
                  ),
                  Text(
                    'Limit: ₹${widget.cashLimit.toInt()}',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Option 1: Cash Liya (कैश लिया)
            InkWell(
              onTap: () {
                setState(() {
                  _step = 'cash-calc';
                  _hasSplitOnline = false;
                  _cashReceivedController.text = orderTotalInt.toString();
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.amber50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.yellow200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.statusPending,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text('💵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Liya (कैश लिया)',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Customer ne cash diya — poora ya kuch',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, color: AppDesignSystem.stone500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppDesignSystem.amber600, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Online Mila (ऑनलाइन मिला)
            InkWell(
              onTap: () => widget.onOpenDoorstepQr(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.green50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.green200, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.green100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text('📱', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22)))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Online Mila (ऑनलाइन मिला)',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.green700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Poora GPay / PhonePe / UPI se aaya',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w500, color: AppDesignSystem.stone500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text('UPI', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w700, color: AppDesignSystem.slate400),
              ),
            ),
          ]

          // STEP 2: Cash Calculator (Screenshots 3 & 4)
          else ...[
            if (!_hasSplitOnline) ...[
              // Full Cash Input (Screenshot 3)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignSystem.amber50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.yellow200, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUSTOMER NE KITNA DIYA? (₹)',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.warning, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _cashReceivedController.text.isEmpty ? '0' : _cashReceivedController.text,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _getQuickPresets(orderTotalInt).map((preset) {
                        final isSelected = cashReceived.toInt() == preset;
                        final label = preset == orderTotalInt
                            ? '₹$preset exact'
                            : (preset >= 1000 ? '₹$preset note' : '₹$preset');
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _cashReceivedController.text = preset.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppDesignSystem.warning : AppDesignSystem.statusPending,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppDesignSystem.amber600 : AppDesignSystem.yellow200),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppDesignSystem.amber700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💵 Cash Received', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
                        Text('₹${cashReceived.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900)),
                      ],
                    ),
                    if (changeToGive > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🔄 Change wapas do', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.rose600)),
                          Text('-₹${changeToGive.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.rose600)),
                        ],
                      ),
                    ],
                    const Divider(height: 16, color: AppDesignSystem.slate200),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💰 Jeb mein rahega (Net Cash)', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.amber700)),
                        Text('₹${netCashInHand.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: AppDesignSystem.slate400),
                            const SizedBox(width: 4),
                            Text('Wallet after this', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate400)),
                          ],
                        ),
                        Text('₹${walletAfter.toInt()} / ₹${widget.cashLimit.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Split Option Link
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _hasSplitOnline = true;
                    _cashPortionController.text = (orderTotalInt ~/ 2).toString();
                  });
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: AppDesignSystem.violet600),
                label: Text(
                  'Kuch cash + kuch online mila? (Split)',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w800, color: AppDesignSystem.violet600),
                ),
              ),
            ] else ...[
              // Split Input (Screenshot 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppDesignSystem.violet50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppDesignSystem.violet200, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CASH MEIN KITNA LIYA? (₹)',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w900, color: AppDesignSystem.violet600, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppDesignSystem.violet600, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _cashPortionController.text.isEmpty ? '0' : _cashPortionController.text,
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 24), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _getSplitPresets(orderTotalInt).map((preset) {
                        final isSelected = cashPortion.toInt() == preset;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _cashPortionController.text = preset.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppDesignSystem.violet600 : AppDesignSystem.statusShipped,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppDesignSystem.violet700 : AppDesignSystem.violet200),
                            ),
                            child: Text(
                              '₹$preset cash',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : AppDesignSystem.violet600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Split Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💵 Cash Collected', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.amber700)),
                        Text('₹${cashPortion.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.amber700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('📱 Online Received', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w700, color: AppDesignSystem.green700)),
                        Text('₹${onlinePortion.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: AppDesignSystem.green700)),
                      ],
                    ),
                    const Divider(height: 16, color: AppDesignSystem.slate200),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: AppDesignSystem.slate900)),
                        Text('₹$orderTotalInt', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: AppDesignSystem.slate900)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: AppDesignSystem.slate400),
                            const SizedBox(width: 4),
                            Text('Wallet after this', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: AppDesignSystem.slate400)),
                          ],
                        ),
                        Text('₹${walletAfter.toInt()} / ₹${widget.cashLimit.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Back to full cash
              TextButton(
                onPressed: () {
                  setState(() {
                    _hasSplitOnline = false;
                    _cashReceivedController.text = orderTotalInt.toString();
                  });
                },
                child: Text(
                  '← Poora cash mein liya (no split)',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), fontWeight: FontWeight.w700, color: AppDesignSystem.slate500),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons: Back + Confirm
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _step = 'choose';
                        _hasSplitOnline = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppDesignSystem.slate200, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('← Back', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: AppDesignSystem.slate500)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final effectiveCash = _hasSplitOnline ? cashPortion : widget.total;
                      widget.onConfirmDelivery({
                        'deliveryLat': widget.lat,
                        'deliveryLng': widget.lng,
                        'paymentMethod': 'COD',
                        'paymentStatus': 'PAID',
                        'isRiderCash': effectiveCash > 0,
                        'paymentCollectedBy': 'RIDER',
                        'cashAmount': effectiveCash,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignSystem.emeraldBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text('Confirm ✅', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
