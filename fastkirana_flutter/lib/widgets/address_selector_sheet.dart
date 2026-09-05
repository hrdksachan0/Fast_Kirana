import 'package:flutter/material.dart';
import '../core/theme/design_system.dart';
import '../core/theme/responsive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../data/models/address.dart';
import '../providers/address_provider.dart';
import '../features/location/map_picker_screen.dart';
import '../core/routes/page_transitions.dart';

class AddressSelectorSheet extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Close Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Choose a delivery address',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 17),
                    fontWeight: FontWeight.w800,
                    color: AppDesignSystem.slate900,
                    letterSpacing: -0.3,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.slate100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: AppDesignSystem.slate500),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

          // + Add New Address Action Button (Swiggy Style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Bounceable(
              onTap: () async {
                Navigator.pop(context);
                final newAddress = await Navigator.push<Address>(
                  context,
                  FadeSlideRoute(page: const MapPickerScreen()),
                );
                if (newAddress != null) {
                  onAddressSelected(newAddress);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppDesignSystem.orange200, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppDesignSystem.orange600.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.orange50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: AppDesignSystem.orange600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add new Address',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.orange600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: AppDesignSystem.slate100),

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
                            'Add your delivery address to proceed with order',
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppDesignSystem.slate100),
                  itemBuilder: (context, idx) {
                    final addr = addresses[idx];
                    final isSelected = activeAddress != null &&
                        (activeAddress!.id == addr.id ||
                            (activeAddress!.fullAddress.isNotEmpty &&
                                activeAddress!.fullAddress == addr.fullAddress));

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(selectedAddressProvider.notifier).state = addr;
                        onAddressSelected(addr);
                        Navigator.pop(context, addr);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    : AppDesignSystem.slate100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getAddressIcon(addr.label),
                                size: 18,
                                color: isSelected
                                    ? AppDesignSystem.green600
                                    : AppDesignSystem.slate600,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Address Text & Selected Badge
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        addr.label.isNotEmpty ? addr.label : 'Saved Address',
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 14.5),
                                          fontWeight: FontWeight.w800,
                                          color: AppDesignSystem.slate900,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppDesignSystem.green100,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppDesignSystem.emerald200),
                                          ),
                                          child: Text(
                                            'SELECTED',
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 9.5),
                                              fontWeight: FontWeight.w900,
                                              color: AppDesignSystem.green600,
                                              letterSpacing: 0.4,
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
                                      color: AppDesignSystem.slate500,
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
