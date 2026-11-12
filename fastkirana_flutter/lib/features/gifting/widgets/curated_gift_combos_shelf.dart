import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/product.dart';
import '../../../providers/cart_provider.dart';

class GiftComboBundle {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final String image1;
  final String name1;
  final String image2;
  final String name2;
  final double totalPrice;
  final double originalPrice;
  final List<String> searchKeywords;

  const GiftComboBundle({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.image1,
    required this.name1,
    required this.image2,
    required this.name2,
    required this.totalPrice,
    required this.originalPrice,
    required this.searchKeywords,
  });
}

class CuratedGiftCombosShelf extends ConsumerWidget {
  final List<Product> catalog;
  final VoidCallback onHamperAdded;

  const CuratedGiftCombosShelf({
    super.key,
    required this.catalog,
    required this.onHamperAdded,
  });

  static const List<GiftComboBundle> _defaultCombos = [
    GiftComboBundle(
      id: 'combo-romance',
      title: 'Romance & Truffle Duo',
      subtitle: 'Red Rose Bouquet + Belgian Truffle Cake',
      tag: '🔥 POPULAR DUO',
      image1: 'assets/navratri/ref-rose-bouquet.png',
      name1: 'Rose Bouquet (8 Stems)',
      image2: 'assets/navratri/ref-chocolate-cake.png',
      name2: 'Truffle Cake (500g)',
      totalPrice: 699,
      originalPrice: 898,
      searchKeywords: ['rose', 'cake'],
    ),
    GiftComboBundle(
      id: 'combo-celebration',
      title: 'Sweet Celebrations Box',
      subtitle: 'Premium Kaju Katli + Ferrero Rocher Box',
      tag: '✨ ROYAL CHOICE',
      image1: 'assets/navratri/haldirams-kaju-katli-box.webp',
      name1: 'Kaju Katli (250g)',
      image2: 'assets/navratri/diwali-chocolates.svg',
      name2: 'Ferrero Rocher Box',
      totalPrice: 499,
      originalPrice: 649,
      searchKeywords: ['kaju', 'chocolate'],
    ),
    GiftComboBundle(
      id: 'combo-party',
      title: 'Midnight Surprise Hamper',
      subtitle: 'Strawberry Delight Cake + Celebration Popper',
      tag: '🎉 MIDNIGHT HIT',
      image1: 'assets/navratri/gifting-boutique-hero-hd.jpg',
      name1: 'Berry Velvet Cake',
      image2: 'assets/navratri/ref-rose-bouquet.png',
      name2: 'Fresh Petals & Card',
      totalPrice: 549,
      originalPrice: 720,
      searchKeywords: ['cake', 'gift'],
    ),
  ];

  void _addComboToCart(WidgetRef ref, GiftComboBundle combo) {
    HapticFeedback.mediumImpact();

    // Match with real DB products from catalog if possible
    Product? prod1;
    Product? prod2;

    for (final p in catalog) {
      final nl = p.name.toLowerCase();
      if (prod1 == null && combo.searchKeywords.isNotEmpty && nl.contains(combo.searchKeywords[0])) {
        prod1 = p;
      } else if (prod2 == null && combo.searchKeywords.length > 1 && nl.contains(combo.searchKeywords[1])) {
        prod2 = p;
      }
    }

    final p1 = prod1 ??
        Product(
          id: '${combo.id}_1',
          name: combo.name1,
          slug: '${combo.id}_1',
          mrp: combo.originalPrice * 0.55,
          price: combo.totalPrice * 0.55,
          discount: 15,
          unit: '1 box',
          stock: 99,
          isAvailable: true,
          tags: const ['gifting', 'combo'],
          minStock: 0,
          costPrice: combo.totalPrice * 0.4,
          isFlashDeal: false,
          isTopPick: true,
          isBestSeller: true,
          sortOrder: 0,
          createdAt: DateTime.now(),
          imageUrl: combo.image1,
        );

    final p2 = prod2 ??
        Product(
          id: '${combo.id}_2',
          name: combo.name2,
          slug: '${combo.id}_2',
          mrp: combo.originalPrice * 0.45,
          price: combo.totalPrice * 0.45,
          discount: 15,
          unit: '1 pc',
          stock: 99,
          isAvailable: true,
          tags: const ['gifting', 'combo'],
          minStock: 0,
          costPrice: combo.totalPrice * 0.35,
          isFlashDeal: false,
          isTopPick: true,
          isBestSeller: true,
          sortOrder: 0,
          createdAt: DateTime.now(),
          imageUrl: combo.image2,
        );

    ref.read(cartProvider.notifier).addProduct(p1, 1);
    ref.read(cartProvider.notifier).addProduct(p2, 1);
    onHamperAdded();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  'SAVE UP TO 25%',
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
            itemCount: _defaultCombos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final combo = _defaultCombos[index];
              final saved = (combo.originalPrice - combo.totalPrice).round();

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
                    // Combo Badge & Saving Pill
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
                            combo.tag,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFE082),
                            ),
                          ),
                        ),
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

                    // Duo Artwork Preview (Overlapping Dual Circles)
                    Row(
                      children: [
                        SizedBox(
                          width: 82,
                          height: 52,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 0,
                                top: 2,
                                child: _ComboMiniAvatar(image: combo.image1),
                              ),
                              Positioned(
                                left: 32,
                                top: 2,
                                child: _ComboMiniAvatar(image: combo.image2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                combo.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3D0C18),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                combo.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF7A4A57),
                                ),
                              ),
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
                              '₹${combo.totalPrice.toInt()}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF3D0C18),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '₹${combo.originalPrice.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        Bounceable(
                          onTap: () => _addComboToCart(ref, combo),
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

class _ComboMiniAvatar extends StatelessWidget {
  final String image;

  const _ComboMiniAvatar({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
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
        child: image.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.card_giftcard, size: 20),
              )
            : Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, size: 20),
              ),
      ),
    );
  }
}
