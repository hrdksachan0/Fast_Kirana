import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../core/theme/design_system.dart';
import '../core/services/location_service.dart';
import '../core/config/app_config.dart';
import '../data/models/address.dart';
import '../providers/address_provider.dart';
import '../features/location/delivery_location_screen.dart';
import '../core/routes/page_transitions.dart';

class UnserviceableLocationBanner extends ConsumerWidget {
  const UnserviceableLocationBanner({super.key});

  static void resetToActiveHub(WidgetRef ref, BuildContext context) {
    HapticFeedback.mediumImpact();
    const defaultHub = Address(
      id: 'hub_active_default',
      userId: 'current',
      label: 'FastKirana Active Store Hub',
      houseNo: '',
      street: 'Central Market',
      area: 'Central Zone',
      city: 'Kanpur Nagar',
      pincode: '209206',
      latitude: AppConfig.darkstoreLat,
      longitude: AppConfig.darkstoreLng,
      isDefault: true,
    );

    ref.read(selectedAddressProvider.notifier).state = defaultHub;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16A34A),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Switched to Active Store Hub (10-15 Min Delivery)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showUnserviceableModal(BuildContext context, WidgetRef ref, double distanceKm) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UnserviceableSheetContent(distanceKm: distanceKm),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(deliveryTierProvider);

    // Only render when location is outside the 5.0 km boundary
    if (tier.isServiceable) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF9F1239)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          // Flashing Radar Dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Message
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Outside Delivery Zone (${tier.distanceKm.toStringAsFixed(1)} km away)',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Delivery is not available at your detected location',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Button: Select Serviceable Hub
          Bounceable(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(context, FadeSlideRoute(page: const DeliveryLocationScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'Change Location',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10.5),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFBE123C),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnserviceableSheetContent extends ConsumerStatefulWidget {
  final double distanceKm;
  const _UnserviceableSheetContent({required this.distanceKm});

  @override
  ConsumerState<_UnserviceableSheetContent> createState() => _UnserviceableSheetContentState();
}

class _UnserviceableSheetContentState extends ConsumerState<_UnserviceableSheetContent> {
  final _phoneController = TextEditingController();
  bool _isNotified = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Radar Icon Animation Container
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECDD3), width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.location_off_rounded,
                color: Color(0xFFE11D48),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title
          Text(
            "We're Not Delivering Here Yet!",
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 18),
              fontWeight: FontWeight.w900,
              color: AppDesignSystem.slate900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            'FastKirana & Partner Outlets currently do not deliver to this location. Please choose an address within our operational delivery zones to start ordering.',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: AppDesignSystem.slate600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Distance Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE11D48)),
                const SizedBox(width: 6),
                Text(
                  'Your location is ${widget.distanceKm.toStringAsFixed(1)} km outside our delivery zone',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary Button: Select Serviceable Delivery Address
          Bounceable(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, FadeSlideRoute(page: const DeliveryLocationScreen()));
            },
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppDesignSystem.primary, Color(0xFFC9081E)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppDesignSystem.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Select Serviceable Delivery Address',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 13),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Button: Pick Another Location
          Bounceable(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, FadeSlideRoute(page: const DeliveryLocationScreen()));
            },
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignSystem.border),
              ),
              child: Center(
                child: Text(
                  'Select Another Address',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 12),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Waitlist Notification Section
          const Divider(height: 1),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Want FastKirana in your area?',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                fontWeight: FontWeight.w800,
                color: AppDesignSystem.slate900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Leave your number to get notified when we launch in your area.',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10),
                color: AppDesignSystem.slate500,
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (_isNotified)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Center(
                child: Text(
                  "🎉 You're on our priority waitlist!",
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '10-digit mobile number',
                        hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Bounceable(
                  onTap: () {
                    if (_phoneController.text.trim().length == 10) {
                      setState(() => _isNotified = true);
                      HapticFeedback.lightImpact();
                    }
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.slate900,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Notify Me',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
