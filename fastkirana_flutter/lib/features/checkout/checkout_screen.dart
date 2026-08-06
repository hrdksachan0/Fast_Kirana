import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/order_repository.dart';
import '../../widgets/brand_button.dart';
import '../../widgets/brand_input.dart';
import '../../widgets/brand_card.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressFormKey = GlobalKey<FormState>();
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedPayment = 'cod';
  bool _isLoading = false;
  int _addressType = 0; // 0: Home, 1: Work, 2: Other

  final _paymentMethods = [
    {'id': 'cod', 'label': 'Cash on Delivery', 'icon': Icons.payments_outlined},
    {'id': 'upi', 'label': 'UPI', 'icon': Icons.account_balance_wallet_outlined},
    {'id': 'card', 'label': 'Card / Wallet', 'icon': Icons.credit_card},
  ];

  @override
  void dispose() {
    _houseNoController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_addressFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final orderRepo = OrderRepository(ref.read(dioProvider));
      final order = await orderRepo.placeOrder({
        'address': {
          'houseNo': _houseNoController.text,
          'street': _streetController.text,
          'area': _areaController.text,
          'city': _cityController.text,
          'pincode': _pincodeController.text,
          'phone': _phoneController.text,
          'label': _addressType == 0 ? 'Home' : _addressType == 1 ? 'Work' : 'Other',
        },
        'paymentMethod': _selectedPayment,
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OrderSuccessScreen(order: order)),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppDesignSystem.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        title: Text('Checkout', style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700, color: Colors.white,
        )),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _addressFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Delivery Address'),
              const SizedBox(height: 12),
              _buildAddressTypeSelector(),
              const SizedBox(height: 16),
              BrandInput(
                label: 'House / Flat No',
                controller: _houseNoController,
                prefixIcon: Icons.home_outlined,
                validator: (v) => Validators.required(v, 'House number'),
              ),
              const SizedBox(height: 16),
              BrandInput(
                label: 'Street / Society',
                controller: _streetController,
                prefixIcon: Icons.signpost_outlined,
                validator: (v) => Validators.required(v, 'Street'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BrandInput(
                      label: 'Area',
                      controller: _areaController,
                      prefixIcon: Icons.location_city_outlined,
                      validator: (v) => Validators.required(v, 'Area'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandInput(
                      label: 'City',
                      controller: _cityController,
                      prefixIcon: Icons.location_on_outlined,
                      validator: (v) => Validators.required(v, 'City'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BrandInput(
                      label: 'Pincode',
                      controller: _pincodeController,
                      prefixIcon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      validator: Validators.pincode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandInput(
                      label: 'Phone',
                      controller: _phoneController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Payment Method'),
              const SizedBox(height: 12),
              _buildPaymentSelector(),
              const SizedBox(height: 32),
              BrandButton(
                text: 'Place Order',
                onPressed: _isLoading ? null : _placeOrder,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppDesignSystem.textPrimary,
      ),
    );
  }

  Widget _buildAddressTypeSelector() {
    final types = ['Home', 'Work', 'Other'];
    return Row(
      children: List.generate(types.length, (index) {
        final isSelected = _addressType == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _addressType = index),
            child: Container(
              margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppDesignSystem.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppDesignSystem.primary : AppDesignSystem.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    index == 0 ? Icons.home_rounded : index == 1 ? Icons.work_rounded : Icons.location_on_rounded,
                    color: isSelected ? Colors.white : AppDesignSystem.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    types[index],
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppDesignSystem.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPaymentSelector() {
    return Column(
      children: _paymentMethods.map((method) {
        final isSelected = _selectedPayment == method['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedPayment = method['id'] as String),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppDesignSystem.primary : AppDesignSystem.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(method['icon'] as IconData, color: AppDesignSystem.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    method['label'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Radio<String>(
                  value: method['id'] as String,
                  groupValue: _selectedPayment,
                  onChanged: (v) => setState(() => _selectedPayment = v!),
                  activeColor: AppDesignSystem.primary,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}