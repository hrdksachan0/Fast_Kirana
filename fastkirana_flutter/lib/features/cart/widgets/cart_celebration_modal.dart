import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/design_system.dart';

/// Celebration Modal for BOGO deals and coupon applications
class CartCelebrationModal {
  static void show({
    required BuildContext context,
    required ConfettiController confettiController,
    required String title,
    required String subtitle,
    required String savingsText,
    bool isBogo = false,
  }) {
    HapticFeedback.heavyImpact();
    confettiController.play();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (isBogo ? const Color(0xFFEA580C) : AppDesignSystem.emerald600).withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isBogo ? const Color(0xFFFED7AA) : const Color(0xFFA7F3D0),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration Icon with Glow
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isBogo
                        ? [const Color(0xFFEA580C), const Color(0xFFF97316)]
                        : [AppDesignSystem.emerald600, AppDesignSystem.emerald400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isBogo ? const Color(0xFFEA580C) : AppDesignSystem.emerald600).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isBogo ? '🎁' : '🎉',
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.slate600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // Savings Highlight Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isBogo ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isBogo ? const Color(0xFFFDBA74) : const Color(0xFF6EE7B7),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('✨', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                    const SizedBox(width: 6),
                    Text(
                      savingsText,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w900,
                        color: isBogo ? const Color(0xFFC2410C) : AppDesignSystem.emerald900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBogo ? const Color(0xFFEA580C) : AppDesignSystem.emerald700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Awesome, Let\'s Order! 🚀',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
