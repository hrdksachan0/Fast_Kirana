import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../core/theme/design_system.dart';

/// A beautifully designed, reusable empty state widget with presets.
class EmptyState extends StatelessWidget {
  /// The large emoji shown in the center
  final String emoji;

  /// Optional icon to use instead of emoji
  final IconData? icon;
  final Color? iconColor;

  /// Bold heading text
  final String title;

  /// Subtitle / description (supports \n for multiline)
  final String subtitle;

  /// CTA button label — if null, no button is shown
  final String? ctaLabel;

  /// CTA callback
  final VoidCallback? onCta;

  /// Secondary text button label (e.g. "Browse Categories")
  final String? secondaryLabel;

  /// Secondary callback
  final VoidCallback? onSecondary;

  /// Background tint color for the decorative circle (defaults to surface)
  final Color? bgTint;

  /// Custom CTA button color override (e.g. Orange for Cafe)
  final Color? ctaColor;

  /// Compact mode for inside tabs or nested scroll views
  final bool isCompact;

  const EmptyState({
    super.key,
    required this.emoji,
    this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.secondaryLabel,
    this.onSecondary,
    this.bgTint,
    this.ctaColor,
    this.isCompact = false,
  });

  /// Preset for when no restaurants are open / found
  factory EmptyState.noRestaurants({
    Key? key,
    VoidCallback? onSwitchToGrocery,
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      key: key,
      emoji: '👨‍🍳',
      title: 'No Outlets Currently Open',
      subtitle: 'Partner kitchens deliver from 11:00 AM to 11:00 PM.\nYou can still order snacks, beverages & groceries 24/7!',
      ctaLabel: 'Switch to Grocery Mart',
      onCta: onSwitchToGrocery,
      secondaryLabel: onRetry != null ? 'Refresh Outlets' : null,
      onSecondary: onRetry,
      bgTint: AppDesignSystem.orange50,
      ctaColor: AppDesignSystem.orange600,
    );
  }

  /// Preset for empty product lists / categories
  factory EmptyState.noProducts({
    Key? key,
    String? categoryName,
    VoidCallback? onReset,
    VoidCallback? onExploreAll,
    bool isCompact = false,
  }) {
    return EmptyState(
      key: key,
      emoji: '📦',
      title: categoryName != null ? 'No items in $categoryName' : 'No Products Found',
      subtitle: 'We are restocking fresh inventory right now.\nCheck back in a few minutes or explore popular picks!',
      ctaLabel: onExploreAll != null ? 'Explore All Products' : (onReset != null ? 'Reset Filters' : null),
      onCta: onExploreAll ?? onReset,
      secondaryLabel: onReset != null && onExploreAll != null ? 'Reset Filters' : null,
      onSecondary: onReset,
      bgTint: AppDesignSystem.statusCancelled,
      isCompact: isCompact,
    );
  }

  /// Preset for empty Flash Deals
  factory EmptyState.noDeals({
    Key? key,
    VoidCallback? onExploreTrending,
    bool isCompact = false,
  }) {
    return EmptyState(
      key: key,
      emoji: '⚡',
      title: 'New Flash Deals Drop Soon!',
      subtitle: 'Today\'s lightning discounts sold out super fast.\nNext batch drops at 6:00 PM today!',
      ctaLabel: 'Explore Trending Essentials',
      onCta: onExploreTrending,
      bgTint: AppDesignSystem.statusCancelled,
      isCompact: isCompact,
    );
  }

  /// Preset for empty cart
  factory EmptyState.emptyCart({
    Key? key,
    VoidCallback? onStartShopping,
  }) {
    return EmptyState(
      key: key,
      emoji: '🛒',
      title: 'Your Cart is Empty',
      subtitle: 'Add farm fresh veggies, dairy, snacks & hot meals to start your order!',
      ctaLabel: 'Start Shopping',
      onCta: onStartShopping,
      bgTint: AppDesignSystem.rose50,
    );
  }

  /// Preset for no orders
  factory EmptyState.noOrders({
    Key? key,
    VoidCallback? onStartShopping,
  }) {
    return EmptyState(
      key: key,
      emoji: '🛍️',
      title: 'No Active Orders',
      subtitle: 'Looks like you haven\'t placed any orders yet.\nGet fresh groceries delivered at your doorstep!',
      ctaLabel: 'Order Now',
      onCta: onStartShopping,
      bgTint: AppDesignSystem.green50,
      ctaColor: AppDesignSystem.green600,
    );
  }

  /// Preset for no search results
  factory EmptyState.noSearchResults({
    Key? key,
    required String query,
    VoidCallback? onClear,
  }) {
    return EmptyState(
      key: key,
      emoji: '🔍',
      title: 'No results for "$query"',
      subtitle: 'Check for typos or try searching for generic terms like "milk", "atta", "maggi" or "chips".',
      ctaLabel: onClear != null ? 'Clear Search' : null,
      onCta: onClear,
      bgTint: AppDesignSystem.slate100,
    );
  }

  /// Preset for offline / network errors
  factory EmptyState.offline({
    Key? key,
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      key: key,
      emoji: '📡',
      title: 'Connection Issue',
      subtitle: 'Unable to reach FastKirana servers.\nPlease check your internet connection and retry.',
      ctaLabel: 'Retry',
      onCta: onRetry,
      bgTint: AppDesignSystem.slate50,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tint = bgTint ?? AppDesignSystem.surfaceMuted;
    final buttonColor = ctaColor ?? AppDesignSystem.primary;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20 : 32,
          vertical: isCompact ? 18 : 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Decorative animated emoji/icon circle ─────────────────
            Container(
              width: isCompact ? 86 : 118,
              height: isCompact ? 86 : 118,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint,
                    tint.withValues(alpha: 0.4),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: tint.withValues(alpha: 0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: isCompact ? 38 : 50, color: iconColor ?? buttonColor)
                    : Text(
                        emoji,
                        style: TextStyle(fontSize: isCompact ? 42 : 56),
                      ),
              ),
            )
                .animate()
                .scale(
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1.0, 1.0),
                )
                .fadeIn(duration: 400.ms, curve: Curves.easeOut),

            SizedBox(height: isCompact ? 16 : 22),

            // ── Title ─────────────────────────────────────────────
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 16 : 19,
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.textPrimary,
                letterSpacing: -0.3,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms, curve: Curves.easeOut)
                .slideY(begin: 0.12, duration: 400.ms, delay: 100.ms, curve: Curves.easeOut),

            const SizedBox(height: 8),

            // ── Subtitle ──────────────────────────────────────────
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isCompact ? 12 : 13,
                fontWeight: FontWeight.w500,
                color: AppDesignSystem.textSecondary,
                height: 1.5,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 180.ms, curve: Curves.easeOut)
                .slideY(begin: 0.08, duration: 400.ms, delay: 180.ms, curve: Curves.easeOut),

            // ── CTA Button(s) ─────────────────────────────────────
            if (ctaLabel != null && onCta != null) ...[
              SizedBox(height: isCompact ? 20 : 26),
              Bounceable(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCta!();
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isCompact ? 260 : 320,
                  ),
                  height: isCompact ? 44 : 48,
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: buttonColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        ctaLabel!,
                        style: GoogleFonts.inter(
                          fontSize: isCompact ? 13.5 : 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms, delay: 260.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.15, duration: 350.ms, delay: 260.ms, curve: Curves.easeOut),
            ],

            // ── Secondary text link ──────────────────────────────
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onSecondary!();
                },
                child: Text(
                  secondaryLabel!,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: buttonColor,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms, delay: 320.ms, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }
}
