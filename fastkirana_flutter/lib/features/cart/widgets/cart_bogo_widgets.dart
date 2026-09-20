import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// BOGO Nudge Alert Banner
class CartBogoNudgeBanner extends StatelessWidget {
  final String nudgeMessage;

  const CartBogoNudgeBanner({
    super.key,
    required this.nudgeMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nudgeMessage,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12),
                fontWeight: FontWeight.w800,
                color: const Color(0xFFC2410C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// BOGO 100% Free Gift Card
class CartBogoFreeGiftCard extends StatelessWidget {
  final Map<String, dynamic> gift;

  const CartBogoFreeGiftCard({
    super.key,
    required this.gift,
  });

  @override
  Widget build(BuildContext context) {
    final name = gift['name']?.toString() ?? 'Free Item';
    final variant = gift['variant']?.toString();
    final originalPrice = (gift['originalPrice'] as num?)?.toDouble() ?? 0.0;
    final message = gift['message']?.toString() ?? '100% Free with BOGO Promotion';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text('🎁', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '100% FREE GIFT',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (variant != null && variant.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Text(
                        '• $variant',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w900,
                    color: AppDesignSystem.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10.5),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (originalPrice > 0)
                Text(
                  '₹${originalPrice.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.slate400,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                'FREE',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF16A34A),
                  letterSpacing: 0.2,
                ),
              ),
              if (originalPrice > 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Saved ₹${originalPrice.toInt()}!',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
