import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../../data/models/store_settings.dart';
import '../../../providers/store_settings_provider.dart';
import '../../../providers/address_provider.dart';

class HomeTrustBadgeStrip extends ConsumerWidget {
  const HomeTrustBadgeStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(storeSettingsProvider);
    final settings = settingsAsync.valueOrNull ?? const StoreSettings();
    final selectedAddress = ref.watch(selectedAddressProvider);
    final rawCity = selectedAddress?.city.isNotEmpty == true
        ? selectedAddress!.city
        : settings.trustBadge1;
    final cityName = rawCity.split(',').first.trim();

    final badge2 = settings.trustBadge2;
    final badge3 = settings.trustBadge3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppDesignSystem.slate200, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. 🟢 ⚡ City Name
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.green600,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.bolt_rounded, size: 16, color: AppDesignSystem.warning),
                const SizedBox(width: 4),
                Text(
                  cityName,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            // Divider
            Container(width: 1, height: 13, color: AppDesignSystem.slate300),

            // 2. 💠 50+ (Verified badge / Varieties)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  size: 15,
                  color: AppDesignSystem.info,
                ),
                const SizedBox(width: 5),
                Text(
                  badge2,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            // Divider
            Container(width: 1, height: 13, color: AppDesignSystem.slate300),

            // 3. 💖 1000+ (Happy Customers / Orders)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 15,
                  color: AppDesignSystem.pink500,
                ),
                const SizedBox(width: 5),
                Text(
                  badge3,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
