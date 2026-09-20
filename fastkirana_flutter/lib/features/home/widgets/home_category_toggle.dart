import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeCategoryToggle extends StatefulWidget {
  final bool isGrocerySelected;
  final ValueChanged<bool> onModeChanged;

  const HomeCategoryToggle({
    super.key,
    required this.isGrocerySelected,
    required this.onModeChanged,
  });

  @override
  State<HomeCategoryToggle> createState() => _HomeCategoryToggleState();
}

class _HomeCategoryToggleState extends State<HomeCategoryToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _toggleNudgeController;
  late final Animation<double> _toggleNudgeAnim;
  late final Animation<double> _toggleGlowAnim;

  // High-contrast vector SVG emojis (Twemoji-style crisp vector paths with clean shadows)
  static const String _grocerySvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000000" flood-opacity="0.3"/>
    </filter>
  </defs>
  <!-- Background Bag (Purple / Teal accent) -->
  <g filter="url(#shadow)">
    <!-- Back shopping bag -->
    <path d="M22 24c0-5.5 4.5-10 10-10s10 4.5 10 10" fill="none" stroke="#FBBF24" stroke-width="4" stroke-linecap="round"/>
    <path d="M16 26h32l-3 34H19L16 26z" fill="#8B5CF6"/>
    <path d="M19 26l3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4" stroke="#7C3AED" stroke-width="1.5" fill="none"/>
    <!-- Front Bright Red/Orange bag -->
    <path d="M34 20c0-6 5-11 11-11s11 5 11 11" fill="none" stroke="#FDE047" stroke-width="4.5" stroke-linecap="round"/>
    <path d="M28 22h34l-3 38H31L28 22z" fill="#EF4444"/>
    <path d="M31 22l3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4 3 4 3-4" stroke="#DC2626" stroke-width="1.5" fill="none"/>
    <!-- Fresh greens sticking out -->
    <path d="M42 12c-2-4 1-8 6-7 4 1 5 6 2 9-2 2-6 1-8-2z" fill="#22C55E"/>
    <path d="M48 9c1-3 5-4 7-1 2 2 1 6-2 7-3 1-5-3-5-6z" fill="#4ADE80"/>
    <!-- White contrast badge/sparkle -->
    <circle cx="58" cy="18" r="3" fill="#FFFFFF"/>
    <circle cx="26" cy="36" r="2.5" fill="#F87171"/>
  </g>
</svg>
''';

  static const String _burgerSvg = '''
<svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="burgerShadow" x="-10%" y="-10%" width="130%" height="130%">
      <feDropShadow dx="0" dy="2.5" stdDeviation="2.5" flood-color="#000000" flood-opacity="0.25"/>
    </filter>
  </defs>
  <g filter="url(#burgerShadow)">
    <!-- Top Bun -->
    <path d="M12 36c0-13.25 10.75-24 24-24s24 10.75 24 24H12z" fill="#F59E0B"/>
    <path d="M16 34c2-9 10-17 20-17s18 8 20 17H16z" fill="#FBBF24" opacity="0.35"/>
    <!-- Sesame Seeds (High Contrast White) -->
    <ellipse cx="26" cy="23" rx="1.8" ry="2.8" transform="rotate(-25 26 23)" fill="#FEF3C7"/>
    <ellipse cx="36" cy="19" rx="1.8" ry="2.8" fill="#FEF3C7"/>
    <ellipse cx="46" cy="24" rx="1.8" ry="2.8" transform="rotate(25 46 24)" fill="#FEF3C7"/>
    <ellipse cx="31" cy="28" rx="1.5" ry="2.5" transform="rotate(15 31 28)" fill="#FEF3C7"/>
    <ellipse cx="41" cy="29" rx="1.5" ry="2.5" transform="rotate(-15 41 29)" fill="#FEF3C7"/>
    <!-- Lettuce (Vibrant Green Wavy) -->
    <path d="M10 37c2-1.5 4-1.5 6 0s4 1.5 6 0 4-1.5 6 0 4-1.5 6 0 4-1.5 6 0 4-1.5 6 0 4-1.5 6 0v4H10v-4z" fill="#10B981"/>
    <!-- Tomato Slices (Vibrant Red) -->
    <rect x="13" y="40" width="22" height="4.5" rx="2.2" fill="#EF4444"/>
    <rect x="37" y="40" width="22" height="4.5" rx="2.2" fill="#EF4444"/>
    <!-- Cheese (Melted Golden Yellow) -->
    <path d="M12 43.5h48l-6 7-18-2-18 2-6-7z" fill="#FACC15"/>
    <!-- Patty (Rich Savory Brown) -->
    <rect x="11" y="48" width="50" height="9" rx="4.5" fill="#78350F"/>
    <rect x="14" y="50" width="44" height="2" rx="1" fill="#92400E" opacity="0.6"/>
    <!-- Bottom Bun -->
    <path d="M13 56h46c0 4.5-3.5 8-8 8H21c-4.5 0-8-3.5-8-8z" fill="#F59E0B"/>
    <path d="M16 57h40c0 2-2 4-5 4H21c-3 0-5-2-5-4z" fill="#D97706" opacity="0.3"/>
  </g>
</svg>
''';

  @override
  void initState() {
    super.initState();

    // Rhythmic subtle bounce/glow every 2.4s to guide the customer that this is interactive
    _toggleNudgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _toggleNudgeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 0.96).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.04).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 48, // Resting pause between cycles
      ),
    ]).animate(_toggleNudgeController);

    _toggleGlowAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 50,
      ),
    ]).animate(_toggleNudgeController);
  }

  @override
  void dispose() {
    _toggleNudgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGrocery = widget.isGrocerySelected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: AnimatedBuilder(
        animation: _toggleNudgeController,
        builder: (context, child) {
          final glowVal = _toggleGlowAnim.value;
          final nudgeScale = _toggleNudgeAnim.value;

          return LayoutBuilder(
            builder: (context, constraints) {
              final outerWidth = constraints.maxWidth;
              const outerHeight = 60.0;
              const innerPadding = 4.0;
              final pillWidth = (outerWidth - (innerPadding * 2)) / 2;

              return Container(
                height: outerHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: (isGrocery ? const Color(0xFFE20A22) : const Color(0xFFEA580C))
                          .withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Active Sliding Pill with Glowing Ambient Light ──
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: const Cubic(0.25, 1.0, 0.4, 1.0), // Smooth Apple-like spring
                      left: !isGrocery ? innerPadding : (innerPadding + pillWidth),
                      top: innerPadding,
                      bottom: innerPadding,
                      width: pillWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: !isGrocery
                                ? const [Color(0xFFEA580C), Color(0xFFF97316)]
                                : const [Color(0xFFE20A22), Color(0xFFF43F5E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            // Vibrant Ambient Glow matching reference
                            BoxShadow(
                              color: (!isGrocery ? const Color(0xFFEA580C) : const Color(0xFFE20A22))
                                  .withValues(alpha: 0.45 + (glowVal * 0.1)),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        // Subtle specular top highlight
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            height: 1.5,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Two Tap Targets (Food & Cafe vs Grocery) ──
                    Row(
                      children: [
                        // 1. Food Tab Target (Left - First)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!isGrocery) return;
                              HapticFeedback.mediumImpact();
                              widget.onModeChanged(false);
                            },
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 3D Burger with gentle float animation when inactive
                                      Transform.scale(
                                        scale: isGrocery ? nudgeScale : 1.0,
                                        child: Transform.translate(
                                          offset: Offset(0, isGrocery ? (-2 * glowVal) : 0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.12),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: SvgPicture.string(
                                              _burgerSvg,
                                              width: 32,
                                              height: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      // 2-Line Typography
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w900,
                                              color: !isGrocery
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                              letterSpacing: -0.3,
                                            ),
                                            child: const Text('Food'),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: !isGrocery
                                                  ? Colors.white.withValues(alpha: 0.9)
                                                  : const Color(0xFF94A3B8),
                                              letterSpacing: 1.4,
                                            ),
                                            child: const Text('RESTAURANTS'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 2. Grocery Tab Target (Right - Second)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (isGrocery) return;
                              HapticFeedback.mediumImpact();
                              widget.onModeChanged(true);
                            },
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 3D Grocery Basket with gentle float animation when inactive
                                      Transform.scale(
                                        scale: !isGrocery ? nudgeScale : 1.0,
                                        child: Transform.translate(
                                          offset: Offset(0, !isGrocery ? (-2 * glowVal) : 0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.12),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: SvgPicture.string(
                                              _grocerySvg,
                                              width: 32,
                                              height: 32,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 9),
                                      // 2-Line Typography
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w900,
                                              color: isGrocery
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                              letterSpacing: -0.3,
                                            ),
                                            child: const Text('Grocery'),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 220),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: isGrocery
                                                  ? Colors.white.withValues(alpha: 0.9)
                                                  : const Color(0xFF94A3B8),
                                              letterSpacing: 1.4,
                                            ),
                                            child: const Text('FAST DELIVERY'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
