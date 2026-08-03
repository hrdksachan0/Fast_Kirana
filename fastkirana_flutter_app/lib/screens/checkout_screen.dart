import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPayment = 'COD';
  bool _isProcessing = false;

  final List<String> _paymentMethods = [
    'COD',
    'UPI',
    'Wallet',
    'Online',
  ];

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final deliveryFee = cart.subtotalAmount >= 200 ? 0 : 40;
    final total = cart.subtotalAmount + deliveryFee;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded,
                      size: 22, color: AppTheme.textPrimary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Checkout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),

                  // Delivery Address
                  _SectionHeader(title: 'Delivery Address', icon: Icons.location_on_outlined),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.home_rounded, size: 20, color: AppTheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Home',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              Text(
                                'Sector 62, Noida, Uttar Pradesh',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: AppTheme.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Delivery Slot
                  _SectionHeader(title: 'Delivery Slot', icon: Icons.schedule_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFFD97706)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Express Delivery',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              Text(
                                '10 mins • 9:00 PM - 11:00 PM',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹$deliveryFee',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: deliveryFee == 0 ? AppTheme.primary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method
                  _SectionHeader(title: 'Payment Method', icon: Icons.payments_outlined),
                  const SizedBox(height: 8),
                  ..._paymentMethods.map((method) {
                    final isSelected = _selectedPayment == method;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedPayment = method);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.border.withOpacity(0.5),
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              method == 'COD'
                                  ? Icons.money_outlined
                                  : method == 'UPI'
                                  ? Icons.qr_code_scanner_outlined
                                  : method == 'Wallet'
                                  ? Icons.account_balance_wallet_outlined
                                  : Icons.credit_card_outlined,
                              size: 20,
                              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                method == 'COD' ? 'Cash on Delivery'
                                  : method == 'UPI' ? 'UPI Payment'
                                  : method == 'Wallet' ? 'FastKirana Wallet'
                                  : 'Online Payment',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, size: 22, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Order Summary
                  _SectionHeader(title: 'Order Summary', icon: Icons.receipt_long_outlined),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Item Total', value: '₹${cart.subtotalAmount.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _SummaryRow(
                          label: 'Delivery Fee',
                          value: deliveryFee == 0 ? 'FREE' : '₹$deliveryFee',
                          valueColor: deliveryFee == 0 ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                        if (cart.totalSavings > 0) ...[
                          const SizedBox(height: 8),
                          _SummaryRow(
                            label: 'You Save',
                            value: '-₹${cart.totalSavings.toStringAsFixed(0)}',
                            valueColor: AppTheme.primary,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Divider(color: AppTheme.border.withOpacity(0.5), height: 1),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Grand Total',
                          value: '₹${total.toInt()}',
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Place Order Button
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () async {
                    setState(() => _isProcessing = true);
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) {
                      setState(() => _isProcessing = false);
                      cart.clearCart();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Order placed successfully! 🎉\nEstimated delivery: 10 mins',
                              style: const TextStyle(fontSize: 13),
                            ),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    }
                  },
                  style: ElevatedButton(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(AppTheme.primaryDark),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'PLACE ORDER • ₹${total.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
