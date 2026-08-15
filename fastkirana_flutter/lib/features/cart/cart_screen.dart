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

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'My Cart',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
        ),
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart.items.isEmpty) return _buildEmptyState(context);
          return _buildCartContent(context, ref, cart);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppDesignSystem.primary)),
        error: (_, __) => _buildEmptyState(context),
      ),
    );
  }

  Widget _buildCartContent(BuildContext context, WidgetRef ref, Cart cart) {
    final subtotal = cart.subtotal;
    final deliveryFee = subtotal >= 199 ? 0.0 : 25.0;
    final discount = cart.couponDiscount > 0 ? cart.couponDiscount : cart.savings;
    final total = subtotal + deliveryFee - discount;
    final totalItems = cart.totalItems;

    return Stack(
      children: [
        Positioned.fill(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 200),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return _buildCartItemCard(context, ref, item);
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildGlassBottomSheet(context, totalItems, subtotal, deliveryFee, discount, total),
        ),
      ],
    );
  }

  Widget _buildCartItemCard(BuildContext context, WidgetRef ref, CartItem item) {
    final product = item.product;
    final isLowStock = product.stock > 0 && product.stock <= (product.minStock ?? 5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppDesignSystem.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.borderLight),
        boxShadow: AppDesignSystem.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(product: product),
                ));
              },
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: bgLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: product.imageUrl!, fit: BoxFit.contain, width: 64, height: 64))
                    : Center(child: Text(_getEmoji(product.name), style: const TextStyle(fontSize: 28))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ref.read(cartProvider.notifier).removeItem(item.id),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.danger.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.delete_outline_rounded, size: 16, color: AppDesignSystem.danger),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(product.unit, style: GoogleFonts.inter(fontSize: 11, color: textMuted)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('₹${product.price.toInt()}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: textDark)),
                      if (product.mrp > product.price) ...[
                        const SizedBox(width: 6),
                        Text('₹${product.mrp.toInt()}', style: GoogleFonts.inter(fontSize: 11, decoration: TextDecoration.lineThrough, color: textMuted)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${product.discount.toInt()}% OFF', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: AppDesignSystem.primary)),
                        ),
                      ],
                    ],
                  ),
                  if (isLowStock) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: AppDesignSystem.warning),
                        const SizedBox(width: 4),
                        Text('Only ${product.stock} left', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppDesignSystem.warning)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                _qtyBtn(Icons.remove_rounded, () {
                  if (item.quantity > 1) {
                    ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1);
                  } else {
                    ref.read(cartProvider.notifier).removeItem(item.id);
                  }
                }),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text('${item.quantity}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: textDark)),
                ),
                _qtyBtn(Icons.add_rounded, () {
                  ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1);
                }),
              ],
            ),
          ],
        ),
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

  Widget _buildGlassBottomSheet(BuildContext context, int totalItems, double subtotal, double deliveryFee, double discount, double total) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.95),
            Colors.white,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppDesignSystem.borderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bill Details', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: textDark)),
                      Text('$totalItems items', style: GoogleFonts.inter(fontSize: 13, color: textMuted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _billRow('Item Total', '₹${subtotal.toInt()}'),
                  _billRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toInt()}', isGreen: deliveryFee == 0),
                  if (discount > 0) ...[
                    const SizedBox(height: 6),
                    _billRow('Discount', '-₹${discount.toInt()}', isGreen: true),
                  ],
                  const SizedBox(height: 12),
                  Container(height: 1, color: AppDesignSystem.divider),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('To Pay', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
                      Text('₹${total.toInt()}', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: AppDesignSystem.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const CheckoutScreen(),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('Place Order', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textMuted)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isGreen ? AppDesignSystem.primary : textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110, height: 110,
            decoration: BoxDecoration(
              color: AppDesignSystem.surface,
              borderRadius: BorderRadius.circular(55),
              border: Border.all(color: AppDesignSystem.borderLight),
              boxShadow: AppDesignSystem.shadowMd,
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 56, color: AppDesignSystem.textMuted),
          ),
          const SizedBox(height: 28),
          Text('Your cart is empty', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 8),
          Text('Looks like you haven\'t added anything yet', style: GoogleFonts.inter(fontSize: 14, color: textMuted)),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              gradient: AppDesignSystem.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
              label: Text('Start Shopping', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
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
