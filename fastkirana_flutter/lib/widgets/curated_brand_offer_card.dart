import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/card_color_palette.dart';
import '../data/models/brand_offer_card_data.dart';
import 'card_media_widget.dart';

/// Ultra-Premium, Agency-Grade Category & Outlet Offer Card
/// Double-Bezel Hardware Architecture, Atmospheric Radial Glows,
/// Button-in-Button CTAs, and Concentric Squircles.
class CategoryOfferCard extends StatefulWidget {
  final String cardType;
  final String discountTitle;
  final String subtitle;
  final String? eyebrowTag;
  final String? categoryName;
  final String? outletName;
  final String? imageUrl;
  final String? videoUrl;
  final String? imageAsset;
  final String? cashbackTitle;
  final String? cashbackSubtitle;
  final String? disclaimerText;
  final Color? backgroundColor;
  final List<Color>? gradientColors;
  final String? ctaText;
  final String? ctaUrl;
  final Color? ctaBgColor;
  final Color? ctaTextColor;
  final List<String>? gridImages;
  final List<String>? gridTitles;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const CategoryOfferCard({
    super.key,
    this.cardType = 'standard',
    required this.discountTitle,
    required this.subtitle,
    this.eyebrowTag,
    this.categoryName,
    this.outletName,
    this.imageUrl,
    this.videoUrl,
    this.imageAsset,
    this.cashbackTitle,
    this.cashbackSubtitle,
    this.disclaimerText,
    this.backgroundColor,
    this.gradientColors,
    this.ctaText,
    this.ctaUrl,
    this.ctaBgColor,
    this.ctaTextColor,
    this.gridImages,
    this.gridTitles,
    this.width = 265.0,
    this.height = 390.0,
    this.onTap,
  });

  /// Factory constructor to build card directly from a dynamic [CategoryCardData] model
  factory CategoryOfferCard.fromData(
    CategoryCardData data, {
    double width = 265.0,
    double height = 390.0,
    VoidCallback? onTap,
  }) {
    Color? bg;
    if (data.backgroundColorHex != null && data.backgroundColorHex!.trim().isNotEmpty) {
      try {
        final hex = data.backgroundColorHex!.trim().replaceFirst('#', '');
        bg = Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
      } catch (_) {}
    }

    List<Color>? gradients;
    if (data.gradientColorsHex != null && data.gradientColorsHex!.isNotEmpty) {
      gradients = data.gradientColorsHex!.map((hexStr) {
        try {
          final h = hexStr.trim().replaceFirst('#', '');
          return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
        } catch (_) {
          return bg ?? const Color(0xFFFFFBF5);
        }
      }).toList();
    }

    Color? ctaBg;
    if (data.ctaBgColorHex != null && data.ctaBgColorHex!.trim().isNotEmpty) {
      try {
        final h = data.ctaBgColorHex!.trim().replaceFirst('#', '');
        ctaBg = Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
      } catch (_) {}
    }

    Color? ctaTextCol;
    if (data.ctaTextColorHex != null && data.ctaTextColorHex!.trim().isNotEmpty) {
      try {
        final h = data.ctaTextColorHex!.trim().replaceFirst('#', '');
        ctaTextCol = Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
      } catch (_) {}
    }

    return CategoryOfferCard(
      cardType: data.cardType,
      discountTitle: data.title,
      subtitle: data.subtitle,
      eyebrowTag: data.eyebrowTag,
      categoryName: data.categoryName,
      outletName: data.outletName,
      imageUrl: data.imageUrl,
      videoUrl: data.videoUrl,
      imageAsset: data.imageAsset,
      cashbackTitle: data.cashbackTitle,
      cashbackSubtitle: data.cashbackSubtitle,
      disclaimerText: data.disclaimerText,
      backgroundColor: bg,
      gradientColors: gradients,
      ctaText: data.ctaText,
      ctaUrl: data.ctaUrl,
      ctaBgColor: ctaBg,
      ctaTextColor: ctaTextCol,
      gridImages: data.gridImages,
      gridTitles: data.gridTitles,
      width: width,
      height: height,
      onTap: onTap,
    );
  }

  @override
  State<CategoryOfferCard> createState() => _CategoryOfferCardState();
}

class _CategoryOfferCardState extends State<CategoryOfferCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.965).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  CardColorPalette _resolvePalette() {
    // Priority 1: Explicit admin-set CTA color → derive palette from it
    if (widget.ctaBgColor != null) {
      return CardColorPalette.fromAccentColor(widget.ctaBgColor!);
    }
    // Priority 2: Keyword-based palette resolution
    return CardColorPalette.fromKeywords(
      widget.discountTitle,
      widget.categoryName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette();
    final glowColor = palette.accent;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        child: Container(
          width: widget.width,
          height: widget.height,
          // ─── 1. Outer Doppelrand / Light Double-Bezel Architecture ───
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.accent.withOpacity(0.25),
                palette.accent.withOpacity(0.08),
                Colors.black.withOpacity(0.04),
                palette.accent.withOpacity(0.12),
              ],
              stops: const [0.0, 0.40, 0.75, 1.0],
            ),
            boxShadow: [
              // Soft warm diffused ambient shadow
              BoxShadow(
                color: palette.accent.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              // Crisp elevation lift shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            // ─── 2. Inner Concentric Core ───
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26.5),
              color: widget.backgroundColor ?? palette.surface,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26.5),
              child: _buildCardContent(context, glowColor, palette),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, Color glowColor, CardColorPalette palette) {
    final hasMedia = (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) ||
        (widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty) ||
        (widget.imageAsset != null && widget.imageAsset!.trim().isNotEmpty);

    final fmt = widget.cardType;

    // Pure media card: when cardType is 'media', 'pure_media', or 'standard' with media,
    // or when the card has media and title is empty/default.
    if (fmt == 'media' || fmt == 'pure_media' || (fmt == 'standard' && hasMedia)) {
      return _buildPureMediaCard(context);
    }
    if (fmt == 'hero' || fmt == 'dark_showcase') {
      return _buildHeroCard(context, glowColor, palette);
    } else if (fmt == 'bento_grid') {
      return _buildBentoGridCard(context, glowColor, palette);
    } else if (fmt == 'editorial') {
      return _buildEditorialCard(context, glowColor, palette);
    }
    if (hasMedia) {
      return _buildPureMediaCard(context);
    }
    return _buildStandardCard(context, glowColor, palette);
  }

  /// ─── 0. PURE FULL-BLEED PHOTO & VIDEO CARD (Zero text, zero coupons, pure media) ───
  Widget _buildPureMediaCard(BuildContext context) {
    return SizedBox.expand(
      child: CardMediaWidget(
        imageUrl: widget.imageUrl,
        videoUrl: widget.videoUrl,
        imageAsset: widget.imageAsset,
        fit: BoxFit.cover,
        borderRadius: 26.5,
        showLiveBadge: false, // Pure photo/video: NO BADGES, NO TEXT
      ),
    );
  }

  // ===========================================================================
  // 1. AESTHETIC CATEGORY HERO CARD (Food & Grocery Spotlight)
  // ===========================================================================
  Widget _buildHeroCard(BuildContext context, Color glowColor, CardColorPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.gradientColors ?? palette.gradient,
        ),
      ),
      child: Stack(
        children: [
          // ─── Dual-Stage Radial Ambient Glow ───
          Positioned(
            top: widget.height * 0.22,
            right: -30,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.glowCenter,
                    palette.glowMid,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.50, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ─── Header: Eyebrow Capsule + Title + Subtitle + Outlet Pill ───
          Positioned(
            top: 18,
            left: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.eyebrowTag != null && widget.eyebrowTag!.trim().isNotEmpty) ...[
                  _buildMicroEyebrowPill(glowColor),
                  const SizedBox(height: 6),
                ],
                Text(
                  widget.discountTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22.5,
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                    letterSpacing: -0.7,
                    height: 1.12,
                  ),
                ),
                if (widget.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: palette.textSecondary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
                if (widget.categoryName != null && widget.categoryName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCategoryTagPill(glowColor),
                ],
              ],
            ),
          ),

          // ─── Center Hero Visual with Floor Contact Shadow ───
          Positioned(
            left: 10,
            right: 10,
            bottom: widget.ctaText != null ? 70 : 42,
            height: 180,
            child: _buildHeroVisualWithShadow(),
          ),

          // ─── Bottom Nested "Button-in-Button" Island CTA ───
          if (widget.ctaText != null && widget.ctaText!.trim().isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _buildIslandCtaButton(glowColor),
            ),

          // ─── Bottom Disclaimer ───
          if ((widget.ctaText == null || widget.ctaText!.trim().isEmpty) &&
              widget.disclaimerText != null &&
              widget.disclaimerText!.trim().isNotEmpty)
            Positioned(
              left: 18,
              right: 18,
              bottom: 14,
              child: Text(
                widget.disclaimerText!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: palette.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMicroEyebrowPill(Color glowColor) {
    return Container(
      constraints: BoxConstraints(maxWidth: widget.width - 36),
      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: glowColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glowColor.withOpacity(0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glowColor,
              boxShadow: [
                BoxShadow(color: glowColor, blurRadius: 4, spreadRadius: 0.5),
              ],
            ),
          ),
          const SizedBox(width: 5.5),
          Flexible(
            child: Text(
              widget.eyebrowTag!.trim().toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: glowColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTagPill(Color glowColor) {
    final cat = widget.categoryName!.trim();
    final outlet = widget.outletName?.trim();

    return Container(
      constraints: BoxConstraints(maxWidth: widget.width - 36),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              cat.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (outlet != null && outlet.isNotEmpty) ...[
            Text(
              ' • ',
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
            ),
            Flexible(
              child: Text(
                outlet.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroVisualWithShadow() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft Floor Contact Shadow
        Positioned(
          bottom: 4,
          child: Container(
            width: 140,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        // Cutout Food / Produce Image
        Positioned.fill(
          child: _buildHeroVisual(),
        ),
      ],
    );
  }

  Widget _buildHeroVisual() {
    return CardMediaWidget(
      imageUrl: widget.imageUrl,
      videoUrl: widget.videoUrl,
      imageAsset: widget.imageAsset,
      borderRadius: 18.0,
      fit: BoxFit.cover,
      showLiveBadge: true,
      fallback: _buildFallbackVisual(),
    );
  }

  Widget _buildFallbackVisual() {
    return const SizedBox.shrink();
  }

  /// Nested "Button-in-Button" Island Architecture (Elite Agency Spec)
  Widget _buildIslandCtaButton(Color glowColor) {
    final bgColor = widget.ctaBgColor ?? glowColor;
    final textColor = widget.ctaTextColor ?? Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.40),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.ctaText!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nested circular trailing icon pill
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.24),
            ),
            child: Center(
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. 2x2 CATEGORY BENTO GRID CARD
  // ===========================================================================
  Widget _buildBentoGridCard(BuildContext context, Color glowColor, CardColorPalette palette) {
    final gradient = widget.gradientColors != null && widget.gradientColors!.length >= 2
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.gradientColors!,
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.gradient,
          );

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        gradient: gradient,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.eyebrowTag != null && widget.eyebrowTag!.trim().isNotEmpty) ...[
              _buildMicroEyebrowPill(glowColor),
              const SizedBox(height: 5),
            ],
            Text(
              widget.discountTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20.5,
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
                letterSpacing: -0.6,
                height: 1.14,
              ),
            ),
            if (widget.subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Accent Pill CTA Button (uses palette accent instead of hardcoded amber)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: widget.ctaBgColor ?? glowColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (widget.ctaBgColor ?? glowColor).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.ctaText ?? 'EXPLORE ALL',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.ctaTextColor ?? Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 11,
                    color: widget.ctaTextColor ?? Colors.white,
                  ),
                ],
              ),
            ),
            const Spacer(),

            // 2x2 Bento Tiles with Concentric Squircles
            _buildBentoTiles2x2(),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoTiles2x2() {
    final images = widget.gridImages ?? [];
    return SizedBox(
      height: 188,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildBentoTile(images.isNotEmpty ? images[0] : null, 0)),
                const SizedBox(width: 8),
                Expanded(child: _buildBentoTile(images.length > 1 ? images[1] : null, 1)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildBentoTile(images.length > 2 ? images[2] : null, 2)),
                const SizedBox(width: 8),
                Expanded(child: _buildBentoTile(images.length > 3 ? images[3] : null, 3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoTile(String? customImg, int slotIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1.0),
      ),
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: customImg != null && customImg.startsWith('http')
              ? CachedNetworkImage(
                  imageUrl: customImg,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) => const Center(
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ),
                  errorWidget: (_, __, ___) => _buildTileFallbackVisual(slotIndex),
                )
              : _buildTileFallbackVisual(slotIndex),
        ),
      ),
    );
  }

  Widget _buildTileFallbackVisual(int slotIndex) {
    final icons = [
      Icons.local_pizza_rounded,
      Icons.lunch_dining_rounded,
      Icons.icecream_rounded,
      Icons.local_cafe_rounded,
    ];
    final colors = [
      const Color(0xFFEA580C),
      const Color(0xFFE11D48),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
    ];

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Icon(
          icons[slotIndex % icons.length],
          size: 30,
          color: colors[slotIndex % colors.length],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. EDITORIAL LUXURY CATEGORY SPOTLIGHT CARD
  // ===========================================================================
  Widget _buildEditorialCard(BuildContext context, Color glowColor, CardColorPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.gradientColors ?? palette.gradient,
        ),
      ),
      child: Stack(
        children: [
          // Ambient Radial Light (palette accent instead of hardcoded amber)
          Positioned(
            top: 40,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glowColor.withOpacity(0.24),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Header: Eyebrow + Title + Subtitle + Category Tag
          Positioned(
            top: 20,
            left: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.eyebrowTag != null && widget.eyebrowTag!.trim().isNotEmpty) ...[
                  _buildMicroEyebrowPill(glowColor),
                  const SizedBox(height: 5),
                ],
                Text(
                  widget.discountTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.syne(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                if (widget.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
                if (widget.categoryName != null && widget.categoryName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.categoryName!.toUpperCase(),
                    style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: glowColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Photographic Hero Visual
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.cashbackTitle != null ? 70 : 40,
            height: 200,
            child: _buildHeroVisualWithShadow(),
          ),

          // Floating Luxury Offer Capsule
          if (widget.cashbackTitle != null && widget.cashbackTitle!.trim().isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              bottom: 20,
              child: _buildLuxuryOfferCapsule(palette),
            ),

          // Bottom Disclaimer
          if (widget.disclaimerText != null && widget.disclaimerText!.trim().isNotEmpty)
            Positioned(
              left: 16,
              bottom: 8,
              child: Text(
                widget.disclaimerText!.trim(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLuxuryOfferCapsule(CardColorPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: palette.capsuleBorder, width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: palette.capsuleIconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.stars_rounded,
              size: 17,
              color: palette.accentDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.cashbackTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (widget.cashbackSubtitle != null && widget.cashbackSubtitle!.trim().isNotEmpty)
                  Text(
                    widget.cashbackSubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. STANDARD MODERN CARD
  // ===========================================================================
  Widget _buildStandardCard(BuildContext context, Color glowColor, CardColorPalette palette) {
    return Container(
      color: widget.backgroundColor,
      child: Stack(
        children: [
          Positioned(
            top: 18,
            left: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.eyebrowTag != null && widget.eyebrowTag!.isNotEmpty)
                  Text(
                    widget.eyebrowTag!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                Text(
                  widget.discountTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 100,
            left: 14,
            right: 14,
            bottom: widget.ctaText != null ? 65 : 20,
            child: _buildHeroVisualWithShadow(),
          ),
          if (widget.ctaText != null && widget.ctaText!.trim().isNotEmpty)
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: _buildIslandCtaButton(glowColor),
            ),
        ],
      ),
    );
  }
}

/// Backward compatibility alias so existing Flutter widgets continue to work cleanly.
typedef CuratedBrandOfferCard = CategoryOfferCard;

/// Horizontal Scrolling Carousel for Dynamic Category Offer Cards
class CategoryOffersCarousel extends StatelessWidget {
  final List<CategoryCardData>? items;
  final List<CategoryOfferCard>? customCards;
  final String? sectionTitle;
  final double cardWidth;
  final double cardHeight;
  final void Function(CategoryCardData item)? onCardTap;
  final VoidCallback? onSeeAll;

  const CategoryOffersCarousel({
    super.key,
    this.items,
    this.customCards,
    this.sectionTitle,
    this.cardWidth = 265.0,
    this.cardHeight = 390.0,
    this.onCardTap,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> cards = [];

    if (customCards != null && customCards!.isNotEmpty) {
      cards = customCards!;
    } else if (items != null && items!.isNotEmpty) {
      cards = items!
          .where((i) => i.isActive)
          .map((data) => CategoryOfferCard.fromData(
                data,
                width: cardWidth,
                height: cardHeight,
                onTap: onCardTap != null ? () => onCardTap!(data) : null,
              ))
          .toList();
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionTitle != null && sectionTitle!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sectionTitle!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Text(
                      'See All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE11D48),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: cardHeight + 8,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) => cards[index],
          ),
        ),
      ],
    );
  }
}

/// Backward compatibility alias
typedef CuratedBrandOffersCarousel = CategoryOffersCarousel;
