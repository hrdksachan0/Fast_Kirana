import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders formatted product price, crossed-out MRP, and savings badge.
class PriceRow extends StatelessWidget {
  final String priceText;
  final String? mrpText;
  final double s;

  const PriceRow({
    super.key,
    required this.priceText,
    this.mrpText,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          priceText,
          style: GoogleFonts.inter(
            fontSize: s * 16.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
            letterSpacing: -0.35,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (mrpText != null) ...[
          SizedBox(width: s * 4.5),
          Flexible(
            child: Text(
              mrpText!,
              style: GoogleFonts.inter(
                fontSize: s * 12.0,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.lineThrough,
                decorationColor: const Color(0xFF6B7280),
                decorationThickness: 1.3,
                color: const Color(0xFF6B7280),
                letterSpacing: -0.1,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
