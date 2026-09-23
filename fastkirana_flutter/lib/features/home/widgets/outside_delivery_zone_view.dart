import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/store_hub.dart';
import '../../../widgets/unserviceable_location_banner.dart';
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFECDD3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Radar Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDA4AF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE11D48),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'OUTSIDE DELIVERY ZONE',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFBE123C),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Map Pin Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECDD3), width: 2),
            ),
            child: const Center(
              child: Icon(Icons.wrong_location_rounded, size: 36, color: Color(0xFFE11D48)),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Headline
          Text(
            'We Are Not Available Here Yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 18),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.slate900,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          // 4. Distance to Nearest Hub Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Nearest Hub: ${nearestHub.city} (${distanceKm.toStringAsFixed(1)} km away)',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11.5),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 5. Explanatory Body
          Text(
            'FastKirana currently operates rapid 10-15 minute grocery and food delivery within 5.0 km of our active dark stores in Ghatampur and Akbarpur.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.slate600,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 22),

          // 6. Action 1: Request Delivery in My Area (Notify Me)
          Bounceable(
            onTap: () {
              HapticFeedback.mediumImpact();
              HubWaitlistSheet.show(
                context,
                hubName: '${nearestHub.city} Outskirts (${distanceKm.toStringAsFixed(1)}km away)',
                areaName: 'Outside Delivery Zone',
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF25D366).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Request FastKirana in My Area',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 7. Action 2: Change Location
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
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Change Delivery Location',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 8. Action 3: Browse Nearest Hub (Secondary)
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              UnserviceableLocationBanner.resetToActiveHub(ref, context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  'Switch to ${nearestHub.city} Hub (Browse Mode)',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12.5),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
