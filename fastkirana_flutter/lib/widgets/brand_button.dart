import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';

class BrandButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool fullWidth;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? gradientStart;
  final Color? gradientEnd;

  const BrandButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.fullWidth = true,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.gradientStart,
    this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor;
    final effectiveGradient = effectiveBg != null
        ? null
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradientStart ?? AppDesignSystem.primary,
              gradientEnd ?? AppDesignSystem.primaryDark,
            ],
          );

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        decoration: BoxDecoration(
          color: effectiveBg,
          gradient: effectiveGradient,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusMd),
          boxShadow: AppDesignSystem.shadowSm,
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor ?? Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor ?? Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}