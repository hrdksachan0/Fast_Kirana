import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../data/models/address.dart';
import '../../data/models/cart.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/cart_provider.dart';
import '../../core/network/api_client.dart';
import '../../widgets/brand_input.dart';
import '../../widgets/brand_card.dart';
import '../../widgets/brand_button.dart';
import 'order_success_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _addressType = 0;
  bool _isLoading = false;
  String _selectedPayment = 'cod';
  final double _freeDeliveryThreshold = 199.0;
  final double _deliveryFee = 25.0;

  final _controllers = {
    'house': TextEditingController(),
    'street': TextEditingController(),
    'area': TextEditingController(),
    'city': TextEditingController(),
    'pincode': TextEditingController(),
    'phone': TextEditingController(),
  };

  final _paymentMethods = [
    {'id': 'cod', 'label': 'Cash on Delivery', 'icon': Icons.payments_outlined},
    {'id': 'upi', 'label': 'UPI / GPay / PhonePe', 'icon': Icons.qr_code_2_outlined},
    {'id': 'card', 'label': 'Card / Wallet', 'icon': Icons.credit_card_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: cartAsync.when(
        data: (cart) {
          if (cart.items.isEmpty) {
            return _buildEmptyState();
          }
          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildAddressSection(),
                    const SizedBox(height: 20),
                    _buildPaymentSection(),
                    const SizedBox(height: 20),
                    _buildOrderSummary(cart),
                    const SizedBox(height: 20),
                    BrandButton(
                      text: 'Place Order',
                      onPressed: () => _placeOrder(cart),
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: AppDesignSystem.danger)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: AppDesignSystem.primary,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          ),
          Text(
            'Checkout',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    final addressTypes = ['Home', 'Work', 'Other'];
    final icons = [Icons.home_rounded, Icons.work_rounded, Icons.location_on_rounded];

    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Address',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Address Type Selector
          Row(
            children: List.generate(3, (index) {
              final isSelected = _addressType == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _addressType = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: isSelected ? AppDesignSystem.primary.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppDesignSystem.primary : AppDesignSystem.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[index],
                          size: 18,
                          color: isSelected ? AppDesignSystem.primary : AppDesignSystem.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          addressTypes[index],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppDesignSystem.primary : AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),
          BrandInput(
            label: 'House / Flat No',
            controller: _controllers['house']!,
            hint: 'e.g., 123, Flat 4B',
            prefixIcon: Icons.home_outlined,
            validator: (v) => Validators.required(v, 'House number'),
          ),
          const SizedBox(height: 12),
          BrandInput(
            label: 'Street / Society',
            controller: _controllers['street']!,
            hint: 'e.g., Main Street, Galaxy Apartments',
            prefixIcon: Icons.signpost_outlined,
            validator: (v) => Validators.required(v, 'Street'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BrandInput(
                  label: 'Area',
                  controller: _controllers['area']!,
                  hint: 'Area',
                  prefixIcon: Icons.location_city_outlined,
                  validator: (v) => Validators.required(v, 'Area'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BrandInput(
                  label: 'City',
                  controller: _controllers['city']!,
                  hint: 'City',
                  prefixIcon: Icons.location_on_outlined,
                  validator: (v) => Validators.required(v, 'City'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BrandInput(
                  label: 'Pincode',
                  controller: _controllers['pincode']!,
                  hint: '6-digit pincode',
                  prefixIcon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  validator: Validators.pincode,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BrandInput(
                  label: 'Phone',
                  controller: _controllers['phone']!,
                  hint: '10-digit mobile',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(_paymentMethods.length, (index) {
            final method = _paymentMethods[index];
            final isSelected = _selectedPayment == method['id'];
            return GestureDetector(
              onTap: () => setState(() => _selectedPayment = method['id'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppDesignSystem.primary.withOpacity(0.04)
                      : AppDesignSystem.surface,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
                  border: Border.all(
                    color: isSelected ? AppDesignSystem.primary : AppDesignSystem.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppDesignSystem.primary.withOpacity(0.1)
                            : AppDesignSystem.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        method['icon'] as IconData,
                        color: AppDesignSystem.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        method['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: AppDesignSystem.textPrimary,
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
          }),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(Cart cart) {
    final subtotal = cart.subtotal;
    final deliveryFee = subtotal >= _freeDeliveryThreshold ? 0.0 : _deliveryFee;
    final total = subtotal + deliveryFee;

    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...cart.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.borderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: item.product.imageUrl!,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                          ),
                        )
                      : const Icon(Icons.shopping_bag, size: 18, color: AppDesignSystem.textMuted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'x${item.quantity}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppDesignSystem.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Helpers.formatPrice(item.lineTotal),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )),
          const Divider(height: 20),
          _buildRow('Subtotal', Helpers.formatPrice(subtotal)),
          _buildRow(
            'Delivery',
            deliveryFee == 0 ? 'FREE' : Helpers.formatPrice(deliveryFee),
            highlight: deliveryFee == 0,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.textPrimary,
                ),
              ),
              Text(
                Helpers.formatPrice(total),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppDesignSystem.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: highlight ? AppDesignSystem.accent : AppDesignSystem.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: AppDesignSystem.textMuted),
            const SizedBox(height: 16),
            Text('Your cart is empty', style: GoogleFonts.inter(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(Cart cart) async {
    final house = _controllers['house']!.text.trim();
    final street = _controllers['street']!.text.trim();
    final area = _controllers['area']!.text.trim();
    final city = _controllers['city']!.text.trim();
    final pincode = _controllers['pincode']!.text.trim();
    final phone = _controllers['phone']!.text.trim();

    if (house.isEmpty || street.isEmpty || area.isEmpty || city.isEmpty || pincode.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all address fields'), backgroundColor: AppDesignSystem.danger),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      final order = await repo.placeOrder({
        'address': {
          'houseNo': house,
          'street': street,
          'area': area,
          'city': city,
          'pincode': pincode,
          'phone': phone,
          'label': _addressType == 0 ? 'Home' : _addressType == 1 ? 'Work' : 'Other',
        },
        'paymentMethod': _selectedPayment,
        'items': cart.items.map((item) => {
          'productId': item.productId,
          'quantity': item.quantity,
        }).toList(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OrderSuccessScreen(orderId: order.id)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppDesignSystem.danger),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}