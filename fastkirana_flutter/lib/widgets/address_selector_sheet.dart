import 'package:flutter/material.dart';
import '../core/theme/design_system.dart';
import '../core/theme/responsive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../core/services/location_service.dart';
import '../data/models/address.dart';
import '../providers/address_provider.dart';
import '../providers/auth_provider.dart';
import '../features/location/map_picker_screen.dart';
import '../core/routes/page_transitions.dart';
import 'unserviceable_location_banner.dart';

class AddressSelectorSheet extends ConsumerStatefulWidget {
  final Address? activeAddress;
  final ValueChanged<Address> onAddressSelected;

  const AddressSelectorSheet({
    super.key,
    required this.activeAddress,
    required this.onAddressSelected,
  });

  static Future<Address?> show(
    BuildContext context, {
    required Address? activeAddress,
    required ValueChanged<Address> onAddressSelected,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressSelectorSheet(
        activeAddress: activeAddress,
        onAddressSelected: onAddressSelected,
      ),
    );
  }

  @override
  ConsumerState<AddressSelectorSheet> createState() => _AddressSelectorSheetState();
}

class _AddressSelectorSheetState extends ConsumerState<AddressSelectorSheet> {
  bool _isLocatingGps = false;

  Future<void> _handleUseCurrentLocation() async {
    if (_isLocatingGps) return;
    setState(() => _isLocatingGps = true);
    HapticFeedback.selectionClick();

    try {
      final details = await LocationService.fetchCurrentLocationDetails();
      if (details != null && mounted) {
        final newAddr = Address(
          id: 'addr_gps_${DateTime.now().millisecondsSinceEpoch}',
          userId: ref.read(currentUserIdProvider) ?? 'user',
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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_chosen_location', true);

        if (!mounted) return;
        ref.read(selectedAddressProvider.notifier).state = newAddr;
        widget.onAddressSelected(newAddr);
        Navigator.pop(context, newAddr);

        if (!details.isServiceable) {
          UnserviceableLocationBanner.showUnserviceableModal(context, ref, details.distanceKm);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF16A34A),
              content: Text('📍 Location set to ${details.area} (${details.distanceKm.toStringAsFixed(1)} km)'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLocatingGps = false);
      // Fallback to map picker
      final newAddress = await Navigator.push<Address>(
        context,
        FadeSlideRoute(page: const MapPickerScreen()),
      );
      if (newAddress != null && mounted) {
        final distKm = LocationService.getDistanceKm(
          newAddress.latitude ?? AppConfig.darkstoreLat,
          newAddress.longitude ?? AppConfig.darkstoreLng,
        );
        ref.read(selectedAddressProvider.notifier).state = newAddress;
        widget.onAddressSelected(newAddress);
        Navigator.pop(context, newAddress);
        if (distKm > LocationService.maxDeliveryRadiusKm) {
          UnserviceableLocationBanner.showUnserviceableModal(context, ref, distKm);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.84,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesignSystem.slate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Bar with Close Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Delivery Location',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 17),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Express delivery within 5 km of Ghatampur Hub',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w500,
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.slate100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppDesignSystem.slate600),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // Action Buttons (Swiggy / Zepto Style): Use GPS & Add New Address
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // 1. Use Current Location (GPS)
                Expanded(
                  child: Bounceable(
                    onTap: _handleUseCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isLocatingGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.green600),
                                )
                              : const Icon(Icons.my_location_rounded, size: 18, color: AppDesignSystem.green600),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isLocatingGps ? 'Locating...' : 'Current Location',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Add New Address (Map Picker)
                Expanded(
                  child: Bounceable(
                    onTap: () async {
                      Navigator.pop(context);
                      final newAddress = await Navigator.push<Address>(
                        context,
                        FadeSlideRoute(page: const MapPickerScreen()),
                      );
                      if (newAddress != null && context.mounted) {
                        final distKm = LocationService.getDistanceKm(
                          newAddress.latitude ?? AppConfig.darkstoreLat,
                          newAddress.longitude ?? AppConfig.darkstoreLng,
                        );
                        ref.read(selectedAddressProvider.notifier).state = newAddress;
                        widget.onAddressSelected(newAddress);
                        if (distKm > LocationService.maxDeliveryRadiusKm) {
                          UnserviceableLocationBanner.showUnserviceableModal(context, ref, distKm);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_location_alt_rounded, size: 18, color: AppDesignSystem.orange600),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Add New Address',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 12.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFC2410C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'SAVED ADDRESSES',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 10.5),
                fontWeight: FontWeight.w900,
                color: AppDesignSystem.slate400,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Saved Addresses List
          Flexible(
            child: addressesAsync.when(
              data: (addresses) {
                if (addresses.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_outlined, size: 40, color: AppDesignSystem.slate400),
                          const SizedBox(height: 10),
                          Text(
                            'No saved addresses yet',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 14),
                              fontWeight: FontWeight.w700,
                              color: AppDesignSystem.slate500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Use current location or add a new address to order',
                            style: GoogleFonts.inter(
                              fontSize: Responsive.scaledFontSize(context, 12),
                              color: AppDesignSystem.slate400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppDesignSystem.slate100),
                  itemBuilder: (context, idx) {
                    final addr = addresses[idx];
                    final isSelected = widget.activeAddress != null &&
                        (widget.activeAddress!.id == addr.id ||
                            (widget.activeAddress!.fullAddress.isNotEmpty &&
                                widget.activeAddress!.fullAddress == addr.fullAddress));

                    final distKm = (addr.latitude != null && addr.longitude != null)
                        ? LocationService.getDistanceKm(addr.latitude!, addr.longitude!)
                        : 0.0;
                    final isServiceable = distKm <= LocationService.maxDeliveryRadiusKm;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedAddressProvider.notifier).state = addr;
                        widget.onAddressSelected(addr);
                        Navigator.pop(context, addr);

                        if (!isServiceable) {
                          UnserviceableLocationBanner.showUnserviceableModal(context, ref, distKm);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon Box
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppDesignSystem.green100
                                    : (isServiceable ? AppDesignSystem.slate100 : const Color(0xFFFFE4E6)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getAddressIcon(addr.label),
                                size: 18,
                                color: isSelected
                                    ? AppDesignSystem.green600
                                    : (isServiceable ? AppDesignSystem.slate600 : const Color(0xFFE11D48)),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Address Text & Badges
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        addr.label.isNotEmpty ? addr.label : 'Saved Address',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 14),
                                          fontWeight: FontWeight.w800,
                                          color: AppDesignSystem.slate900,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppDesignSystem.green100,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppDesignSystem.emerald200),
                                          ),
                                          child: Text(
                                            'SELECTED',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 9),
                                              fontWeight: FontWeight.w900,
                                              color: AppDesignSystem.green600,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      if (!isServiceable) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFE4E6),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'NOT SERVICEABLE (${distKm.toStringAsFixed(1)} km)',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 9),
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFFE11D48),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    addr.fullAddress.isNotEmpty
                                        ? addr.fullAddress
                                        : '${addr.houseNo}, ${addr.street}, ${addr.area}, ${addr.city}',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12),
                                      fontWeight: FontWeight.w500,
                                      color: isServiceable ? AppDesignSystem.slate500 : const Color(0xFF94A3B8),
                                      height: 1.35,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppDesignSystem.orange600,
                  ),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Failed to load saved addresses',
                    style: GoogleFonts.inter(color: AppDesignSystem.danger),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAddressIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('home') || l.contains('ghar') || l.contains('house')) {
      return Icons.home_rounded;
    } else if (l.contains('work') || l.contains('office') || l.contains('shop')) {
      return Icons.work_rounded;
    } else if (l.contains('road') || l.contains('street')) {
      return Icons.navigation_rounded;
    }
    return Icons.location_on_rounded;
  }
}
