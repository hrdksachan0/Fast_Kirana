import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';

class DeliveryInstructionPreset {
  final String id;
  final String icon;
  final String title;
  final String subtitle;

  const DeliveryInstructionPreset({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class CheckoutDeliveryInstructions extends StatelessWidget {
  final Set<String> selectedInstructions;
  final ValueChanged<String> onToggleInstruction;
  final TextEditingController noteController;

  static const List<DeliveryInstructionPreset> presets = [
    DeliveryInstructionPreset(
      id: 'avoid_calling',
      icon: '🔕',
      title: 'Avoid calling',
      subtitle: 'Rider won\'t call unless necessary',
    ),
    DeliveryInstructionPreset(
      id: 'ring_bell',
      icon: '🔔',
      title: 'Ring bell',
      subtitle: 'Ring doorbell upon arrival',
    ),
    DeliveryInstructionPreset(
      id: 'leave_at_door',
      icon: '🚪',
      title: 'Leave at door',
      subtitle: 'Drop parcel safely at doorstep',
    ),
    DeliveryInstructionPreset(
      id: 'leave_with_guard',
      icon: '👮',
      title: 'Leave with guard',
      subtitle: 'Leave with main gate / security',
    ),
    DeliveryInstructionPreset(
      id: 'pet_at_home',
      icon: '🐾',
      title: 'Pet at home',
      subtitle: 'Friendly / cautious pet warning',
    ),
    DeliveryInstructionPreset(
      id: 'baby_sleeping',
      icon: '👶',
      title: 'Baby sleeping',
      subtitle: 'Please do not knock loudly',
    ),
  ];

  const CheckoutDeliveryInstructions({
    super.key,
    required this.selectedInstructions,
    required this.onToggleInstruction,
    required this.noteController,
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Instructions',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                      ),
                    ),
                    Text(
                      'Rider will strictly follow these delivery preferences',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10.5),
                        fontWeight: FontWeight.w500,
                        color: slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets Grid / Wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              final isSelected = selectedInstructions.contains(preset.id);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleInstruction(preset.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3B82F6) : AppDesignSystem.slate200,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(preset.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        preset.title,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11.5),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF1D4ED8) : AppDesignSystem.slate700,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: Color(0xFF3B82F6),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Custom rider note text field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppDesignSystem.slate200),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 18, color: AppDesignSystem.slate400),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: noteController,
                    maxLines: 1,
                    maxLength: 80,
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11.5),
                      fontWeight: FontWeight.w600,
                      color: slateDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add note for rider (e.g. 2nd floor, red gate)',
                      hintStyle: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        color: AppDesignSystem.slate400,
                      ),
                      counterText: '',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
