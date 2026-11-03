import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/product.dart';
import '../../../widgets/product_card.dart';
import '../../products/product_detail_screen.dart';

/// Ultra-Premium "Chilled Freezer" Add-ons Tray for Cafe & Restaurant Menu Screens.
/// Features an authentic frosted ice glass aesthetic, gentle breathing float animation,
/// subtle icy shimmer mist, and 100% in-stock cold drinks and ice cream desserts.
class ChilledFreezerAddonSection extends StatefulWidget {
  final List<Product> addons;

  const ChilledFreezerAddonSection({
    super.key,
    required this.addons,
  });

  @override
  State<ChilledFreezerAddonSection> createState() => _ChilledFreezerAddonSectionState();
}

class _ChilledFreezerAddonSectionState extends State<ChilledFreezerAddonSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutSine,
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inStockList = widget.addons
        .where((p) =>
            p.isAvailable &&
            p.isInStock &&
            (p.parsedVariants.isNotEmpty
                ? p.parsedVariants.any((v) => v.stock > 0)
                : p.stock > 0))
        .toList();

    if (inStockList.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFBAE6FD), // Crisp ice blue border
          width: 1.3,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0F9FF), // Glacial ice mist
            Color(0xFFE0F2FE), // Soft frosty blue
            Colors.white,
          ],
          stops: [0.0, 0.35, 0.75],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08), // Cyan ice glow
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle Frosted Light Shimmer Line on Top Edge
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                      end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                      colors: [
                        const Color(0xFFBAE6FD).withValues(alpha: 0.2),
                        const Color(0xFF38BDF8),
                        const Color(0xFFE0F2FE),
                        const Color(0xFFBAE6FD).withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Main Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Premium Header with Animated Chill Badge
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 15, 14, 12),
                child: Row(
                  children: [
                    // Animated 3D Floating Ice Badge
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE0F2FE),
                              Color(0xFFBAE6FD),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF7DD3FC),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🧊',
                          style: TextStyle(fontSize: 21),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Header Titles & Tag
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                'Freezer & Drinks',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 14.0),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFBAE6FD),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('❄️', style: TextStyle(fontSize: 9)),
                                    const SizedBox(width: 2.5),
                                    Text(
                                      '2°C CHILL',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 8.5),
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0369A1), // Deep Cyan
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Chilled drinks & frozen desserts',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF475569),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Items Counter Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${inStockList.length}',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 11),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'items',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 10),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 8.5,
                            color: Color(0xFF0284C7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Edge-to-edge Horizontal Shelf
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  height: Responsive.productShelfHeight(context),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: inStockList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final p = inStockList[idx];
                      final cardWidth = Responsive.productCardShelfWidth(context);
                      return SizedBox(
                        width: cardWidth,
                        child: ProductCard(
                          product: p,
                          width: cardWidth,
                          isCompact: false,
                          showOutlet: false,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              FadeSlideRoute(page: ProductDetailScreen(product: p)),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
