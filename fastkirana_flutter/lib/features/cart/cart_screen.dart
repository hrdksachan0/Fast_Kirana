import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/validators.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/brand_button.dart';
import '../../widgets/brand_card.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.background,
      appBar: AppBar(
        title: Text(
          'My Cart',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppDesignSystem.primary,
        elevation: 0,
      ),
      body: cartAsync.when(
        data: (cart) {
          if (cart.items.isEmpty) {
            return _buildEmptyCart(context);
          }
          return Column(
            children: [
              Expanded(child: _buildCartList(context, ref, cart)),
              _buildCartSummary(context, cart),
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

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppDesignSystem.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppDesignSystem.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items to start shopping',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppDesignSystem.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          BrandButton(
            text: 'Start Shopping',
            onPressed: () => Navigator.pop(context),
            width: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildCartList(BuildContext context, WidgetRef ref, cart) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: AppDesignSystem.danger,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLg),
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) {
            ref.read(cartProvider.notifier).removeItem(item.id);
          },
          child: BrandCard(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.product.imageUrl ?? '',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 80,
                      color: AppDesignSystem.borderLight,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.product.unit,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        Helpers.formatPrice(item.lineTotal),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildQuantityControl(context, ref, item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantityControl(BuildContext context, WidgetRef ref, item) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesignSystem.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: item.quantity > 1
                ? () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1)
                : null,
            icon: const Icon(Icons.remove, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${item.quantity}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1),
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(BuildContext context, cart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: AppDesignSystem.shadowLg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: GoogleFonts.poppins(fontSize: 14)),
              Text(
                Helpers.formatPrice(cart.subtotal),
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Fee', style: GoogleFonts.poppins(fontSize: 14)),
              Text('FREE', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppDesignSystem.accent,
              )),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700,
              )),
              Text(
                Helpers.formatPrice(cart.subtotal),
                style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppDesignSystem.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BrandButton(
            text: 'Proceed to Checkout',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CheckoutScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}