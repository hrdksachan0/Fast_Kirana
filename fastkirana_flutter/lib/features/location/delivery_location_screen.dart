import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/routes/page_transitions.dart';
import '../../core/services/location_service.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/brand_logo.dart';
import '../profile/address_book_screen.dart';

class DeliveryLocationScreen extends ConsumerStatefulWidget {
  final bool isInitialOnboarding;
  const DeliveryLocationScreen({super.key, this.isInitialOnboarding = false});

  @override
  ConsumerState<DeliveryLocationScreen> createState() => _DeliveryLocationScreenState();
}

class _DeliveryLocationScreenState extends ConsumerState<DeliveryLocationScreen>
    with SingleTickerProviderStateMixin {
  bool _isDetectingLocation = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color primaryPinkRed = Color(0xFFE20A22);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  final List<Map<String, String>> _popularLocalities = const [
    {
      'label': 'Subhash Chowk (Central)',
      'address': 'Main Market Area, Ghatampur, Kanpur Nagar 209206',
    },
    {
      'label': 'Station Road',
      'address': 'Railway Station & Bus Stand Area, Ghatampur 209206',
    },
    {
      'label': 'Hospital Road',
      'address': 'Community Health Center Zone, Ghatampur 209206',
    },
    {
      'label': 'Nagar Palika Block',
      'address': 'Administrative Block, Ghatampur 209206',
    },
    {
      'label': 'Nehru Nagar Colony',
      'address': 'Residential Colony, Ghatampur 209206',
    },
    {
      'label': 'Mandi Samiti',
      'address': 'Grain & Vegetable Market, Kanpur Road, Ghatampur',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

        ref.read(selectedAddressProvider.notifier).state = detectedAddress;

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
              'phone': user.phone ?? '',
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
            content: Text('Could not access GPS. Please choose your area from list below.'),
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

  Future<void> _requestAddressFromFriend() async {
    HapticFeedback.lightImpact();
    final message = Uri.encodeComponent(
      'Hey! Please share your full delivery address (House No, Landmark & Pincode) so I can order groceries/food for you on FastKirana ⚡🛍️',
    );
    final uri = Uri.parse('https://wa.me/?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _selectLocality(Map<String, String> locality) {
    HapticFeedback.lightImpact();
    final address = Address(
      id: 'loc_${DateTime.now().millisecondsSinceEpoch}',
      label: locality['label']!,
      houseNo: '',
      street: locality['label']!,
      area: locality['label']!,
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

  void _selectSavedAddress(Address address) {
    HapticFeedback.lightImpact();
    ref.read(selectedAddressProvider.notifier).state = address;
    _proceedToApp();
  }

  Future<void> _proceedToApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_chosen_location', true);
    if (!mounted) return;
    if (widget.isInitialOnboarding || !Navigator.canPop(context)) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);
    final user = ref.watch(currentUserProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Rich, Realistic FastKirana Storefront Behind the Modal Sheet
          Positioned.fill(
            child: _buildStorefrontBackground(),
          ),

          // 2. Ambient Frosted Blur & Dim Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
              child: Container(
                color: const Color(0xFF0F172A).withOpacity(0.38),
              ),
            ),
          ),

          // 3. Main Interactive Location Selection Sheet Modal Container
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.90,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 28,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sheet Grab Handle
                      Center(
                        child: Container(
                          width: 38,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 1. Radar Animated Map Pin & Location Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFEFF6FF), // Soft Sky/Ice Blue
                              Color(0xFFF8FAFC),
                              Colors.white,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Column(
                          children: [
                            // Glowing Radar Rings around 3D Map Pin
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Outer Radar Ring
                                    Container(
                                      width: 78 * _pulseAnimation.value,
                                      height: 78 * _pulseAnimation.value,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryPinkRed.withOpacity(0.08 * (1.1 - (_pulseAnimation.value - 0.95))),
                                      ),
                                    ),
                                    // Middle Soft Ring
                                    Container(
                                      width: 66,
                                      height: 66,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryPinkRed.withOpacity(0.14),
                                      ),
                                    ),
                                    // 3D Floating Map Pin Circle
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF2D55),
                                            Color(0xFFE20A22),
                                            Color(0xFFB80517),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryPinkRed.withOpacity(0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Header Titles
                            Text(
                              'Location permission is off',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Enabling location helps us reach you quickly with accurate delivery estimates in Ghatampur',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Action Card (Use Current Location + Request from Friend)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Option 1: Use my Current Location
                            InkWell(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              onTap: _isDetectingLocation ? null : _detectGpsLocation,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.my_location_rounded,
                                          color: primaryPinkRed,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Use my Current Location',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Using GPS for exact doorstep delivery',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFFF2D55),
                                            Color(0xFFE20A22),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryPinkRed.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: _isDetectingLocation
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(
                                              'Enable',
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const Divider(height: 1, color: Color(0xFFF1F5F9)),

                            // Option 2: Request address from friend
                            InkWell(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                              onTap: _requestAddressFromFriend,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.chat_rounded,
                                          size: 18,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Request address from friend',
                                            style: GoogleFonts.inter(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Share via WhatsApp to get address details',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 3. Select your address Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select your address',
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                FadeSlideRoute(page: const AddressBookScreen()),
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  'See All',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: primaryPinkRed,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryPinkRed),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 4. Saved / Popular Localities List Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: addressesAsync.when(
                          data: (addresses) {
                            if (addresses.isNotEmpty) {
                              final displayList = addresses.take(2).toList();
                              return Column(
                                children: [
                                  for (int i = 0; i < displayList.length; i++) ...[
                                    _buildAddressTile(
                                      title: displayList[i].label,
                                      subtitle: '${displayList[i].houseNo}, ${displayList[i].street}, ${displayList[i].area}, ${displayList[i].city}',
                                      iconData: displayList[i].label.toLowerCase().contains('home')
                                          ? Icons.home_rounded
                                          : (displayList[i].label.toLowerCase().contains('work') ||
                                                  displayList[i].label.toLowerCase().contains('office'))
                                              ? Icons.work_rounded
                                              : Icons.location_on_outlined,
                                      isDefault: displayList[i].isDefault,
                                      onTap: () => _selectSavedAddress(displayList[i]),
                                      isLast: i == displayList.length - 1,
                                    ),
                                    if (i < displayList.length - 1)
                                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  ],
                                ],
                              );
                            }

                            // Fallback default Ghatampur hubs
                            return Column(
                              children: [
                                _buildAddressTile(
                                  title: user?.name?.isNotEmpty == true ? 'Home (${user!.name})' : 'Subhash Chowk (Central)',
                                  subtitle: 'Subhash Chowk, Main Market, Ghatampur, Kanpur Nagar 209206',
                                  iconData: Icons.home_rounded,
                                  isDefault: true,
                                  onTap: () => _selectLocality(_popularLocalities[0]),
                                ),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                _buildAddressTile(
                                  title: 'Station Road Hub',
                                  subtitle: 'Station Road, Near Railway Station, Ghatampur, Kanpur Nagar',
                                  iconData: Icons.location_city_rounded,
                                  onTap: () => _selectLocality(_popularLocalities[1]),
                                  isLast: true,
                                ),
                              ],
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: primaryPinkRed)),
                          ),
                          error: (_, __) => Column(
                            children: [
                              _buildAddressTile(
                                title: 'Subhash Chowk Hub',
                                subtitle: 'Main Market, Ghatampur, Kanpur Nagar 209206',
                                iconData: Icons.location_on_outlined,
                                onTap: () => _selectLocality(_popularLocalities[0]),
                              ),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              _buildAddressTile(
                                title: 'Station Road Hub',
                                subtitle: 'Near Railway Station, Ghatampur, Kanpur Nagar',
                                iconData: Icons.location_on_outlined,
                                onTap: () => _selectLocality(_popularLocalities[1]),
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 5. Search your Location Button
                      if (!_isSearching)
                        GestureDetector(
                          onTap: () => setState(() => _isSearching = true),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0F172A)),
                                const SizedBox(width: 8),
                                Text(
                                  'Search your Location',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Search Field when opened
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: primaryPinkRed, width: 1.3),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, size: 18, color: primaryPinkRed),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    hintText: 'Type your area or colony name...',
                                    hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _isSearching = false;
                                  });
                                },
                                child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: _popularLocalities
                                  .where((loc) =>
                                      loc['label']!.toLowerCase().contains(_searchQuery) ||
                                      loc['address']!.toLowerCase().contains(_searchQuery))
                                  .map((loc) => _buildAddressTile(
                                        title: loc['label']!,
                                        subtitle: loc['address']!,
                                        iconData: Icons.location_on_outlined,
                                        onTap: () => _selectLocality(loc),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🌟 Rich, Realistic Storefront Preview rendered under the modal
  Widget _buildStorefrontBackground() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Storefront Bar
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  const FastKiranaLogoWidget(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                              'Delivering in Ghatampur',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'FastKirana Store',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(
                          'FAST',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Realistic Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search "milk, bread, potato, chips..."',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(Icons.mic_none_rounded, size: 18, color: primaryPinkRed),
                ],
              ),
            ),
          ),

          // 3. Mode Toggle Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE20A22), Color(0xFFFF334B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          '🛍️ Grocery Mart',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '🍴 Food & Cafe',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Hero Banner Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 125,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE20A22), Color(0xFFFF4D62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: primaryPinkRed.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'GHATAMPUR EXPRESS ⚡',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fresh Fruits & Vegetables',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Delivered fast to your doorstep',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text('🥬🍎', style: TextStyle(fontSize: 38)),
                ],
              ),
            ),
          ),

          // 5. Category Circles Row Preview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Explore Categories',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMockCategoryItem('🥦', 'Veggies'),
                _buildMockCategoryItem('🥛', 'Dairy'),
                _buildMockCategoryItem('🍟', 'Snacks'),
                _buildMockCategoryItem('🥤', 'Drinks'),
                _buildMockCategoryItem('🍫', 'Sweets'),
                _buildMockCategoryItem('🧼', 'Cleaning'),
              ],
            ),
          ),

          // 6. Featured Products Grid Preview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Trending Essentials',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildMockProductCard(
                    title: 'Amul Taaza Milk 500ml',
                    price: '₹27',
                    emoji: '🥛',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMockProductCard(
                    title: 'Fresh Desi Tomatoes 1kg',
                    price: '₹35',
                    emoji: '🍅',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockCategoryItem(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Widget _buildMockProductCard({
    required String title,
    required String price,
    required String emoji,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32))),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  '+ ADD',
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF16A34A)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    IconData iconData = Icons.location_on_outlined,
    bool isDefault = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                iconData,
                size: 18,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: primaryPinkRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }
}
