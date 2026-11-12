import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';

/// Royal Velvet Wax-Sealed Gift Note & Recipient Envelope Widget
/// Gives customers an interactive preview of their physical gift card,
/// with secret gift mode (hidden price invoice) and wax-seal embossing.
class LuxuryGiftEnvelopeCard extends StatelessWidget {
  final String recipientName;
  final String recipientPhone;
  final String giftNote;
  final bool isSecretGift;
  final ValueChanged<bool> onSecretGiftToggle;
  final VoidCallback onTapEdit;

  const LuxuryGiftEnvelopeCard({
    super.key,
    required this.recipientName,
    required this.recipientPhone,
    required this.giftNote,
    required this.isSecretGift,
    required this.onSecretGiftToggle,
    required this.onTapEdit,
  });

  bool get _hasDetails => recipientName.isNotEmpty || giftNote.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF7F9),
            Color(0xFFFDECEF),
            Color(0xFFFBF0F3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEBC1CC),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B1728).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Top Right Golden Wax Seal Stamp Graphic
            Positioned(
              right: 14,
              top: 14,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFFFDF73),
                      Color(0xFFD4AF37),
                      Color(0xFF8A6D1F),
                    ],
                    center: Alignment(-0.2, -0.2),
                    radius: 0.9,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A6D1F).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFFF1BD),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '💌',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Eyebrow Ribbon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B1728),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              'FREE COMPLIMENTARY GIFT CARD',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: const Color(0xFFFFE082),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Envelope Body / Recipient Note Preview
                  Bounceable(
                    onTap: onTapEdit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF2D3DC),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B1728).withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                recipientName.isNotEmpty
                                    ? 'To: $recipientName 💝'
                                    : 'To: Someone Special 💝',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF4A0E1C),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _hasDetails ? 'EDIT' : '+ ADD NOTE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFBE123C),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 11,
                                    color: Color(0xFFBE123C),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            giftNote.isNotEmpty
                                ? '“$giftNote”'
                                : 'Tap to write a personalized message card. Our partner handwrites it and adds a satin ribbon!',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontStyle: giftNote.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                              fontWeight: giftNote.isNotEmpty ? FontWeight.w600 : FontWeight.w500,
                              color: giftNote.isNotEmpty
                                  ? const Color(0xFF6B1728)
                                  : const Color(0xFF824F5C),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Secret Gift Mode Toggle (Hide Prices on physical package)
                  InkWell(
                    onTap: () => onSecretGiftToggle(!isSecretGift),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSecretGift ? const Color(0xFF16A34A) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSecretGift ? const Color(0xFF16A34A) : const Color(0xFFD4AF37),
                                width: 1.4,
                              ),
                            ),
                            child: isSecretGift
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Secret Surprise Mode',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF4A0E1C),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('🔒', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                Text(
                                  'Price invoice & tags will be removed from delivery box',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF7A4A57),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
