import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Modal bottom sheet for choosing estimated cooking / prep time when accepting an order
class RestaurantPrepTimeModal {
  static void show({
    required BuildContext context,
    required Map<String, dynamic> order,
    required void Function(int prepMinutes) onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        int selectedTime = 15;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Accept Order & Cooking Time',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 17),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.slate900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppDesignSystem.slate500),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select estimated cooking time to notify customer & rider:',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      color: AppDesignSystem.slate500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [15, 25, 35, 45].map((time) {
                      final isSelected = selectedTime == time;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Bounceable(
                            onTap: () {
                              setModalState(() => selectedTime = time);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? AppDesignSystem.primary : AppDesignSystem.slate100,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppDesignSystem.primary : AppDesignSystem.slate200,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$time',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 18),
                                      fontWeight: FontWeight.w900,
                                      color: isSelected ? Colors.white : AppDesignSystem.slate900,
                                    ),
                                  ),
                                  Text(
                                    'mins',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white.withValues(alpha: 0.9) : AppDesignSystem.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirm(selectedTime);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.success,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Start Cooking ($selectedTime Mins) 🍳',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14.5),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
