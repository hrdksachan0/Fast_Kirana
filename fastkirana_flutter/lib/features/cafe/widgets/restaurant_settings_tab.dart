import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/design_system.dart';

/// Restaurant store settings tab (open/closed status, kitchen high rush mode)
class RestaurantSettingsTab extends StatelessWidget {
  final bool isStoreOpen;
  final bool isBusyMode;
  final ValueChanged<bool> onToggleStoreOpen;
  final ValueChanged<bool> onToggleBusyMode;

  const RestaurantSettingsTab({
    super.key,
    required this.isStoreOpen,
    required this.isBusyMode,
    required this.onToggleStoreOpen,
    required this.onToggleBusyMode,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile.adaptive(
          title: Text(
            'Store Open Status',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate900,
            ),
          ),
          subtitle: Text(
            isStoreOpen ? 'Accepting online orders' : 'Closed for online orders',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12),
              color: AppDesignSystem.slate500,
            ),
          ),
          value: isStoreOpen,
          activeTrackColor: AppDesignSystem.success,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            onToggleStoreOpen(val);
          },
        ),
        const Divider(height: 1, color: AppDesignSystem.slate200),
        SwitchListTile.adaptive(
          title: Text(
            'Kitchen Busy / High Rush Mode',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate900,
            ),
          ),
          subtitle: Text(
            'Displays "Kitchen in High Demand" notice on restaurant menu',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12),
              color: AppDesignSystem.slate500,
            ),
          ),
          value: isBusyMode,
          activeTrackColor: AppDesignSystem.warning,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            onToggleBusyMode(val);
          },
        ),
      ],
    );
  }
}
