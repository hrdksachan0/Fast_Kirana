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
    final cityName = nearestHub.city.isNotEmpty ? nearestHub.city : 'Ghatampur';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFBF7),
            Color(0xFFFFFFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFFD5CE),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Prominent Status Pill: UNSERVICEABLE AREA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFDA4AF),
                width: 1.2,
              ),
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
                const SizedBox(width: 7),
                Text(
                  'UNSERVICEABLE AREA • ${distanceKm.toStringAsFixed(1)} KM OUTSIDE ZONE',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFBE123C),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. Emblem Graphic: Gift Box with Location Alert Pin
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer Soft Halo
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFEDD5).withValues(alpha: 0.5),
                ),
              ),
              // Main Radiant Sphere
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A00), Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              // Location Off Badge
              Positioned(
                bottom: 0,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFE11D48),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Headline: Current Location Not Serviceable
          Text(
            'Aapke Area Me Delivery Uplabdh Nahi Hai',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: Responsive.scaledFontSize(context, 19),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate900,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          // 4. Highlight Banner: "Lekin apno ke liye order karein!"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFED7AA), width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎁', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Lekin aap $cityName me apno ke liye order kar sakte hain!',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFC2410C),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 5. Clear Explanatory Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Aapki current location hamare delivery radius se bahar hai. Lekin agar aapka parivar, rishtedar ya dost $cityName me rehte hain, toh aap unke liye fresh kirana aur khana order kar sakte hain!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12),
                fontWeight: FontWeight.w400,
                color: AppDesignSystem.slate600,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 6. Value Proposition Highlights (Chips)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureChip(
                icon: '⚡',
                label: 'Express Delivery',
                bgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
                textColor: const Color(0xFFC2410C),
              ),
              _buildFeatureChip(
                icon: '🥬',
                label: 'Fresh Produce & Food',
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                textColor: const Color(0xFF15803D),
              ),
              _buildFeatureChip(
                icon: '📞',
                label: 'Rider Calls Recipient',
                bgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
                textColor: const Color(0xFF0369A1),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // 7. PRIMARY CTA: Order for Loved Ones in Ghatampur (1-Tap Switch)
          Bounceable(
            onTap: () {
              UnserviceableLocationBanner.resetToActiveHub(
                ref,
                context,
                isOrderForSomeone: true,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFEA580C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Order for Someone in $cityName',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 8. SECONDARY CTA: Change Location
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
                    Icons.edit_location_alt_rounded,
                    color: Color(0xFF0F172A),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Change Delivery Location',
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

          const SizedBox(height: 14),

          // 9. TERTIARY / WAITLIST: Notify when available here
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              HubWaitlistSheet.show(
                context,
                hubName: '$cityName Outskirts (${distanceKm.toStringAsFixed(1)}km away)',
                areaName: 'Outside Delivery Zone',
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
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Want delivery at your current location? Notify me on WhatsApp',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w600,
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

  Widget _buildFeatureChip({
    required String icon,
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
