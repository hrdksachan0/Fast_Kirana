import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';

/// Premium Branded Logo with gradient effect
class BrandLogo extends StatelessWidget {
  final double size;
  final bool withText;
  final bool variant; // true = dark, false = light

  const BrandLogo({
    super.key,
    this.size = 40,
    this.withText = true,
    this.variant = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = variant ? AppDesignSystem.textPrimary : Colors.white;

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
          child: Icon(
            Icons.shopping_basket_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
        if (withText) ...[
          SizedBox(width: size * 0.25),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FastKirana',
                style: GoogleFonts.poppins(
                  fontSize: size * 0.55,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Grocery & Food',
                style: GoogleFonts.poppins(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.7),
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