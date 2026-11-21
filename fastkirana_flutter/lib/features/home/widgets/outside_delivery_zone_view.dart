import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/store_hub.dart';
import '../../../providers/address_provider.dart';
import '../../../widgets/address_selector_sheet.dart';
import '../../location/delivery_location_screen.dart';
import 'hub_waitlist_sheet.dart';

class OutsideDeliveryZoneView extends ConsumerWidget {
  final StoreHub nearestHub;
  final double distanceKm;

  const OutsideDeliveryZoneView({
    super.key,
    required this.nearestHub,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const brandPink = Color(0xFFE11D48); // FastMinute Crimson
    const slateDark = Color(0xFF0F172A);
    const slateMuted = Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Hero Illustration: Delivery Scooter with Binoculars
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft background glow
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6),
                    shape: BoxShape.circle,
                  ),
                ),
                // Icon representation of delivery scout with binoculars
                const Icon(
                  Icons.moped_rounded,
                  size: 58,
                  color: brandPink,
                ),
                Positioned(
                  top: 22,
                  right: 22,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: brandPink,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 2. Headline: Exact user requested copy (No Zepto copy, direct and clear)
          Text(
            'We are not serviceable here yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: Responsive.scaledFontSize(context, 20),
              fontWeight: FontWeight.w900,
              color: slateDark,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          // 3. Subtitle: Clean English, zero time mention, zero Ghatampur hardcode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "We don't deliver here just yet, but we're expanding and will reach you soon.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: Responsive.scaledFontSize(context, 13),
                fontWeight: FontWeight.w500,
                color: slateMuted,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 4. PRIMARY CTA: Change Location (Opens Address Selector Sheet directly)
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              final currentAddress = ref.read(selectedAddressProvider);
              AddressSelectorSheet.show(
                context,
                activeAddress: currentAddress,
                onAddressSelected: (_) {},
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: brandPink,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: brandPink.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Change Location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 14.5),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 5. SECONDARY CTA: Search Colony, Area or Map
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                FadeSlideRoute(page: const DeliveryLocationScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: slateDark,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Search New Delivery Area',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: slateDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 6. Notify when available here
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              HubWaitlistSheet.show(
                context,
                hubName: nearestHub.name,
                areaName: 'Current Location',
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF16A34A),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Notify me when delivery starts here',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                      decoration: TextDecoration.underline,
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
