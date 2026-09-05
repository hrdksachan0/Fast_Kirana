import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/responsive.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/services/location_service.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';
import 'map_picker_screen.dart';
import '../home/main_shell.dart';
import '../../widgets/unserviceable_location_banner.dart';

class DeliveryLocationScreen extends ConsumerStatefulWidget {
  final bool autoFetchLocation;
  const DeliveryLocationScreen({super.key, this.autoFetchLocation = false});

  @override
  ConsumerState<DeliveryLocationScreen> createState() => _DeliveryLocationScreenState();
}

class _DeliveryLocationScreenState extends ConsumerState<DeliveryLocationScreen> {
  final _searchController = TextEditingController();
  bool _isFetchingGps = false;

  static const Color primaryOrange = Color(0xFFEA580C);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoPromptLocation();
    });
  }

  Future<void> _checkAndAutoPromptLocation() async {
    if (widget.autoFetchLocation) {
      _useCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isFetchingGps = true);
    HapticFeedback.lightImpact();

    try {
      final details = await LocationService.fetchCurrentLocationDetails();
      if (details != null && mounted) {
        if (!details.isServiceable) {
          setState(() => _isFetchingGps = false);
          UnserviceableLocationBanner.showUnserviceableModal(context, ref, details.distanceKm);
          return;
        }

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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_chosen_location', true);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('📍 Location set to ${details.area} (${details.distanceKm.toStringAsFixed(1)} km)'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          FadeSlideRoute(page: const MainShell()),
          (route) => false,
        );
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isFetchingGps = false);
      Navigator.push(context, FadeSlideRoute(page: const MapPickerScreen()));
    }
  }

  Future<void> _requestAddressViaWhatsApp() async {
    HapticFeedback.lightImpact();
    const shareText = 'Hey! Please send me your delivery location for FastKirana order delivery: https://www.fastkirana.in/location';
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(shareText)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  void _handleBack() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_chosen_location', true);
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        FadeSlideRoute(page: const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);
    final activeAddress = ref.watch(selectedAddressProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: _handleBack,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
            ),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Delivery Location',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 16),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'FastKirana Express • Serviceable Zones',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 11),
                      fontWeight: FontWeight.w600,
                      color: slateMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
        ),
        body: SafeArea(
          child: ResponsiveContainer(
            maxWidth: Responsive.formMaxContentWidth,
            fillHeight: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP SEARCH BAR (Clean Native Floating Style, Zero Inner Borders)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: slateBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 20, color: primaryOrange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13.5), fontWeight: FontWeight.w600, color: slateDark),
                            decoration: InputDecoration(
                              hintText: 'Search area, street, landmark...',
                              hintStyle: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), color: const Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (query) {
                              if (query.trim().isNotEmpty) {
                                Navigator.push(
                                  context,
                                  FadeSlideRoute(page: const MapPickerScreen()),
                                );
                              }
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                // 2. HERO ACTION BENTO GRID
                // Hero Card: Use Current GPS Location
                Bounceable(
                  onTap: _isFetchingGps ? null : _useCurrentLocation,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFED7AA), width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: primaryOrange.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: primaryOrange.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: _isFetchingGps
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: primaryOrange),
                                )
                              : const Icon(Icons.my_location_rounded, size: 20, color: primaryOrange),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Use Current Location',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 14),
                                      fontWeight: FontWeight.w900,
                                      color: slateDark,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'GPS 🎯',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 9),
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF15803D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Enable GPS for fastest doorstep delivery',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w500,
                                  color: slateMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primaryOrange),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // 2 Secondary Action Cards: Add New Address + Request Address
                Row(
                  children: [
                    // Card 1: Add New Address on Map
                    Expanded(
                      child: Bounceable(
                        onTap: () async {
                          final nav = Navigator.of(context);
                          final newAddr = await nav.push<Address>(
                            FadeSlideRoute(page: const MapPickerScreen()),
                          );
                          if (newAddr != null && mounted) {
                            ref.read(selectedAddressProvider.notifier).state = newAddr;
                            nav.pushAndRemoveUntil(
                              FadeSlideRoute(page: const MainShell()),
                              (route) => false,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: slateBorder, width: 1.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add_location_alt_rounded, size: 17, color: Color(0xFFE20A22)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add Address',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12.5),
                                        fontWeight: FontWeight.w800,
                                        color: slateDark,
                                      ),
                                    ),
                                    Text(
                                      'Pin on Map',
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Card 2: Request Address via WhatsApp
                    Expanded(
                      child: Bounceable(
                        onTap: _requestAddressViaWhatsApp,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: slateBorder, width: 1.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.chat_bubble_outline_rounded, size: 17, color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Share Link',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12.5),
                                        fontWeight: FontWeight.w800,
                                        color: slateDark,
                                      ),
                                    ),
                                    Text(
                                      'Via WhatsApp',
                                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: slateMuted, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // 3. SAVED ADDRESSES HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SAVED ADDRESSES',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        fontWeight: FontWeight.w800,
                        color: slateMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    addressesAsync.maybeWhen(
                      data: (list) => Text(
                        '${list.length} Saved',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w700,
                          color: primaryOrange,
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Saved Addresses Card List (Swiggy Bento Style)
                addressesAsync.when(
                  data: (addresses) {
                    if (addresses.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: slateBorder),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_city_rounded, size: 32, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No saved addresses yet',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 14),
                                  fontWeight: FontWeight.w800,
                                  color: slateDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add a delivery address to get fast deliveries.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  color: slateMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: slateBorder, width: 1.1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: addresses.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final addr = addresses[idx];
                          final isSelected = activeAddress != null && activeAddress.id == addr.id;

                          return InkWell(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              ref.read(selectedAddressProvider.notifier).state = addr;
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('has_chosen_location', true);
                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                FadeSlideRoute(page: const MainShell()),
                                (route) => false,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Badge
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFFED7AA) : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Icon(
                                      _getAddressIcon(addr.label),
                                      size: 20,
                                      color: isSelected ? primaryOrange : slateDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Address Text
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
                                                fontWeight: FontWeight.w900,
                                                color: slateDark,
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDCFCE7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF16A34A)),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'SELECTED',
                                                      style: GoogleFonts.inter(
                                                        fontSize: Responsive.scaledFontSize(context, 9),
                                                        fontWeight: FontWeight.w900,
                                                        color: const Color(0xFF16A34A),
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          addr.fullAddress.isNotEmpty
                                              ? addr.fullAddress
                                              : '${addr.houseNo}, ${addr.street}, ${addr.area}',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 12),
                                            fontWeight: FontWeight.w500,
                                            color: slateMuted,
                                            height: 1.35,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Options 3-dots
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
                                    onSelected: (val) async {
                                      if (val == 'delete') {
                                        await ref.read(addressesProvider.notifier).deleteAddress(addr.id);
                                      } else if (val == 'edit') {
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
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                            SizedBox(width: 8),
                                            Text('Edit Address'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                            SizedBox(width: 8),
                                            Text('Delete Address'),
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
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: primaryOrange),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // 4. FASTKIRANA BRANDING FOOTER
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('⚡', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                      const SizedBox(width: 6),
                      Text(
                        'FastKirana',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
