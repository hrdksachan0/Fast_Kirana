import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Modal bottom sheet allowing Admin users to switch between multiple restaurant outlets
class RestaurantOutletSwitcherModal {
  static void show({
    required BuildContext context,
    required List<Map<String, String>> availableOutlets,
    required String? assignedRestaurantId,
    required void Function(Map<String, String> selectedOutlet) onOutletSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switch Restaurant Console',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 17),
                  fontWeight: FontWeight.w900,
                  color: AppDesignSystem.slate900,
                ),
              ),
              Text(
                'View orders and menu catalog for selected food outlet:',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  color: AppDesignSystem.slate500,
                ),
              ),
              const SizedBox(height: 16),
              ...availableOutlets.map((outlet) {
                final isSelected = assignedRestaurantId == outlet['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? AppDesignSystem.primary : AppDesignSystem.slate200,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    tileColor: isSelected ? AppDesignSystem.rose50 : AppDesignSystem.slate50,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppDesignSystem.primary : AppDesignSystem.slate200,
                        shape: BoxShape.circle,
                      ),
                      child: Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
                    ),
                    title: Text(
                      outlet['name'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppDesignSystem.primary : AppDesignSystem.slate900,
                      ),
                    ),
                    subtitle: Text(
                      'FastKirana Food Kitchen · Live Outlet',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppDesignSystem.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onOutletSelected(outlet);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
