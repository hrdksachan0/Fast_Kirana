import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';
import '../data/models/address.dart';
import '../core/services/location_service.dart';
import '../providers/address_provider.dart';

class LocationDriftSheet extends StatelessWidget {
  final LocationDetails newGpsDetails;
  final Address? previousAddress;
  final double driftDistanceKm;

  const LocationDriftSheet({
    super.key,
    required this.newGpsDetails,
    required this.previousAddress,
    required this.driftDistanceKm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required LocationDetails newGpsDetails,
    required Address? previousAddress,
    required double driftDistanceKm,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationDriftSheet(
        newGpsDetails: newGpsDetails,
        previousAddress: previousAddress,
        driftDistanceKm: driftDistanceKm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areaText = newGpsDetails.area.isNotEmpty ? newGpsDetails.area : newGpsDetails.city;
    final isServiceable = newGpsDetails.isServiceable;
    final prevLabel = previousAddress?.label ?? previousAddress?.area ?? 'Saved Address';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Icon & Title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Different Location Detected',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 16),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You are ~${driftDistanceKm.toStringAsFixed(1)} km away from $prevLabel',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Current Detected Location Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        areaText,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.slate900,
                        ),
                      ),
                      Text(
                        newGpsDetails.formattedAddress,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          color: AppDesignSystem.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isServiceable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚡ 10-15 Min',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Consumer(
            builder: (context, ref, _) {
              return Row(
                children: [
                  // Keep Previous Address Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Keep $prevLabel',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w700,
                          color: AppDesignSystem.slate700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Switch to Current Location Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final gpsAddress = Address(
                          id: 'addr_drift_gps_${DateTime.now().millisecondsSinceEpoch}',
                          userId: 'current',
                          label: 'Current Location',
                          houseNo: newGpsDetails.houseNo,
                          street: newGpsDetails.street,
                          area: newGpsDetails.area,
                          city: newGpsDetails.city,
                          pincode: newGpsDetails.pincode,
                          latitude: newGpsDetails.latitude,
                          longitude: newGpsDetails.longitude,
                          isDefault: true,
                        );

                        ref.read(selectedAddressProvider.notifier).state = gpsAddress;
                        Navigator.pop(context, true);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF16A34A),
                            content: Text('📍 Switched delivery to $areaText'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Deliver Here',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12.5),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
