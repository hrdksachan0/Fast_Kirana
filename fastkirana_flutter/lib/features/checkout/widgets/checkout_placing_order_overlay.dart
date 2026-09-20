import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// Full-Screen Smooth Loading Overlay during Order Placement
class CheckoutPlacingOrderOverlay extends StatelessWidget {
  const CheckoutPlacingOrderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppDesignSystem.green100,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppDesignSystem.emerald200, width: 2),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      color: AppDesignSystem.green600,
                      strokeWidth: 3.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Placing Your Order...',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Connecting to FastKirana Darkstore...',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
