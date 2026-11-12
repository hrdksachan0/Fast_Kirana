import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GiftingTrustStrip extends StatelessWidget {
  const GiftingTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3D5DE), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPill('⚡', '10-Min Fast', 'Delivery'),
          Container(width: 1, height: 22, color: const Color(0xFFEBC1CC)),
          _buildPill('💌', 'Free Handwritten', 'Card Inside'),
          Container(width: 1, height: 22, color: const Color(0xFFEBC1CC)),
          _buildPill('🎀', 'Luxury Satin', 'Gift Packing'),
        ],
      ),
    );
  }

  Widget _buildPill(String emoji, String title, String subtitle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3D0C18),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF824F5C),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
