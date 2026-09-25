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
          color: const Color(0xFFFFEAD8),
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
          // 1. Top Launching Soon Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFDBA74).withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  size: 14,
                  color: Color(0xFFEA580C),
                ),
                const SizedBox(width: 7),
                Text(
                  'LAUNCHING SOON IN YOUR AREA',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC2410C),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Multi-layered Animated Emblem Graphic
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
                    colors: [Color(0xFFFF7A00), Color(0xFFE20A22)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE20A22).withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              // Floating Sparkle Badge
              Positioned(
                bottom: 0,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFF59E0B),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 3. Headline
          Text(
            'FastKirana is Coming Soon to $cityName!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: Responsive.scaledFontSize(context, 20),
              fontWeight: FontWeight.w800,
              color: AppDesignSystem.slate900,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          // 4. Subtitle (Timing removed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'We are setting up our local darkstores and onboarding your favorite neighborhood kitchens. Fresh groceries, essentials, and meals will be live in $cityName very soon!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w400,
                color: AppDesignSystem.slate600,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 5. Value Proposition Highlights (Timing-free aesthetic chips)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildFeatureChip(
                icon: '🥬',
                label: 'Farm-Fresh Produce',
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                textColor: const Color(0xFF15803D),
              ),
              _buildFeatureChip(
                icon: '🍲',
                label: 'Top Local Kitchens',
                bgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
                textColor: const Color(0xFFC2410C),
              ),
              _buildFeatureChip(
                icon: '🛍️',
                label: 'Daily Essentials',
                bgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
                textColor: const Color(0xFF0369A1),
              ),
              _buildFeatureChip(
                icon: '💰',
                label: 'Direct Store Prices',
                bgColor: const Color(0xFFFEFCE8),
                borderColor: const Color(0xFFFEF08A),
                textColor: const Color(0xFF854D0E),
              ),
            ],
          ),

          const SizedBox(height: 24),

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
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Notify Me on WhatsApp When Live',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13.5),
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppDesignSystem.slate700,
                    size: 17,
                  ),
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
