import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import '../../core/services/location_service.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';

class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  static const Color primaryRed = Color(0xFFDC2626);
  bool _isFetchingGps = false;
  Address? _currentGpsAddress;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(addressesProvider.notifier).loadAddresses());
  }

  Future<void> _fetchAndUseGpsLocation() async {
    HapticFeedback.lightImpact();
    setState(() => _isFetchingGps = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        if (mounted) {
          setState(() => _isFetchingGps = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: const Text(
                'Please enable GPS / Location permission on your device.',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          );
        }
        return;
      }

      final details = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
      final user = ref.read(authProvider).value;

      final prefs = await SharedPreferences.getInstance();
      final currentPhone = user?.phone ?? prefs.getString('user_phone') ?? '';

      final gpsAddress = Address(
        id: 'addr_gps_live',
        userId: user?.id ?? prefs.getString('user_id') ?? '',
        label: '📍 Current Location',
        houseNo: details.houseNo.isNotEmpty ? details.houseNo : 'Near Pinpoint',
        street: details.street.isNotEmpty ? details.street : 'GPS Detected Road',
        area: details.area.isNotEmpty ? details.area : 'Ghatampur Market',
        city: details.city.isNotEmpty ? details.city : 'Kanpur Nagar',
        pincode: details.pincode.isNotEmpty ? details.pincode : '209206',
        phone: currentPhone,
        latitude: pos.latitude,
        longitude: pos.longitude,
        isDefault: true,
      );

      if (mounted) {
        setState(() {
          _isFetchingGps = false;
          _currentGpsAddress = gpsAddress;
        });

        ref.read(selectedAddressProvider.notifier).state = gpsAddress;

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📍 Set to Current Location: ${details.formattedAddress}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingGps = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              'Failed to fetch GPS location: $e',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);
    final selectedAddress = ref.watch(selectedAddressProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Saved Addresses',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ResponsiveContainer(
        maxWidth: Responsive.formMaxContentWidth,
        fillHeight: true,
        child: Column(
          children: [
            // 1. Delivery Zone Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Express Delivery Zone',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                      Text(
                        'Delivering across Ghatampur (Pincode: 209206)',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── 1-TAP GPS AUTO-DETECT CARD ───
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectedAddress?.id == 'addr_gps_live'
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFE2E8F0),
                width: selectedAddress?.id == 'addr_gps_live' ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isFetchingGps
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 2.2),
                        )
                      : const Icon(Icons.my_location_rounded, color: Color(0xFF16A34A), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isFetchingGps ? 'Detecting Live GPS Pinpoint...' : '📍 Deliver to Current GPS Location',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentGpsAddress != null
                            ? _currentGpsAddress!.fullAddress
                            : 'Auto-detect exact house & street in Ghatampur',
                        style: GoogleFonts.inter(
                          fontSize: 11,
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
                ElevatedButton(
                  onPressed: _isFetchingGps ? null : _fetchAndUseGpsLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedAddress?.id == 'addr_gps_live' ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text(
                    selectedAddress?.id == 'addr_gps_live' ? 'SELECTED' : 'FETCH',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                              color: isSelected ? primaryRed : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? primaryRed.withOpacity(0.08) : Colors.black.withOpacity(0.04),
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
                                      ? const Color(0xFFFEF2F2)
                                      : isWork
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFF0FDF4),
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
                                      ? const Color(0xFFDC2626)
                                      : isWork
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF16A34A),
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
                                            fontSize: 14.5,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (addr.isDefault || isSelected) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? primaryRed.withOpacity(0.1) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isSelected ? 'ACTIVE' : 'DEFAULT',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: isSelected ? primaryRed : const Color(0xFF64748B),
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF475569),
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (addr.phone.isNotEmpty) ...[
                                          const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                                          const SizedBox(width: 4),
                                          Text(
                                            addr.phone,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                        ],
                                        Text(
                                          '•  Pincode: ${addr.pincode}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showMapLocationPicker(context, editAddress: addr);
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
                                        Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                        SizedBox(width: 8),
                                        Text('Set Active Delivery'),
                                      ],
                                    ),
                                  ),
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
                                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                        SizedBox(width: 8),
                                        Text('Delete Address', style: TextStyle(color: Color(0xFFEF4444))),
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
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load saved addresses',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        err.toString().replaceAll('Exception: ', ''),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
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
                  color: Colors.black.withOpacity(0.05),
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
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showMapLocationPicker(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_location_alt_rounded, size: 19, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Add New Delivery Address',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
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
      bgTint: const Color(0xFFFFF0F0),
      onCta: () {
        HapticFeedback.lightImpact();
        _showMapLocationPicker(context);
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
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

  // Map-First Simplified Address Bottom Sheet (Zepto / Blinkit Style)
  void _showMapLocationPicker(BuildContext context, {Address? editAddress}) {
    final houseCtrl = TextEditingController(text: editAddress?.houseNo ?? '');
    final landmarkCtrl = TextEditingController(text: editAddress?.street ?? '');
    String area = editAddress?.area ?? 'Central Market';
    String city = editAddress?.city ?? 'Ghatampur';
    String pincode = editAddress?.pincode ?? '209206';
    String phone = editAddress?.phone ?? '';
    String selectedTag = editAddress?.label ?? 'Home';
    bool isSaving = false;
    bool isLocating = false;
    double currentLat = editAddress?.latitude ?? 26.1534185;
    double currentLng = editAddress?.longitude ?? 80.1714024;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: primaryRed, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  editAddress != null ? 'Edit Address' : 'Select Delivery Location',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Ghatampur Express Zone • 10-15 Min Delivery',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Map & Location Prioritized Hero Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: primaryRed,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.my_location_rounded, size: 16, color: Colors.white),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$area, $city',
                                            style: GoogleFonts.inter(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Pincode: $pincode • Kanpur Nagar',
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // GPS Auto-Detect Button
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    setSheetState(() => isLocating = true);
                                    try {
                                      final pos = await LocationService.getCurrentPosition();
                                      if (pos != null) {
                                        final loc = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
                                        setSheetState(() {
                                          currentLat = pos.latitude;
                                          currentLng = pos.longitude;
                                          if (loc.houseNo.isNotEmpty) houseCtrl.text = loc.houseNo;
                                          if (loc.street.isNotEmpty) landmarkCtrl.text = loc.street;
                                          area = loc.area.isNotEmpty ? loc.area : area;
                                          city = loc.city.isNotEmpty ? loc.city : city;
                                          pincode = loc.pincode.isNotEmpty ? loc.pincode : pincode;
                                        });
                                      }
                                    } finally {
                                      setSheetState(() => isLocating = false);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isLocating)
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed),
                                          )
                                        else
                                          const Icon(Icons.gps_fixed_rounded, size: 14, color: primaryRed),
                                        const SizedBox(width: 8),
                                        Text(
                                          isLocating ? 'Locating on Map...' : 'Refetch GPS Location 🎯',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: primaryRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 2. Simplified Field 1: Flat / House No
                          _buildFieldLabel('House / Flat / Floor / Building No. *'),
                          const SizedBox(height: 6),
                          _buildTextField(houseCtrl, 'e.g. Flat 302, Royal Residency / Shop #12'),

                          const SizedBox(height: 14),

                          // 3. Simplified Field 2: Landmark
                          _buildFieldLabel('Nearby Landmark (Optional)'),
                          const SizedBox(height: 6),
                          _buildTextField(landmarkCtrl, 'e.g. Near Subhash Chowk / Clock Tower'),

                          const SizedBox(height: 18),

                          // 4. Save Address As Tag Selector
                          _buildFieldLabel('Save Address As'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildTagChip('Home', '🏠', selectedTag, (val) => setSheetState(() => selectedTag = val)),
                              const SizedBox(width: 10),
                              _buildTagChip('Work', '🏢', selectedTag, (val) => setSheetState(() => selectedTag = val)),
                              const SizedBox(width: 10),
                              _buildTagChip('Other', '📍', selectedTag, (val) => setSheetState(() => selectedTag = val)),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 5. Save & Deliver CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final house = houseCtrl.text.trim();
                                      final landmark = landmarkCtrl.text.trim();

                                      if (house.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter your House / Flat number')),
                                        );
                                        return;
                                      }

                                       if (phone.isEmpty) {
                                         final user = ref.read(currentUserProvider);
                                         final prefs = await SharedPreferences.getInstance();
                                         phone = user?.phone ?? prefs.getString('user_phone') ?? '';
                                       }

                                      setSheetState(() => isSaving = true);
                                      HapticFeedback.heavyImpact();

                                      try {
                                        final payload = {
                                          if (editAddress != null) 'id': editAddress.id,
                                          'label': selectedTag,
                                          'houseNo': house,
                                          'street': landmark.isNotEmpty ? landmark : area,
                                          'area': area,
                                          'city': city,
                                          'pincode': pincode,
                                          'phone': phone,
                                          'lat': currentLat,
                                          'lng': currentLng,
                                          'isDefault': true,
                                        };

                                        if (editAddress != null) {
                                          await ref.read(addressesProvider.notifier).updateAddress(payload);
                                        } else {
                                          await ref.read(addressesProvider.notifier).addAddress(payload);
                                        }

                                        if (mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: const Color(0xFF15803D),
                                              content: Row(
                                                children: const [
                                                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Delivery address saved successfully!'),
                                                ],
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: const Color(0xFFEF4444),
                                              content: Text(e.toString().replaceAll('Exception: ', '')),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } finally {
                                        setSheetState(() => isSaving = false);
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    )
                                  : Text(
                                      editAddress != null ? 'Update Address' : 'Save Address & Deliver Here ➔',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, String emoji, String selectedTag, ValueChanged<String> onSelect) {
    final isSelected = selectedTag.toLowerCase() == label.toLowerCase();
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onSelect(label);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryRed : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? primaryRed : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}