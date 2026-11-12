import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/gifting_store_config.dart';
import '../../../../providers/cart_provider.dart';

/// Curated 1-Tap Gift Hampers Shelf
/// Strictly renders only Admin-created custom hampers from the Admin Web Console.
/// Zero hardcoded fake bundles or mock Unsplash products.
class CuratedGiftCombosShelf extends ConsumerWidget {
  final List<GiftingHamperModel> hampers;
  final List<Product> catalog;
  final VoidCallback onHamperAdded;

  const CuratedGiftCombosShelf({
    super.key,
    required this.hampers,
    required this.catalog,
    required this.onHamperAdded,
  });

  void _addHamperToCart(BuildContext context, WidgetRef ref, GiftingHamperModel hamper) {
    HapticFeedback.mediumImpact();

    // 1. Resolve real bundled products from active catalog
    final itemsToAdd = <Product>[];
    for (final prodId in hamper.bundledProductIds) {
      final found = catalog.firstWhereOrNull(
        (p) => p.id == prodId || p.slug == prodId,
      );
      if (found != null && found.isAvailable) {
        itemsToAdd.add(found);
      }
    }

    if (itemsToAdd.isEmpty) {
      // If no bundled items found in local stock, check if hamper itself exists as product
      final matchedHamper = catalog.firstWhereOrNull(
        (p) => p.id == hamper.id || p.name.toLowerCase() == hamper.name.toLowerCase(),
      );
      if (matchedHamper != null && matchedHamper.isAvailable) {
        ref.read(cartProvider.notifier).addProduct(matchedHamper, 1);
        onHamperAdded();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${hamper.name} items are currently out of stock at this hub'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Add all bundled real products to cart
    for (final item in itemsToAdd) {
      ref.read(cartProvider.notifier).addProduct(item, 1);
    }
    onHamperAdded();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeHampers = hampers.where((h) => h.isActive).toList();
    if (activeHampers.isEmpty) {
      return const SizedBox.shrink(); // Zero fake hampers!
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'Curated 1-Tap Gift Hampers',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF3D0C18),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  'LIMITED EDITION',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF92400E),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Hampers Carousel
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: activeHampers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final hamper = activeHampers[index];
              final saved = hamper.mrp > hamper.price ? (hamper.mrp - hamper.price).round() : 0;

              return Container(
                width: 270,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Color(0xFFFFF9FA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEBC1CC), width: 1.1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B1728).withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge & Saving Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B1728),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hamper.badge.isNotEmpty ? hamper.badge : '✨ CURATED DUO',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFE082),
                            ),
                          ),
                        ),
                        if (saved > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Save ₹$saved',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Artwork Preview & Title
                    Row(
                      children: [
                        _HamperAvatar(imageUrl: hamper.imageUrl),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hamper.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3D0C18),
                                ),
                              ),
                              if (hamper.tagline.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  hamper.tagline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF7A4A57),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Price & 1-Tap Add Hamper Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${hamper.price.toInt()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF3D0C18),
                              ),
                            ),
                            if (hamper.mrp > hamper.price) ...[
                              const SizedBox(width: 5),
                              Text(
                                '₹${hamper.mrp.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Bounceable(
                          onTap: () => _addHamperToCart(context, ref, hamper),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFBE123C), Color(0xFFE11D48)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFBE123C).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🎁', style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Hamper',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HamperAvatar extends StatelessWidget {
  final String imageUrl;

  const _HamperAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFEBC1CC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Center(
                  child: Text('🎁', style: TextStyle(fontSize: 22)),
                ),
              )
            : const Center(
                child: Text('🎁', style: TextStyle(fontSize: 22)),
              ),
      ),
    );
  }
}
