import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class CheckoutPackagingSelector extends StatelessWidget {
  final String selectedPackaging;
  final ValueChanged<String> onPackagingChanged;

  const CheckoutPackagingSelector({
    super.key,
    required this.selectedPackaging,
    required this.onPackagingChanged,
  });

  @override
  Widget build(BuildContext context) {
    const slateDark = AppDesignSystem.slate900;
    const slateMuted = AppDesignSystem.slate500;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppDesignSystem.statusDelivered,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('🛍️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
              ),
              const SizedBox(width: 8),
              Text(
                'Packaging Preference',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13.5),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Option 1: Normal Packaging
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPackagingChanged('NORMAL');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: selectedPackaging == 'NORMAL' ? AppDesignSystem.green50 : AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedPackaging == 'NORMAL' ? AppDesignSystem.green700 : AppDesignSystem.slate300,
                  width: selectedPackaging == 'NORMAL' ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selectedPackaging == 'NORMAL' ? AppDesignSystem.green700 : Colors.white,
                      border: Border.all(
                        color: selectedPackaging == 'NORMAL' ? AppDesignSystem.green700 : AppDesignSystem.slate500,
                        width: 1.5,
                      ),
                    ),
                    child: selectedPackaging == 'NORMAL'
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Standard Packaging',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12.5),
                            fontWeight: FontWeight.w800,
                            color: slateDark,
                          ),
                        ),
                        Text(
                          'Eco-friendly containers & tamper-proof bag',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusDelivered,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '₹5',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.emerald600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Option 2: Premium Thermal Packaging (+₹15)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPackagingChanged('PREMIUM');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: selectedPackaging == 'PREMIUM' ? AppDesignSystem.amber50 : AppDesignSystem.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedPackaging == 'PREMIUM' ? AppDesignSystem.warning : AppDesignSystem.slate300,
                  width: selectedPackaging == 'PREMIUM' ? 1.4 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selectedPackaging == 'PREMIUM' ? AppDesignSystem.warning : Colors.white,
                      border: Border.all(
                        color: selectedPackaging == 'PREMIUM' ? AppDesignSystem.warning : AppDesignSystem.slate500,
                        width: 1.5,
                      ),
                    ),
                    child: selectedPackaging == 'PREMIUM'
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Premium Thermal Packaging',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                fontWeight: FontWeight.w800,
                                color: slateDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('✨', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 11))),
                          ],
                        ),
                        Text(
                          'Insulated thermal pouch + spill-proof packaging',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.statusPending,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '₹15',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.amber600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
