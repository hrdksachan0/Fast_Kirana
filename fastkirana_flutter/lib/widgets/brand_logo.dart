import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';

/// Premium Branded Logo using brand image asset with elegant icon+text fallback
class BrandLogo extends StatelessWidget {
  final double size;
  final bool withText;
  final bool variant; // true = dark, false = light
  final bool useImageLogo;

  const BrandLogo({
    super.key,
    this.size = 40,
    this.withText = true,
    this.variant = false,
    this.useImageLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = variant ? AppDesignSystem.textPrimary : Colors.white;

    if (useImageLogo) {
      return Image.asset(
        'assets/brand/fastkirana_exact_logo.png',
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/brand/fastkirana_app_icon.png',
            height: size,
            width: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildFallbackLogo(textColor);
            },
          );
        },
      );
    }

    return _buildFallbackLogo(textColor);
  }

  Widget _buildFallbackLogo(Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppDesignSystem.primary, AppDesignSystem.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.225),
            boxShadow: AppDesignSystem.shadowCard,
          ),
          child: Center(
            child: Icon(
              Icons.shopping_basket_rounded,
              color: Colors.white,
              size: size * 0.55,
            ),
          ),
        ),
        if (withText) ...[
          SizedBox(width: size * 0.25),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fast',
                    style: GoogleFonts.inter(
                      fontSize: size * 0.55,
                      fontWeight: FontWeight.w900,
                      color: AppDesignSystem.primary,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Kirana',
                    style: GoogleFonts.inter(
                      fontSize: size * 0.55,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Grocery & Food',
                style: GoogleFonts.inter(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.textSecondary,
                  height: 1,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}