import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/cart.dart';
import '../../data/models/product.dart';
import '../../providers/cart_provider.dart';
import '../products/product_detail_screen.dart';
import '../checkout/checkout_screen.dart';
import '../../widgets/brand_button.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);

    return cartAsync.when(
      data: (cart) {
        if (cart.items.isEmpty) {
          return _buildEmptyState();
        }

        final subtotal = cart.subtotal;
        final deliveryFee = subtotal > 199 ? 0.0 : 35.0;
        final discount = cart.couponDiscount > 0 ? cart.couponDiscount : (subtotal * 0.05);
        final total = subtotal + deliveryFee - discount;

        return Scaffold(
          backgroundColor: AppDesignSystem.background,
          appBar: AppBar(
            backgroundColor: AppDesignSystem.background,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'My Cart',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return _buildCartItem(item);
                  },
                ),
              ),
              _buildBillSummary(subtotal, deliveryFee, discount, total, cart.items),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _buildEmptyState(),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
            leading: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: item.product),
                ));
              },
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppDesignSystem.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: item.product.imageUrl!, fit: BoxFit.contain))
                    : Center(child: Text(_getEmoji(item.product.name), style: const TextStyle(fontSize: 28))),
              ),
            ),
            title: Text(
              item.product.name,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppDesignSystem.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Text('₹${item.product.price.toInt()}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                  const SizedBox(width: 6),
                  if (item.product.mrp > item.product.price)
                    Text('₹${item.product.mrp.toInt()}', style: GoogleFonts.inter(fontSize: 11, decoration: TextDecoration.lineThrough, color: AppDesignSystem.textMuted)),
                ],
              ),
            ),
            trailing: IconButton(
              onPressed: () => ref.read(cartProvider.notifier).removeItem(item.id),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppDesignSystem.danger),
              style: IconButton.styleFrom(backgroundColor: AppDesignSystem.danger.withOpacity(0.08)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(80, 0, 14, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _qtyBtn(Icons.remove_rounded, () {
                  if (item.quantity > 1) {
                    ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1);
                  } else {
                    ref.read(cartProvider.notifier).removeItem(item.id);
                  }
                }),
                Container(
                  width: 42,
                  alignment: Alignment.center,
                  child: Text('${item.quantity}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
                ),
                _qtyBtn(Icons.add_rounded, () {
                  ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1);
                }),
                const SizedBox(width: 12),
                Text(
                  '₹${item.lineTotal.toInt()}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppDesignSystem.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppDesignSystem.primary),
      ),
    );
  }

  Widget _buildBillSummary(double subtotal, double deliveryFee, double discount, double total, List<CartItem> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppDesignSystem.shadowElevated,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Item Total', '₹${subtotal.toInt()}'),
            const SizedBox(height: 8),
            _row('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}', isGreen: deliveryFee == 0),
            if (discount > 0) ...[
              const SizedBox(height: 8),
              _row('Discount Savings', '-₹${discount.toInt()}', isGreen: true),
            ],
            const Divider(height: 24),
            _row('To Pay', '₹${total.toInt()}', isBold: true),
            const SizedBox(height: 16),
            BrandButton(
              text: 'Proceed to Checkout',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500, color: AppDesignSystem.textSecondary)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: isGreen ? AppDesignSystem.accent : AppDesignSystem.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppDesignSystem.surface,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppDesignSystem.borderLight),
                boxShadow: AppDesignSystem.shadowSm,
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 56, color: AppDesignSystem.textMuted),
            ),
            const SizedBox(height: 24),
            Text('Your cart is empty', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppDesignSystem.textPrimary)),
            const SizedBox(height: 8),
            Text('Looks like you haven\'t added anything yet', style: GoogleFonts.inter(fontSize: 14, color: AppDesignSystem.textSecondary)),
            const SizedBox(height: 28),
            BrandButton(
              text: 'Start Shopping',
              fullWidth: false,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('apple')) return '🍎';
    return '🛒';
  }
}