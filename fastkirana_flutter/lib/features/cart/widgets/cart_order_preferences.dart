import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

/// Interactive Delivery Instruction Tags
class CartDeliveryInstructions extends StatelessWidget {
  final Set<String> selectedInstructions;
  final ValueChanged<String> onToggleInstruction;

  const CartDeliveryInstructions({
    super.key,
    required this.selectedInstructions,
    required this.onToggleInstruction,
  });

  static const List<Map<String, String>> _instructions = [
    {'label': 'Leave at door', 'icon': '🚪'},
    {'label': 'Don\'t ring bell', 'icon': '🔕'},
    {'label': 'Avoid calling', 'icon': '📞'},
    {'label': 'Pet at home', 'icon': '🐾'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
              const SizedBox(width: 6),
              Text(
                'Delivery Instructions',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w800,
                  color: AppDesignSystem.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _instructions.map((item) {
                final label = item['label']!;
                final isSelected = selectedInstructions.contains(label);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggleInstruction(label);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppDesignSystem.primary : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.3 : 1.1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppDesignSystem.primary.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item['icon']!, style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppDesignSystem.primary : const Color(0xFF334155),
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Delivery Partner Tip Selector (₹10, ₹20, ₹30, ₹50)
class CartTipSelector extends StatelessWidget {
  final int selectedTip;
  final ValueChanged<int> onTipSelected;

  const CartTipSelector({
    super.key,
    required this.selectedTip,
    required this.onTipSelected,
  });

  static const List<int> _tips = [10, 20, 30, 50];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('💖', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tip your delivery partner',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '100% goes to partner',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10),
                  fontWeight: FontWeight.w600,
                  color: AppDesignSystem.green600,
                ),
                maxLines: 1,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _tips.map((tip) {
              final isSelected = selectedTip == tip;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTipSelected(isSelected ? 0 : tip);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.3 : 1.1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '₹$tip',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w800,
                          color: isSelected ? const Color(0xFF15803D) : const Color(0xFF334155),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// 100% Quality & Cancellation Policy Card
class CartCancellationPolicy extends StatelessWidget {
  const CartCancellationPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignSystem.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignSystem.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppDesignSystem.slate500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '100% Quality & Replacement Guarantee. Orders cannot be cancelled once packed by store.',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                color: AppDesignSystem.slate500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
