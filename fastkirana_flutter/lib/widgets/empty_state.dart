import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../core/theme/design_system.dart';

/// A beautifully designed, reusable empty state widget.
///
/// Usage:
/// ```dart
/// EmptyState(
///   emoji: '🛒',
///   title: 'Your cart is empty',
///   subtitle: 'Looks like you haven\'t added anything yet.\nStart shopping now!',
///   ctaLabel: 'Start Shopping',
///   onCta: () => Navigator.pop(context),
/// )
/// ```
///
/// Or without a CTA:
/// ```dart
/// EmptyState(
///   emoji: '📭',
///   title: 'No messages',
///   subtitle: 'We\'ll notify you when something arrives.',
/// )
/// ```
class EmptyState extends StatelessWidget {
  /// The large emoji / illustration shown in the center
  final String emoji;

  /// Bold heading text
  final String title;

  /// Subtitle / description (supports \\n for multiline)
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

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
    this.secondaryLabel,
    this.onSecondary,
    this.bgTint,
  });

  @override
  Widget build(BuildContext context) {
    final tint = bgTint ?? AppDesignSystem.surfaceMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Decorative animated emoji circle ─────────────────────
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tint,
                    tint.withValues(alpha: 0.5),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 62),
                ),
              ),
            )
                .animate()
                .scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                )
                .fadeIn(duration: 500.ms, curve: Curves.easeOut),

            const SizedBox(height: 28),

            // ── Title ─────────────────────────────────────────────
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.textPrimary,
                letterSpacing: -0.3,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 150.ms, curve: Curves.easeOut)
                .slideY(begin: 0.15, duration: 500.ms, delay: 150.ms, curve: Curves.easeOut),

            const SizedBox(height: 10),

            // ── Subtitle ──────────────────────────────────────────
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppDesignSystem.textSecondary,
                height: 1.55,
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 250.ms, curve: Curves.easeOut)
                .slideY(begin: 0.1, duration: 500.ms, delay: 250.ms, curve: Curves.easeOut),

            // ── CTA Button(s) ─────────────────────────────────────
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 32),
              Bounceable(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCta!();
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppDesignSystem.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      ctaLabel!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 350.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.2, duration: 400.ms, delay: 350.ms, curve: Curves.easeOut),
            ],

            // ── Secondary text link ──────────────────────────────
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onSecondary!();
                },
                child: Text(
                  secondaryLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppDesignSystem.primary,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 420.ms, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }
}
