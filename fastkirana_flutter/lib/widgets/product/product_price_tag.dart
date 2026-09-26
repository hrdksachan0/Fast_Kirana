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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          priceText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: s * 14.0,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.4,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (mrpText != null)
          Padding(
            padding: EdgeInsets.only(top: s * 1.0),
            child: Text(
              mrpText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: s * 10.0,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.lineThrough,
                decorationColor: const Color(0xFF94A3B8),
                color: const Color(0xFF94A3B8),
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
