import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';

import '../core/theme/responsive.dart';

import '../core/services/location_service.dart';

import '../providers/address_provider.dart';

import 'address_selector_sheet.dart';

import 'unserviceable_location_banner.dart';

/// Swiggy / Zomato style sleek location permission onboarding sheet.

///

/// Prompts the customer on first-time app open when no location/address is chosen:

/// - "Share your location for fastest delivery"

/// - "Hum aapke mohalle/shehar ka exact dark store aur live stock dikhane ke liye location use karte hain."

/// - [ Enable Device Location (GPS) ]

/// - [ Enter Location Manually ]

class SwiggyLocationPermissionSheet extends ConsumerStatefulWidget {

  const SwiggyLocationPermissionSheet({super.key});

  /// Presents the sleek Swiggy-style permission bottom sheet.

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

    extends ConsumerState<SwiggyLocationPermissionSheet> {

  bool _isLocating = false;

  Future<void> _handleEnableGps() async {

    if (_isLocating) return;

    setState(() => _isLocating = true);

    HapticFeedback.mediumImpact();

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

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              backgroundColor: const Color(0xFF16A34A),

              behavior: SnackBarBehavior.floating,

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(12),

              ),

              content: Row(

                children: [

                  const Icon(

                    Icons.check_circle_rounded,

                    color: Colors.white,

                    size: 18,

                  ),

                  const SizedBox(width: 8),

                  Expanded(

                    child: Text(

                      'Delivering to $areaName • Live store connected! 🚀',

                      style: GoogleFonts.inter(

                        fontSize: Responsive.scaledFontSize(context, 12.5),

                        fontWeight: FontWeight.w700,

                        color: Colors.white,

                      ),

                    ),

                  ),

                ],

              ),

            ),

          );

        }

      }

    } finally {

      if (mounted) {

        setState(() => _isLocating = false);

      }

    }

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

    const primaryOrange = Color(0xFFEA580C);

    const primaryRed = Color(0xFFDC2626);

    const slateDark = Color(0xFF0F172A);

    const slateMuted = Color(0xFF475569);

    const slateBorder = Color(0xFFE2E8F0);

    return Container(

      decoration: const BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),

        boxShadow: [

          BoxShadow(

            color: Color(0x33000000),

            blurRadius: 24,

            offset: Offset(0, -4),

          ),

        ],

      ),

      padding: EdgeInsets.fromLTRB(

        22,

        12,

        22,

        MediaQuery.of(context).padding.bottom + 18,

      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.center,

        children: [

          // Drag handle

          Container(

            width: 44,

            height: 4.5,

            decoration: BoxDecoration(

              color: const Color(0xFFCBD5E1),

              borderRadius: BorderRadius.circular(2.5),

            ),

          ),

          const SizedBox(height: 18),

          // Glowing Concentric Location Graphic

          Stack(

            alignment: Alignment.center,

            children: [

              Container(

                width: 90,

                height: 90,

                decoration: const BoxDecoration(

                  color: Color(0xFFFFF7ED),

                  shape: BoxShape.circle,

                ),

              ),

              Container(

                width: 68,

                height: 68,

                decoration: const BoxDecoration(

                  color: Color(0xFFFFEDD5),

                  shape: BoxShape.circle,

                ),

              ),

              Container(

                width: 48,

                height: 48,

                decoration: const BoxDecoration(

                  gradient: LinearGradient(

                    colors: [primaryOrange, primaryRed],

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                  ),

                  shape: BoxShape.circle,

                  boxShadow: [

                    BoxShadow(

                      color: Color(0x4DEA580C),

                      blurRadius: 12,

                      offset: Offset(0, 4),

                    ),

                  ],

                ),

                child: const Center(

                  child: Icon(

                    Icons.location_on_rounded,

                    color: Colors.white,

                    size: 26,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          // Main Headline

          Text(

            'Share your location for fastest delivery',

            textAlign: TextAlign.center,

            style: GoogleFonts.inter(

              fontSize: Responsive.scaledFontSize(context, 18),

              fontWeight: FontWeight.w900,

              color: slateDark,

              letterSpacing: -0.4,

            ),

          ),

          const SizedBox(height: 8),

          // Subtitle in user-requested Hindi / English

          Text(

            'Hum aapke mohalle/shehar ka exact dark store aur live stock dikhane ke liye location use karte hain.',

            textAlign: TextAlign.center,

            style: GoogleFonts.inter(

              fontSize: Responsive.scaledFontSize(context, 12.5),

              fontWeight: FontWeight.w500,

              color: slateMuted,

              height: 1.45,

            ),

          ),

          const SizedBox(height: 20),

          // Swiggy-style Value Highlights

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

            decoration: BoxDecoration(

              color: const Color(0xFFF8FAFC),

              borderRadius: BorderRadius.circular(16),

              border: Border.all(color: slateBorder, width: 1),

            ),

            child: Column(

              children: [

                _buildValueRow(

                  icon: Icons.flash_on_rounded,

                  iconColor: const Color(0xFFEA580C),

                  title: 'Fast Delivery',

                  subtitle: 'Direct from your nearest neighbourhood store',

                  context: context,

                ),

                const Divider(height: 16, thickness: 0.8, color: slateBorder),

                _buildValueRow(

                  icon: Icons.storefront_rounded,

                  iconColor: const Color(0xFF16A34A),

                  title: 'Live Local Stock & Pricing',

                  subtitle: 'Real-time items available in your city',

                  context: context,

                ),

                const Divider(height: 16, thickness: 0.8, color: slateBorder),

                _buildValueRow(

                  icon: Icons.touch_app_rounded,

                  iconColor: const Color(0xFF2563EB),

                  title: '1-Tap Zero Typing Setup',

                  subtitle: 'Auto-detects area without typing full address',

                  context: context,

                ),

              ],

            ),

          ),

          const SizedBox(height: 22),

          // Primary Button: [ Enable Device Location (GPS) ]

          SizedBox(

            width: double.infinity,

            height: 52,

            child: ElevatedButton(

              onPressed: _isLocating ? null : _handleEnableGps,

              style: ElevatedButton.styleFrom(

                backgroundColor: primaryOrange,

                foregroundColor: Colors.white,

                elevation: 0,

                shadowColor: Colors.transparent,

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(16),

                ),

                padding: EdgeInsets.zero,

              ),

              child: Ink(

                decoration: BoxDecoration(

                  gradient: const LinearGradient(

                    colors: [primaryOrange, primaryRed],

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                  ),

                  borderRadius: BorderRadius.circular(16),

                ),

                child: Center(

                  child: _isLocating

                      ? Row(

                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [

                            const SizedBox(

                              width: 20,

                              height: 20,

                              child: CircularProgressIndicator(

                                strokeWidth: 2.2,

                                color: Colors.white,

                              ),

                            ),

                            const SizedBox(width: 10),

                            Text(

                              'Finding nearest store...',

                              style: GoogleFonts.inter(

                                fontSize: Responsive.scaledFontSize(context, 14),

                                fontWeight: FontWeight.w800,

                                color: Colors.white,

                              ),

                            ),

                          ],

                        )

                      : Row(

                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [

                            const Icon(

                              Icons.my_location_rounded,

                              size: 19,

                              color: Colors.white,

                            ),

                            const SizedBox(width: 8),

                            Text(

                              'Enable Device Location (GPS)',

                              style: GoogleFonts.inter(

                                fontSize: Responsive.scaledFontSize(context, 14),

                                fontWeight: FontWeight.w800,

                                color: Colors.white,

                                letterSpacing: -0.2,

                              ),

                            ),

                          ],

                        ),

                ),

              ),

            ),

          ),

          const SizedBox(height: 10),

          // Secondary Button: [ Enter Location Manually ]

          SizedBox(

            width: double.infinity,

            height: 48,

            child: OutlinedButton(

              onPressed: _isLocating ? null : _handleManualLocation,

              style: OutlinedButton.styleFrom(

                backgroundColor: const Color(0xFFF8FAFC),

                foregroundColor: slateDark,

                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(16),

                ),

              ),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  const Icon(

                    Icons.search_rounded,

                    size: 18,

                    color: Color(0xFF64748B),

                  ),

                  const SizedBox(width: 8),

                  Text(

                    'Enter Location Manually',

                    style: GoogleFonts.inter(

                      fontSize: Responsive.scaledFontSize(context, 13.5),

                      fontWeight: FontWeight.w700,

                      color: const Color(0xFF334155),

                    ),

                  ),

                ],

              ),

            ),

          ),

          const SizedBox(height: 12),

          // Privacy Assurance Note

          Row(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              const Icon(

                Icons.lock_outline_rounded,

                size: 12,

                color: Color(0xFF94A3B8),

              ),

              const SizedBox(width: 4),

              Text(

                'Your location is securely used only for store delivery.',

                style: GoogleFonts.inter(

                  fontSize: Responsive.scaledFontSize(context, 10.5),

                  fontWeight: FontWeight.w600,

                  color: const Color(0xFF94A3B8),

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

  Widget _buildValueRow({

    required IconData icon,

    required Color iconColor,

    required String title,

    required String subtitle,

    required BuildContext context,

  }) {

    return Row(

      crossAxisAlignment: CrossAxisAlignment.center,

      children: [

        Container(

          width: 32,

          height: 32,

          decoration: BoxDecoration(

            color: iconColor.withValues(alpha: 0.12),

            borderRadius: BorderRadius.circular(8),

          ),

          child: Icon(icon, color: iconColor, size: 17),

        ),

        const SizedBox(width: 12),

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(

                title,

                style: GoogleFonts.inter(

                  fontSize: Responsive.scaledFontSize(context, 12.5),

                  fontWeight: FontWeight.w800,

                  color: const Color(0xFF0F172A),

                ),

              ),

              Text(

                subtitle,

                style: GoogleFonts.inter(

                  fontSize: Responsive.scaledFontSize(context, 11),

                  fontWeight: FontWeight.w500,

                  color: const Color(0xFF64748B),

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

}
