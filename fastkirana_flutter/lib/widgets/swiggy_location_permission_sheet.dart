import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/responsive.dart';
import '../core/services/location_service.dart';
import '../core/utils/app_toast.dart';
import '../core/utils/app_url_launcher.dart';
import '../data/models/address.dart';
import '../providers/address_provider.dart';
import '../providers/store_hub_provider.dart';
import 'address_selector_sheet.dart';
import 'unserviceable_location_banner.dart';

/// Zepto / Blinkit style sleek "Your device location is off" onboarding sheet.
///
/// Features:
/// 1. 3D Cloud & Pin Hero Graphic
/// 2. 1-Tap "Use my Current Location" [Enable] Button
/// 3. "Request address from friend" via WhatsApp share
/// 4. 1-Tap Saved Address Quick-Picker (Home, Work, etc.)
/// 5. "Search your Location" manual search entrypoint
class SwiggyLocationPermissionSheet extends ConsumerStatefulWidget {
  const SwiggyLocationPermissionSheet({super.key});

  /// Presents the sleek Zepto-style location permission bottom sheet.
  static Future<bool?> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SwiggyLocationPermissionSheet(),
    );
  }

  @override
  ConsumerState<SwiggyLocationPermissionSheet> createState() =>
      _SwiggyLocationPermissionSheetState();
}

class _SwiggyLocationPermissionSheetState
    extends ConsumerState<SwiggyLocationPermissionSheet>
    with WidgetsBindingObserver {
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndAutoDetectOnResume();
    }
  }

  Future<void> _checkAndAutoDetectOnResume() async {
    if (_isLocating || !mounted) return;
    final serviceEnabled = await LocationService.isLocationServiceEnabledSafe();
    if (!mounted) return;
    if (serviceEnabled) {
      // Frictionless: User turned on GPS in Settings and returned to the app!
      // Instantly auto-locate, pop this sheet, and announce Ghatampur Central Hub.
      _handleEnableGps();
    }
  }

  Future<void> _handleEnableGps() async {
    if (_isLocating) return;
    HapticFeedback.mediumImpact();

    final serviceEnabled = await LocationService.isLocationServiceEnabledSafe();
    if (!mounted) return;
    if (!serviceEnabled) {
      // 1-Tap directly opens Android/iOS Location Settings, exactly like Zepto
      await Geolocator.openLocationSettings();
      return;
    }

    setState(() => _isLocating = true);

    try {
      final details = await LocationService.detectAndApplyGpsLocation(
        context: context,
        ref: ref,
      );

      if (!mounted) return;

      if (details != null) {
        Navigator.pop(context, true);
        final areaName = details.area.isNotEmpty ? details.area : details.city;

        if (!details.isServiceable) {
          UnserviceableLocationBanner.showUnserviceableModal(
            context,
            ref,
            details.distanceKm,
          );
        } else {
          final currentHub = ref.read(currentStoreHubProvider);
          final hubSubtitle = currentHub.name.isNotEmpty
              ? 'Connected to ${currentHub.name}'
              : 'Delivery available in your area';
          AppToast.showSuccess(
            context,
            'Delivering to $areaName',
            subtitle: hubSubtitle,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _handleSelectSavedAddress(Address address) {
    HapticFeedback.lightImpact();
    ref.read(selectedAddressProvider.notifier).state = address;
    ref.invalidate(deliveryTierProvider);
    Navigator.pop(context, true);

    final label = address.label.isNotEmpty ? address.label : (address.area.isNotEmpty ? address.area : 'Selected Address');
    AppToast.showSuccess(
      context,
      'Delivering to $label',
      subtitle: address.fullAddress,
    );
  }

  void _handleRequestAddressFromFriend() {
    HapticFeedback.lightImpact();
    final message = Uri.encodeComponent(
      'Namaste! Mujhe aapke yahan FastMinute se 10-minute grocery & food delivery mangwani hai. Kripya apna exact address ya Google Maps pin yahan share karein.',
    );
    AppUrlLauncher.launchString('https://wa.me/?text=$message');
  }

  void _handleManualLocation() {
    HapticFeedback.lightImpact();
    Navigator.pop(context, false);
    final currentAddress = ref.read(selectedAddressProvider);
    AddressSelectorSheet.show(
      context,
      activeAddress: currentAddress,
      onAddressSelected: (addr) {
        ref.invalidate(deliveryTierProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandPink = Color(0xFFE11D48); // FastMinute Crimson / Zepto Pink
    const brandPinkSoft = Color(0xFFFFF1F2);
    const slateDark = Color(0xFF0F172A);
    const slateMuted = Color(0xFF64748B);
    const slateBorder = Color(0xFFE2E8F0);

    final savedAddressesAsync = ref.watch(addressesProvider);
    final savedAddresses = savedAddressesAsync.valueOrNull ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 14),

          // ── 3D Sky Box & Pin Hero ──
          Container(
            width: double.infinity,
            height: 105,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE0F2FE), Color(0xFFF0F9FF), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floating Cloud 1
                Positioned(
                  top: 14,
                  left: 28,
                  child: Icon(
                    Icons.cloud_rounded,
                    color: Colors.white.withValues(alpha: 0.90),
                    size: 38,
                  ),
                ),
                // Floating Cloud 2
                Positioned(
                  bottom: 12,
                  right: 32,
                  child: Icon(
                    Icons.cloud_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 44,
                  ),
                ),
                // 3D Pin Icon (Upright, Straight Down, Zepto Style)
                const _LocationPinWidget(),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Headline & Subtitle ──
          Text(
            'Your device location is off',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: Responsive.scaledFontSize(context, 19),
              fontWeight: FontWeight.w900,
              color: slateDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enabling location helps us reach you quickly with accurate delivery',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: Responsive.scaledFontSize(context, 12),
              fontWeight: FontWeight.w500,
              color: slateMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),

          // ── Action Card Group (Enable Location + Request from Friend) ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: slateBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Row 1: Use my Current Location
                InkWell(
                  onTap: _isLocating ? null : _handleEnableGps,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: brandPinkSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location_rounded,
                              color: brandPink,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Use my Current Location',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w800,
                              color: slateDark,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isLocating ? null : _handleEnableGps,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandPink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLocating
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Enable',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Responsive.scaledFontSize(context, 12),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                // Row 2: Request address from friend
                InkWell(
                  onTap: _handleRequestAddressFromFriend,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Color(0xFF059669),
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Request address from friend',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Responsive.scaledFontSize(context, 13),
                              fontWeight: FontWeight.w800,
                              color: slateDark,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Saved Address Section (If user has addresses) ──
          if (savedAddresses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select your address',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w800,
                      color: slateDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: _handleManualLocation,
                    child: Row(
                      children: [
                        Text(
                          'See All',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            fontWeight: FontWeight.w800,
                            color: brandPink,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: brandPink,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Top 2 Saved Addresses
            ...savedAddresses.take(2).map((address) {
              final label = address.label.isNotEmpty ? address.label : 'Saved Address';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _handleSelectSavedAddress(address),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            address.label.toLowerCase() == 'home'
                                ? Icons.home_outlined
                                : (address.label.toLowerCase() == 'work' ? Icons.work_outline : Icons.location_on_outlined),
                            size: 18,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 12),
                                  fontWeight: FontWeight.w800,
                                  color: slateDark,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                address.fullAddress,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Responsive.scaledFontSize(context, 10.5),
                                  fontWeight: FontWeight.w500,
                                  color: slateMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // ── Search Your Location Button (Bottom Entrypoint) ──
          OutlinedButton(
            onPressed: _handleManualLocation,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: slateDark,
                ),
                const SizedBox(width: 8),
                Text(
                  'Search your Location',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Responsive.scaledFontSize(context, 13),
                    fontWeight: FontWeight.w800,
                    color: slateDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upright, perfectly symmetrical 3D Location Pin pointing straight DOWN (Zepto style)
class _LocationPinWidget extends StatelessWidget {
  const _LocationPinWidget();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 46,
      height: 56,
      child: CustomPaint(
        painter: _LocationPinPainter(),
      ),
    );
  }
}

class _LocationPinPainter extends CustomPainter {
  const _LocationPinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    // 1. Soft bottom ambient shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFFE11D48).withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 2), width: w * 0.6, height: 7),
      shadowPaint,
    );

    // 2. Teardrop Pin Path pointing straight DOWN (0 degrees, zero tilt)
    final pinPath = Path();
    pinPath.moveTo(w / 2, h - 3); // Tip at bottom center
    // Left curve up to circular top
    pinPath.cubicTo(w * 0.05, h * 0.58, 0, h * 0.42, 0, r);
    // Semi-circle arc over the top
    pinPath.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Right curve down to tip
    pinPath.cubicTo(w, h * 0.42, w * 0.95, h * 0.58, w / 2, h - 3);
    pinPath.close();

    // 3. Vibrant Gradient Fill
    final pinPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFF2E70), Color(0xFFE11D48)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(pinPath, pinPaint);

    // 4. White Center Circle / Core
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, r * 0.94), r * 0.36, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
