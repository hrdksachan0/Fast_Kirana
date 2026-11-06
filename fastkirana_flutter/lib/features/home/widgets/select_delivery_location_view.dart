import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../../core/routes/page_transitions.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../data/models/address.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/product_provider.dart';
import '../../location/delivery_location_screen.dart';
import '../../../widgets/darkstore_switch_dialog.dart';

class SelectDeliveryLocationView extends ConsumerStatefulWidget {
  const SelectDeliveryLocationView({super.key});

  @override
  ConsumerState<SelectDeliveryLocationView> createState() =>
      _SelectDeliveryLocationViewState();
}

class _SelectDeliveryLocationViewState
    extends ConsumerState<SelectDeliveryLocationView> {
  bool _isLocating = false;

  Future<void> _handleGpsLocation() async {
    setState(() => _isLocating = true);
    HapticFeedback.lightImpact();

    try {
      final details = await LocationService.fetchCurrentLocationDetails();
      if (details != null && mounted) {
        final address = Address(
          id: 'gps_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'current',
          label: 'Current Location',
          houseNo: details.houseNo,
          street: details.street,
          area: details.area,
          city: details.city,
          pincode: details.pincode,
          latitude: details.latitude,
          longitude: details.longitude,
          isDefault: true,
        );

        ref.read(selectedAddressProvider.notifier).state = address;
        ref.invalidate(homeProductCatalogProvider);
        if (mounted) {
          await DarkstoreSwitchDialog.show(context, cityName: details.city);
        }
        setState(() => _isLocating = false);
        return;
      }
    } catch (e, st) {
      LoggerService.error('GPS auto-detect error in SelectDeliveryLocationView', e, st);
    }

    if (mounted) {
      setState(() => _isLocating = false);
      Navigator.push(
        context,
        FadeSlideRoute(page: const DeliveryLocationScreen(autoFetchLocation: true)),
      );
    }
  }



  @override
  Widget build(BuildContext context) {


    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          color: const Color(0xFFFFEDD5),
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
          // 1. Icon Badge
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDBA74), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.location_searching_rounded,
                size: 34,
                color: Color(0xFFEA580C),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 2. Headline
          Text(
            'Where should we deliver?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // 3. Subtitle
          Text(
            'Set your delivery location to see fresh groceries, exact delivery time & local offers in your area.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 22),

          // 4. Primary CTA: Auto-detect GPS Location
          Bounceable(
            onTap: _isLocating ? null : _handleGpsLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLocating)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _isLocating ? 'Detecting Location...' : 'Use Current Location (GPS)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 5. Secondary CTA: Search Area or Mohalla
          Bounceable(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                FadeSlideRoute(page: const DeliveryLocationScreen(autoFetchLocation: false)),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Search Area, Colony or Street',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
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
