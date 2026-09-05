import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/responsive.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/product_card.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;

  void _shareWishlist(BuildContext context, List wishlist) {
    HapticFeedback.lightImpact();
    if (wishlist.isEmpty) return;

    final itemNames = wishlist.map((p) => '• ${p.name} - ₹${p.price.toStringAsFixed(0)}').join('\n');
    final shareText = '''🛒 My FastKirana Wishlist:\n\n$itemNames\n\nOrder fresh groceries & food delivered in 10 mins on FastKirana Ghatampur!\nDownload the app: https://www.fastkirana.in''';

    Share.share(shareText, subject: 'My FastKirana Wishlist');
  }

  void _shareApp(BuildContext context) {
    HapticFeedback.lightImpact();
    const shareText = '''⚡ Order Groceries, Daily Essentials & Restaurant Food in Ghatampur delivered in 10-15 mins with FastKirana!\n\nDownload FastKirana app now: https://www.fastkirana.in''';
    Share.share(shareText, subject: 'Download FastKirana App');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Bounceable(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate50,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: slateDark,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Wishlist',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17),
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
            ),
            if (wishlist.isNotEmpty)
              Text(
                '${wishlist.length} saved ${wishlist.length == 1 ? "item" : "items"}',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11.5),
                  fontWeight: FontWeight.w600,
                  color: slateMuted,
                ),
              ),
          ],
        ),
        actions: [
          if (wishlist.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Bounceable(
                onTap: () => _shareWishlist(context, wishlist),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.rose50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.rose100alt),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.share_rounded, size: 14, color: primaryRed),
                      const SizedBox(width: 5),
                      Text(
                        'Share List',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: primaryRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Bounceable(
              onTap: () => _shareApp(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppDesignSystem.slate100,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppDesignSystem.slate200),
                ),
                child: const Icon(
                  Icons.share_outlined,
                  color: slateDark,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: Responsive.wideMaxContentWidth,
          fillHeight: true,
          child: wishlist.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.rose50,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppDesignSystem.rose100alt, width: 2),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 42,
                              color: primaryRed,
                            ),
                          ),
                        ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack),
                        const SizedBox(height: 18),
                        Text(
                          'Your Wishlist is Empty',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 19),
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Explore products and tap the heart icon to save your favorite grocery and food items!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w500,
                            color: slateMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Bounceable(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [primaryRed, AppDesignSystem.primaryLight],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryRed.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Explore Store ➔',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13.5),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Bounceable(
                              onTap: () => _shareApp(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppDesignSystem.slate200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.share_rounded, size: 15, color: slateDark),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Share App',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 13),
                                        fontWeight: FontWeight.w700,
                                        color: slateDark,
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
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        Responsive.horizontalPadding(context),
                        16,
                        Responsive.horizontalPadding(context),
                        120,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: Responsive.gridColumns(context, smallMobile: 2, mobile: 2, smallTablet: 3, tablet: 4, desktop: 5),
                          childAspectRatio: Responsive.productCardAspectRatio(context, isCompact: true),
                          crossAxisSpacing: Responsive.horizontalPadding(context) * 0.5,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => ProductCard(product: wishlist[index]),
                          childCount: wishlist.length,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
