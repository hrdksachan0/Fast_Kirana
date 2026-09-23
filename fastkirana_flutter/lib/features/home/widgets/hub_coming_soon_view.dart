import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../data/models/store_hub.dart';
import '../../location/delivery_location_screen.dart';
import 'hub_waitlist_sheet.dart';

class HubComingSoonView extends ConsumerWidget {
  final StoreHub hub;
  const HubComingSoonView({super.key, required this.hub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityName = hub.city.isNotEmpty ? hub.city : hub.name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Launching Soon Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚀', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'LAUNCHING SOON IN YOUR AREA',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFEA580C),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Big Animated Hub Graphic
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFED7AA), width: 2),
            ),
            child: const Center(
              child: Text('🏬', style: TextStyle(fontSize: 36)),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Headline
          Text(
            'FastKirana is Coming Soon to $cityName!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 18),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.slate900,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          // 4. Subtitle Description
          Text(
            'We are setting up our local darkstore inventory and onboarding authentic neighborhood restaurants. 10-15 minute grocery & meal delivery will be live in $cityName very soon!',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12.5),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.slate600,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          // 5. Feature Highlights
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeaturePill(context, '⚡ 10-15 Min Delivery'),
              _buildFeaturePill(context, '🥬 Farm-Fresh Produce'),
              _buildFeaturePill(context, '🍲 Top Local Kitchens'),
              _buildFeaturePill(context, '💰 Zero Markups'),
            ],
          ),

          const SizedBox(height: 22),

          // 6. Primary Action: Notify Me on WhatsApp
          Bounceable(
            onTap: () {
              HapticFeedback.mediumImpact();
              HubWaitlistSheet.show(
                context,
                hubName: hub.name,
                areaName: hub.city,
                latitude: hub.latitude,
                longitude: hub.longitude,
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
                    'Notify Me on WhatsApp When Live',
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

          // 7. Secondary Action: Change Location
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
                color: AppDesignSystem.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_rounded, color: AppDesignSystem.slate700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Select Another Delivery Location',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.slate800,
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

  Widget _buildFeaturePill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: Responsive.scaledFontSize(context, 11),
          fontWeight: FontWeight.w700,
          color: AppDesignSystem.slate700,
        ),
      ),
    );
  }
}
