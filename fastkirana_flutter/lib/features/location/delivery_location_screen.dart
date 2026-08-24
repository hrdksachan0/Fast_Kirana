import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/design_system.dart';
import '../../core/services/location_service.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../profile/address_book_screen.dart';

class DeliveryLocationScreen extends ConsumerStatefulWidget {
  final bool isInitialOnboarding;
  const DeliveryLocationScreen({super.key, this.isInitialOnboarding = false});

  @override
  ConsumerState<DeliveryLocationScreen> createState() => _DeliveryLocationScreenState();
}

class _DeliveryLocationScreenState extends ConsumerState<DeliveryLocationScreen> {
  bool _isDetectingLocation = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color primaryRed = Color(0xFFE20A22);

  final List<Map<String, String>> _popularLocalities = const [
    {'name': 'Subhash Chowk', 'desc': 'Central Market Area, Ghatampur 209206'},
    {'name': 'Station Road', 'desc': 'Railway Station & Bus Stand, Ghatampur'},
    {'name': 'Nagar Palika Parishad', 'desc': 'Administrative Block, Ghatampur'},
    {'name': 'Hospital Road', 'desc': 'Community Health Center Zone, Ghatampur'},
    {'name': 'Nehru Nagar', 'desc': 'Residential Colony, Ghatampur 209206'},
    {'name': 'Mandi Samiti', 'desc': 'Grain & Vegetable Market, Kanpur Road'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _detectGpsLocation() async {
    HapticFeedback.mediumImpact();
    setState(() => _isDetectingLocation = true);

    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final details = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (!mounted) return;

        // Create temporary address object for active delivery
        final detectedAddress = Address(
          id: 'temp_gps_${DateTime.now().millisecondsSinceEpoch}',
          label: 'Current GPS Location',
          houseNo: details.houseNo.isNotEmpty ? details.houseNo : 'Current Pin',
          street: details.street.isNotEmpty ? details.street : details.area,
          area: details.area,
          city: details.city,
          pincode: details.pincode,
          phone: '',
          latitude: details.latitude,
          longitude: details.longitude,
          isDefault: true,
        );

        // Update selected address
        ref.read(selectedAddressProvider.notifier).state = detectedAddress;

        // If user is logged in, optionally save in background
        final user = ref.read(currentUserProvider);
        if (user != null) {
          try {
            await ref.read(addressesProvider.notifier).addAddress({
              'label': 'Current Location',
              'houseNo': detectedAddress.houseNo,
              'street': detectedAddress.street,
              'area': detectedAddress.area,
              'city': detectedAddress.city,
              'pincode': detectedAddress.pincode,
              'phone': user.phone ?? '7054470303',
              'lat': detectedAddress.latitude,
              'lng': detectedAddress.longitude,
              'isDefault': true,
            });
          } catch (_) {}
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delivering to: ${details.formattedAddress}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        _proceedToApp();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('Could not access GPS. Please choose your area manually.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Location error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  void _selectLocality(Map<String, String> locality) {
    HapticFeedback.lightImpact();
    final address = Address(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      label: locality['name']!,
      houseNo: '',
      street: locality['name']!,
      area: locality['name']!,
      city: 'Ghatampur, Kanpur Nagar',
      pincode: '209206',
      phone: '',
      latitude: 26.1534185,
      longitude: 80.1714024,
      isDefault: true,
    );

    ref.read(selectedAddressProvider.notifier).state = address;
    _proceedToApp();
  }

  void _proceedToApp() {
    if (widget.isInitialOnboarding) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () {
            if (widget.isInitialOnboarding) {
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Where should we deliver?',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Box
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search area, colony or landmark in Ghatampur',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. GPS Auto-Detect Button Card
                  GestureDetector(
                    onTap: _isDetectingLocation ? null : _detectGpsLocation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFEF2F2), Color(0xFFFFF1F2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: primaryRed.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryRed.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: _isDetectingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.my_location_rounded, size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isDetectingLocation ? 'Detecting your GPS location...' : 'Use Current GPS Location',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: primaryRed,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Accurate delivery to your doorstep',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF9F1239),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primaryRed),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Add Address Manually Button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_location_alt_rounded, size: 18, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Enter Address Details Manually',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. User's Saved Addresses (from Real API)
                  addressesAsync.when(
                      data: (addresses) {
                        if (addresses.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SAVED ADDRESSES',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF64748B),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...addresses.map((addr) {
                              return GestureDetector(
                                onTap: () {
                                  ref.read(selectedAddressProvider.notifier).state = addr;
                                  _proceedToApp();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryRed.withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          addr.label.toLowerCase() == 'home'
                                              ? Icons.home_rounded
                                              : addr.label.toLowerCase() == 'work'
                                                  ? Icons.work_rounded
                                                  : Icons.location_on_rounded,
                                          size: 18,
                                          color: primaryRed,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              addr.label,
                                              style: GoogleFonts.inter(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              addr.fullAddress,
                                              style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                color: const Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFFCBD5E1)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                  // 4. Popular Localities / Landmarks in Ghatampur
                  Text(
                    'POPULAR AREAS IN GHATAMPUR',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._popularLocalities
                      .where((loc) =>
                          _searchQuery.isEmpty ||
                          loc['name']!.toLowerCase().contains(_searchQuery) ||
                          loc['desc']!.toLowerCase().contains(_searchQuery))
                      .map((locality) {
                    return GestureDetector(
                      onTap: () => _selectLocality(locality),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.near_me_rounded, size: 16, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locality['name']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locality['desc']!,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
