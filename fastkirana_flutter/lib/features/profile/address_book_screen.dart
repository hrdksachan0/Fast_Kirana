import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';
import '../../widgets/empty_state.dart';
import '../location/map_picker_screen.dart';

class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  static const Color primaryRed = AppDesignSystem.orange600;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addressesProvider.notifier).loadAddresses());
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppDesignSystem.slate900),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Saved Addresses',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 17),
            fontWeight: FontWeight.w900,
            color: AppDesignSystem.slate900,
            letterSpacing: -0.3,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppDesignSystem.slate100),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: Responsive.formMaxContentWidth,
        fillHeight: true,
        child: Column(
          children: [

          // 2. Real Saved Addresses List from Backend
          Expanded(
            child: addressesAsync.when(
              data: (addresses) {
                if (addresses.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(addressesProvider.notifier).loadAddresses(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: addresses.length,
                    itemBuilder: (context, index) {
                      final addr = addresses[index];
                      final isHome = addr.label.toLowerCase() == 'home';
                      final isWork = addr.label.toLowerCase() == 'work';
                      final isSelected = selectedAddress?.id == addr.id;

                      return GestureDetector(
                        onTap: () {
                          ref.read(selectedAddressProvider.notifier).state = addr;
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? primaryRed : AppDesignSystem.slate200,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? primaryRed.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isHome
                                      ? AppDesignSystem.statusCancelled
                                      : isWork
                                          ? AppDesignSystem.blue50
                                          : AppDesignSystem.green50,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  isHome
                                      ? Icons.home_rounded
                                      : isWork
                                          ? Icons.work_rounded
                                          : Icons.location_on_rounded,
                                  size: 22,
                                  color: isHome
                                      ? AppDesignSystem.red600
                                      : isWork
                                          ? AppDesignSystem.blue600
                                          : AppDesignSystem.green600,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          addr.label,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w900,
                                            fontSize: Responsive.scaledFontSize(context, 14.5),
                                            color: AppDesignSystem.slate900,
                                          ),
                                        ),
                                        if (addr.isDefault || isSelected) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? primaryRed.withValues(alpha: 0.1) : AppDesignSystem.slate100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isSelected ? 'ACTIVE' : 'DEFAULT',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 9),
                                                fontWeight: FontWeight.w800,
                                                color: isSelected ? primaryRed : AppDesignSystem.slate500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      addr.fullAddress,
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12),
                                        fontWeight: FontWeight.w500,
                                        color: AppDesignSystem.slate600,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (addr.phone.isNotEmpty) ...[
                                          const Icon(Icons.phone_outlined, size: 12, color: AppDesignSystem.slate400),
                                          const SizedBox(width: 4),
                                          Text(
                                            addr.phone,
                                            style: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 11),
                                              fontWeight: FontWeight.w600,
                                              color: AppDesignSystem.slate500,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          '•  Pincode: ${addr.pincode}',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 11),
                                            fontWeight: FontWeight.w600,
                                            color: AppDesignSystem.cyan600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppDesignSystem.slate500),
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    final updated = await Navigator.push<Address>(
                                      context,
                                      FadeSlideRoute(
                                        page: MapPickerScreen(
                                          initialLat: addr.latitude,
                                          initialLng: addr.longitude,
                                        ),
                                      ),
                                    );
                                    if (updated != null && mounted) {
                                      ref.read(addressesProvider.notifier).loadAddresses();
                                    }
                                  } else if (val == 'delete') {
                                    _confirmDeleteAddress(context, addr);
                                  } else if (val == 'select') {
                                    ref.read(selectedAddressProvider.notifier).state = addr;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'select',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, size: 16, color: AppDesignSystem.success),
                                        SizedBox(width: 8),
                                        Text('Set Active Delivery'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 16, color: AppDesignSystem.slate500),
                                        SizedBox(width: 8),
                                        Text('Edit Address'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 16, color: AppDesignSystem.danger),
                                        SizedBox(width: 8),
                                        Text('Delete Address', style: TextStyle(color: AppDesignSystem.danger)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: primaryRed),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppDesignSystem.danger),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load saved addresses',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w800, color: AppDesignSystem.slate900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        err.toString().replaceAll('Exception: ', ''),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: AppDesignSystem.slate500),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(addressesProvider.notifier).loadAddresses(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Add New Address Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final newAddr = await Navigator.push<Address>(
                    context,
                    FadeSlideRoute(page: const MapPickerScreen()),
                  );
                  if (newAddr != null && mounted) {
                    ref.read(addressesProvider.notifier).loadAddresses();
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_location_alt_rounded, size: 19, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Add New Delivery Address',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 13.5),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
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
  );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      emoji: '📍',
      title: 'No Saved Addresses Yet',
      subtitle: 'Add your delivery address in Ghatampur\nfor fast grocery and food deliveries.',
      ctaLabel: 'Add Address',
      bgTint: AppDesignSystem.rose50,
      onCta: () async {
        HapticFeedback.lightImpact();
        final newAddr = await Navigator.push<Address>(
          context,
          FadeSlideRoute(page: const MapPickerScreen()),
        );
        if (newAddr != null && mounted) {
          ref.read(addressesProvider.notifier).loadAddresses();
        }
      },
    );
  }

  void _confirmDeleteAddress(BuildContext context, Address addr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Address?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to remove "${addr.label}" from your saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(addressesProvider.notifier).deleteAddress(addr.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}