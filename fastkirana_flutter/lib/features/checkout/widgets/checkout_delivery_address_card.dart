import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/services/location_service.dart';
import '../../../data/models/address.dart';
import '../../../widgets/address_selector_sheet.dart';

class CheckoutDeliveryAddressCard extends StatelessWidget {
  final Address? selectedAddress;
  final DeliveryTierInfo tier;
  final ValueChanged<Address> onAddressChanged;

  const CheckoutDeliveryAddressCard({
    super.key,
    required this.selectedAddress,
    required this.tier,
    required this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    const slateDark = AppDesignSystem.slate900;
    const slateMuted = AppDesignSystem.slate500;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesignSystem.orange300, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.orange600.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Deliver To Label + Change Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppDesignSystem.orange50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDesignSystem.orange200),
                ),
                child: Icon(
                  selectedAddress?.label.toLowerCase().contains('work') == true
                      ? Icons.work_rounded
                      : (selectedAddress?.label.toLowerCase().contains('current') == true
                          ? Icons.my_location_rounded
                          : Icons.home_rounded),
                  size: 18,
                  color: AppDesignSystem.orange600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVER TO',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10),
                        fontWeight: FontWeight.w800,
                        color: slateMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      () {
                        if (selectedAddress == null ||
                            selectedAddress!.label.trim().isEmpty ||
                            selectedAddress!.label.trim() == '.') {
                          return 'Home';
                        }
                        final clean = selectedAddress!.label.replaceAll('📍', '').trim();
                        return clean.isNotEmpty ? clean : 'Home';
                      }(),
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w900,
                        color: slateDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      (selectedAddress?.area != null &&
                              selectedAddress!.area.trim().isNotEmpty &&
                              selectedAddress!.area.trim() != '.' &&
                              selectedAddress!.area.trim().toLowerCase() != 'n/a')
                          ? selectedAddress!.area.trim()
                          : 'Ghatampur Zone',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: AppDesignSystem.orange600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Interactive Change Address Pill
              Bounceable(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  await AddressSelectorSheet.show(
                    context,
                    activeAddress: selectedAddress,
                    onAddressSelected: onAddressChanged,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.orange50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppDesignSystem.orange300, width: 1.1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'CHANGE',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w900,
                          color: AppDesignSystem.orange600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: AppDesignSystem.orange600),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Full Exact Address Text (Cleaned of stray dots & commas)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppDesignSystem.slate50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppDesignSystem.slate500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (selectedAddress != null && selectedAddress!.fullAddress.isNotEmpty
                            ? selectedAddress!.fullAddress
                            : 'Near Ghatampur Central Market, Uttar Pradesh 209206')
                        .replaceAll(RegExp(r'^[.,\s]+'), '')
                        .replaceAll(RegExp(r',\s*,+'), ', ')
                        .trim(),
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: AppDesignSystem.slate700,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Distance & Delivery Tier Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: !tier.isServiceable ? AppDesignSystem.statusCancelled : AppDesignSystem.green50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: !tier.isServiceable ? AppDesignSystem.rose200 : AppDesignSystem.green200,
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  !tier.isServiceable ? Icons.error_outline_rounded : Icons.delivery_dining_rounded,
                  size: 16,
                  color: !tier.isServiceable ? AppDesignSystem.red600 : AppDesignSystem.green600,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    !tier.isServiceable
                        ? '⚠️ Outside 5.0 km Hub (${tier.distanceKm.toStringAsFixed(1)} km) • Delivery Unavailable'
                        : '${tier.tierName} (${tier.distanceKm.toStringAsFixed(1)} km) • ${tier.freeDeliveryLabel}',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w800,
                      color: !tier.isServiceable ? AppDesignSystem.red600 : AppDesignSystem.green700,
                    ),
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
