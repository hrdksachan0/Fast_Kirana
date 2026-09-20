import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/network/api_client.dart';
import '../../../providers/store_settings_provider.dart';

/// Doorstep Cashfree Dynamic UPI QR Bottom Sheet with Live Auto-Detection
class DoorstepCashfreeQrSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final String orderId;
  final String orderNum;
  final double total;
  final Future<void> Function(Map<String, dynamic> extra) onConfirmPaid;

  const DoorstepCashfreeQrSheet({
    super.key,
    required this.order,
    required this.orderId,
    required this.orderNum,
    required this.total,
    required this.onConfirmPaid,
  });

  @override
  ConsumerState<DoorstepCashfreeQrSheet> createState() => _DoorstepCashfreeQrSheetState();
}

class _DoorstepCashfreeQrSheetState extends ConsumerState<DoorstepCashfreeQrSheet> {
  bool _isLoading = true;
  bool _isPaid = false;
  String _cashfreeQrUrl = '';
  String _directUpiQrUrl = '';
  String _qrImageUrl = '';
  String _upiVpa = '';
  Timer? _pollTimer;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _fetchQrData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQrData() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/delivery/orders/${widget.orderId}/qr?t=${DateTime.now().millisecondsSinceEpoch}');
      if (res.statusCode == 200 && res.data != null && mounted) {
        final data = res.data;
        final status = data['paymentStatus']?.toString().toUpperCase();
        setState(() {
          _cashfreeQrUrl = data['cashfreeQrUrl']?.toString() ?? '';
          _directUpiQrUrl = data['directUpiQrUrl']?.toString() ?? '';
          _qrImageUrl = data['qrImageUrl']?.toString() ?? '';
          _upiVpa = data['upiVpa']?.toString() ?? '';
          _isLoading = false;
        });

        if (status == 'PAID' && !_isPaid) {
          _onPaymentReceived();
        }
      }
    } catch (e) {
      if (mounted) {
        final settings = ref.read(storeSettingsProvider).valueOrNull;
        final vpa = settings?.storeUpiVpa.isNotEmpty == true ? settings!.storeUpiVpa : '7054470303-2@ibl';
        final payee = Uri.encodeComponent('FastKirana');
        final note = Uri.encodeComponent('Order #${widget.orderNum}');
        final upiUri = 'upi://pay?pa=$vpa&pn=$payee&am=${widget.total.toStringAsFixed(2)}&cu=INR&tn=$note';
        final fallbackQr = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(upiUri)}';

        setState(() {
          _qrImageUrl = fallbackQr;
          _directUpiQrUrl = fallbackQr;
          _upiVpa = vpa;
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isPaid) {
        timer.cancel();
        return;
      }
      try {
        final dio = ref.read(dioProvider);
        final res = await dio.get('/api/delivery/orders/${widget.orderId}/qr?t=${DateTime.now().millisecondsSinceEpoch}');
        if (res.statusCode == 200 && res.data != null && mounted) {
          final status = res.data['paymentStatus']?.toString().toUpperCase();
          if (status == 'PAID') {
            timer.cancel();
            _onPaymentReceived();
          }
        }
      } catch (_) {}
    });
  }

  void _onPaymentReceived() {
    HapticFeedback.heavyImpact();
    if (mounted) {
      setState(() {
        _isPaid = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeQr = _cashfreeQrUrl.isNotEmpty
        ? _cashfreeQrUrl
        : (_qrImageUrl.isNotEmpty ? _qrImageUrl : _directUpiQrUrl);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppDesignSystem.slate200, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isPaid ? 'Payment Confirmed' : 'Doorstep QR Collection',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 16),
                            fontWeight: FontWeight.w900,
                            color: _isPaid ? AppDesignSystem.emerald700 : AppDesignSystem.slate900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isPaid ? AppDesignSystem.green100 : AppDesignSystem.blue50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isPaid ? AppDesignSystem.green200 : AppDesignSystem.blue200,
                            ),
                          ),
                          child: Text(
                            _isPaid ? 'PAID ✅' : 'CASHFREE ⚡',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 9.5),
                              fontWeight: FontWeight.w900,
                              color: _isPaid ? AppDesignSystem.green700 : AppDesignSystem.blue700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order #${widget.orderNum} • ₹${widget.total.toInt()}',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppDesignSystem.slate900),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Display: PAID Screen OR QR Code
          if (_isPaid) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppDesignSystem.green50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.green200, width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Payment Verified! ✅',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 16),
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.green800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${widget.total.toInt()} credited via Cashfree',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.green700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppDesignSystem.green200),
                    ),
                    child: Text(
                      'Collect ₹0 Cash from Customer 🚀',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.green800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _isCompleting
                  ? null
                  : () async {
                      setState(() => _isCompleting = true);
                      await widget.onConfirmPaid({
                        'paymentMethod': 'UPI',
                        'paymentStatus': 'PAID',
                        'paymentCollectedBy': 'ONLINE',
                        'isRiderCash': false,
                        'notes': 'Paid via Doorstep Cashfree QR',
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.success,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isCompleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Complete Delivery ✅',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppDesignSystem.slate200, width: 1.5),
              ),
              child: Column(
                children: [
                  if (_isLoading) ...[
                    const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppDesignSystem.success),
                            SizedBox(height: 14),
                            Text('Generating Cashfree QR...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppDesignSystem.slate900)),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: activeQr.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(activeQr.split(',').last),
                              width: 220,
                              height: 220,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(Icons.qr_code_2_rounded, size: 100, color: AppDesignSystem.slate500),
                            )
                          : CachedNetworkImage(
                              imageUrl: activeQr,
                              width: 220,
                              height: 220,
                              placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: AppDesignSystem.success)),
                              errorWidget: (c, u, e) => const Icon(Icons.qr_code_2_rounded, size: 100, color: AppDesignSystem.slate500),
                            ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Scan via Google Pay, PhonePe, Paytm, BHIM or Cred',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.slate500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_upiVpa.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Store VPA: $_upiVpa',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.emerald600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Checking Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppDesignSystem.green50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignSystem.green100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.emerald600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-checking payment status every 3s...',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.emerald700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Manual confirmation button if needed
            ElevatedButton(
              onPressed: () async {
                await widget.onConfirmPaid({
                  'paymentMethod': 'UPI',
                  'paymentStatus': 'PAID',
                  'paymentCollectedBy': 'ONLINE',
                  'isRiderCash': false,
                  'notes': 'Paid via Doorstep Cashfree QR scan',
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.success,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Confirm Customer Paid ₹${widget.total.toInt()} via QR',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
