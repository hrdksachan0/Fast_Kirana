import 'package:fastminute_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/address.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/store_hub.dart';
import '../../providers/store_hub_provider.dart';
import '../../core/utils/address_formatter.dart';

class DoorstepDetailsScreen extends ConsumerStatefulWidget {
  final double lat;
  final double lng;
  final String areaName;
  final String fullAddress;

  const DoorstepDetailsScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.areaName,
    required this.fullAddress,
  });

  @override
  ConsumerState<DoorstepDetailsScreen> createState() => _DoorstepDetailsScreenState();
}

class _DoorstepDetailsScreenState extends ConsumerState<DoorstepDetailsScreen> {
  final _houseNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _customLabelController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _houseNoFocusNode = FocusNode();
  bool _hasHouseNoError = false;

  bool _useAccountDetails = true;
  String _selectedCategory = 'House'; // 'House' | 'Office' | 'Other'
  final Set<String> _selectedInstructions = {};
  bool _isSaving = false;

  static const Color primaryOrange = AppDesignSystem.orange600;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;

  @override
  void initState() {
    super.initState();
    _customLabelController.text = 'Home';
    _houseNoController.addListener(() {
      if (_hasHouseNoError && _houseNoController.text.trim().isNotEmpty) {
        setState(() => _hasHouseNoError = false);
      }
    });
    _houseNoFocusNode.addListener(() { if (mounted) setState(() {}); });

    final user = ref.read(authProvider).value;
    if (user != null) {
      _receiverNameController.text = user.name?.isNotEmpty == true ? user.name! : 'Customer';
      final cleanP = (user.phone ?? '').replaceAll('+91', '').replaceAll(' ', '').trim();
      _receiverPhoneController.text = cleanP;
    }
    if (_receiverPhoneController.text.isEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        final savedPhone = prefs.getString('user_phone') ?? '';
        final cleanP = savedPhone.replaceAll('+91', '').replaceAll(' ', '').trim();
        if (cleanP.isNotEmpty && mounted && _receiverPhoneController.text.isEmpty) {
          setState(() {
            _receiverPhoneController.text = cleanP;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _houseNoController.dispose();
    _streetController.dispose();
    _customLabelController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _houseNoFocusNode.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
      if (category == 'House') {
        _customLabelController.text = 'Home';
      } else if (category == 'Office') {
        _customLabelController.text = 'Work';
      } else {
        _customLabelController.text = 'Other';
      }
    });
  }

  void _showHouseNumberRequiredSheet() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.home_work_rounded, color: Color(0xFFE20A22), size: 28),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Where should we deliver?',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 17),
                fontWeight: FontWeight.w800,
                color: slateDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please enter your House or Flat number so our delivery hero reaches your exact doorstep.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w500,
                color: slateMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Bounceable(
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _hasHouseNoError = true);
                _houseNoFocusNode.requestFocus();
              },
              child: Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE20A22), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Enter House Number',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 14.5),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _handleSaveAddress() async {
    final houseNo = _houseNoController.text.trim();
    if (houseNo.isEmpty) {
      _showHouseNumberRequiredSheet();
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final hubs = ref.read(activeStoreHubsProvider).valueOrNull ?? StoreHub.defaultHubs;
    StoreHub matchedHub = ref.read(currentStoreHubProvider);
    double minDist = double.infinity;
    for (final h in hubs) {
      final d = Geolocator.distanceBetween(h.latitude, h.longitude, widget.lat, widget.lng);
      if (d < minDist) {
        minDist = d;
        matchedHub = h;
      }
    }
    final addressPincodeMatch = RegExp(r'\b[1-9][0-9]{5}\b').firstMatch(widget.fullAddress)?.group(0);
    final hubIdPin = RegExp(r'\b\d{6}\b').firstMatch(matchedHub.id)?.group(0);
    final resolvedCity = matchedHub.city;
    final resolvedPincode = addressPincodeMatch ??
        hubIdPin ??
        (matchedHub.id.contains('224122')
            ? '224122'
            : (matchedHub.id.contains('816107') ? '816107' : '209206'));

    try {
      final user = ref.read(authProvider).value;
      final receiverPhone = _useAccountDetails
          ? (user?.phone ?? '')
          : _receiverPhoneController.text.trim();

      final label = _customLabelController.text.trim().isNotEmpty
          ? _customLabelController.text.trim()
          : _selectedCategory;

      final street = _streetController.text.trim();

      final cleanArea = AddressFormatter.extractAreaName(
        widget.fullAddress,
        fallback: widget.areaName,
      );

      final savedAddress = await ref.read(addressesProvider.notifier).addAddress({
        'label': label,
        'houseNo': houseNo,
        'street': street.isNotEmpty ? street : cleanArea,
        'area': cleanArea,
        'city': resolvedCity,
        'pincode': resolvedPincode,
        'phone': receiverPhone,
        'lat': widget.lat,
        'lng': widget.lng,
        'latitude': widget.lat,
        'longitude': widget.lng,
        'isDefault': true,
      });

      // Save chosen location flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_chosen_location', true);

      // Set active address
      ref.read(selectedAddressProvider.notifier).state = savedAddress;

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, savedAddress);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final cleanArea = AddressFormatter.extractAreaName(
          widget.fullAddress,
          fallback: widget.areaName,
        );
        final localAddress = Address(
          id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'local',
          label: _customLabelController.text.trim().isNotEmpty ? _customLabelController.text.trim() : _selectedCategory,
          houseNo: _houseNoController.text.trim(),
          street: _streetController.text.trim().isNotEmpty ? _streetController.text.trim() : cleanArea,
          area: cleanArea,
          city: resolvedCity,
          pincode: resolvedPincode,
          phone: _receiverPhoneController.text.trim(),
          latitude: widget.lat,
          longitude: widget.lng,
          isDefault: true,
        );
        ref.read(selectedAddressProvider.notifier).state = localAddress;
        Navigator.pop(context, localAddress);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final accountName = user?.name?.isNotEmpty == true ? user!.name! : 'My Account';
    final userPhone = (user?.phone != null && user!.phone!.trim().isNotEmpty) ? user.phone!.trim() : '';
    final accountPhone = userPhone.isNotEmpty
        ? (userPhone.startsWith('+91') ? userPhone : '+91 $userPhone')
        : (_receiverPhoneController.text.trim().isNotEmpty
            ? '+91 ${_receiverPhoneController.text.trim()}'
            : 'Delivery Mobile Number');

    final cleanSingleLine = AddressFormatter.formatCleanSingleLine(
      widget.fullAddress,
      areaFallback: widget.areaName,
    );
    final cleanAreaName = AddressFormatter.extractAreaName(
      widget.fullAddress,
      fallback: widget.areaName,
    );
    final currentHub = ref.watch(currentStoreHubProvider);
    final addressPincodeMatch = RegExp(r'\b[1-9][0-9]{5}\b').firstMatch(widget.fullAddress)?.group(0);
    final resolvedCity = currentHub.city;
    final resolvedPincode = addressPincodeMatch ?? '209206';

    String displaySubtitle = cleanSingleLine;
    if (displaySubtitle.isEmpty || displaySubtitle == cleanAreaName || RegExp(r'^[0-9]+$').hasMatch(displaySubtitle)) {
      displaySubtitle = '$cleanAreaName, $resolvedCity - $resolvedPincode';
    } else if (!displaySubtitle.toLowerCase().contains(resolvedCity.toLowerCase())) {
      displaySubtitle = '$displaySubtitle, $resolvedCity - $resolvedPincode';
    }

    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 22),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cleanAreaName,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 15),
                fontWeight: FontWeight.w800,
                color: slateDark,
              ),
            ),
            Text(
              displaySubtitle,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 11),
                fontWeight: FontWeight.w500,
                color: slateMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppDesignSystem.slate100),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: Responsive.formMaxContentWidth,
          fillHeight: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. RECEIVER DETAILS CARD (Frictionless Swiggy Style)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Receiver Details',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: slateDark,
                      ),
                    ),
                    if (_useAccountDetails)
                      Bounceable(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _useAccountDetails = false);
                        },
                        child: Text(
                          '+ Order for someone else',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 12),
                            fontWeight: FontWeight.w700,
                            color: primaryOrange,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                _useAccountDetails
                    ? Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.green50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppDesignSystem.green200),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.green600.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppDesignSystem.green100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: AppDesignSystem.green600, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        accountName,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 13.5),
                                          fontWeight: FontWeight.w800,
                                          color: AppDesignSystem.slate900,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppDesignSystem.green100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9),
                                            fontWeight: FontWeight.w900,
                                            color: AppDesignSystem.green600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '📞 $accountPhone • Delivery updates sent here',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w600,
                                      color: AppDesignSystem.green700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Bounceable(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _useAccountDetails = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppDesignSystem.emerald200),
                                ),
                                child: Text(
                                  'Edit',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w800,
                                    color: AppDesignSystem.green600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppDesignSystem.orange300, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: primaryOrange.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Enter Receiver Info',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w800,
                                    color: slateDark,
                                  ),
                                ),
                                Bounceable(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _useAccountDetails = true;
                                      _receiverNameController.text = accountName;
                                      _receiverPhoneController.text = accountPhone;
                                    });
                                  },
                                  child: Text(
                                    'Use my details instead',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      fontWeight: FontWeight.w700,
                                      color: AppDesignSystem.green600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Receiver Name Field
                            _buildInputField(
                              controller: _receiverNameController,
                              label: 'Receiver Name *',
                              hint: 'e.g. Rahul / Mom / Office Desk',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 12),

                            // Phone Number Field with Pinned +91 and 1-Tap Paste
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Receiver Mobile Number *',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 12),
                                        fontWeight: FontWeight.w700,
                                        color: slateDark,
                                      ),
                                    ),
                                    // 1-Tap Paste Button
                                    Bounceable(
                                      onTap: () async {
                                        HapticFeedback.lightImpact();
                                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                                        if (data?.text != null) {
                                          final clean = data!.text!.replaceAll(RegExp(r'[^0-9]'), '');
                                          final phone10 = clean.length > 10 ? clean.substring(clean.length - 10) : clean;
                                          if (phone10.isNotEmpty) {
                                            setState(() {
                                              _receiverPhoneController.text = phone10;
                                            });
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppDesignSystem.orange50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppDesignSystem.orange300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.content_paste_rounded, size: 12, color: primaryOrange),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Paste number',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                                fontWeight: FontWeight.w800,
                                                color: primaryOrange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppDesignSystem.slate50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: slateBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      // Pinned +91 Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: const BoxDecoration(
                                          border: Border(right: BorderSide(color: slateBorder)),
                                        ),
                                        child: Row(
                                          children: [
                                            Text('🇮🇳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
                                            const SizedBox(width: 5),
                                            Text(
                                              '+91',
                                              style: GoogleFonts.inter(
                                                fontSize: Responsive.scaledFontSize(context, 13),
                                                fontWeight: FontWeight.w800,
                                                color: slateDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // 10-Digit Input
                                      Expanded(
                                        child: TextField(
                                          controller: _receiverPhoneController,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                          ],
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 14),
                                            fontWeight: FontWeight.w700,
                                            color: slateDark,
                                            letterSpacing: 1.0,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '98765 43210',
                                            hintStyle: GoogleFonts.inter(
                                              fontSize: Responsive.scaledFontSize(context, 13),
                                              fontWeight: FontWeight.w500,
                                              color: AppDesignSystem.slate400,
                                              letterSpacing: 0,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 20),

                // 2. LOCATION DETAILS CARD (Swiggy Style)
                Text(
                  'Location Details',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w800,
                    color: slateDark,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppDesignSystem.slate200, width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Category Tabs (House / Office / Other)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.slate100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildCategoryPill('House', Icons.home_outlined),
                            _buildCategoryPill('Office', Icons.business_outlined),
                            _buildCategoryPill('Other', Icons.near_me_outlined),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. MODERN FLOATING-LABEL LUXURY CARD (Blinkit / Zepto Pro Style)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _hasHouseNoError
                                ? const Color(0xFFEF4444)
                                : (_houseNoFocusNode.hasFocus
                                    ? const Color(0xFFE20A22)
                                    : const Color(0xFFE2E8F0)),
                            width: _hasHouseNoError || _houseNoFocusNode.hasFocus ? 1.6 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _hasHouseNoError
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                  : (_houseNoFocusNode.hasFocus
                                      ? const Color(0xFFE20A22).withValues(alpha: 0.10)
                                      : Colors.black.withValues(alpha: 0.03)),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Micro Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.home_outlined,
                                      size: 15,
                                      color: _hasHouseNoError
                                          ? const Color(0xFFEF4444)
                                          : (_houseNoFocusNode.hasFocus
                                              ? const Color(0xFFE20A22)
                                              : const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Enter Your Address',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10),
                                        fontWeight: FontWeight.w800,
                                        color: _hasHouseNoError
                                            ? const Color(0xFFEF4444)
                                            : (_houseNoFocusNode.hasFocus
                                                ? const Color(0xFFE20A22)
                                                : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _hasHouseNoError
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'Required',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 9.5),
                                      fontWeight: FontWeight.w800,
                                      color: _hasHouseNoError
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Clean High-Contrast Input with Zero Nested Border Glitch
                            TextField(
                              controller: _houseNoController,
                              focusNode: _houseNoFocusNode,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 15),
                                fontWeight: FontWeight.w700,
                                color: slateDark,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'e.g. Flat 402, House 12, 2nd Floor',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13.5),
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF94A3B8),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasHouseNoError) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                              const SizedBox(width: 5),
                              Text(
                                'Please enter your Flat / House number or Landmark',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11.5),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // 3. Area / Locality details card with [Change]
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded, size: 18, color: primaryOrange),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Area / Locality',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w600,
                                      color: AppDesignSystem.slate500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displaySubtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12.5),
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                    maxLines: 2,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Bounceable(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFED7AA)),
                                ),
                                child: Text(
                                  'Change',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11),
                                    fontWeight: FontWeight.w800,
                                    color: primaryOrange,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 4. Save address as
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark_outline_rounded, size: 20, color: Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _customLabelController,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 13.5),
                                  fontWeight: FontWeight.w700,
                                  color: slateDark,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Save address as (e.g. Home, Work)',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 13),
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. DELIVERY INSTRUCTIONS (Swiggy Style)
                Row(
                  children: [
                    Text(
                      'Delivery Instructions',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 14),
                        fontWeight: FontWeight.w800,
                        color: slateDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(Recommended)',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInstructionChip('🚪 Leave at door'),
                    _buildInstructionChip('🔔 Don\'t ring bell'),
                    _buildInstructionChip('📞 Call before delivery'),
                    _buildInstructionChip('🤫 Baby sleeping / Avoid calling'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      // STICKY BOTTOM SAVE & DELIVER HERE BUTTON
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppDesignSystem.slate100)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Bounceable(
            onTap: _isSaving ? null : _handleSaveAddress,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE20A22), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE20A22).withValues(alpha: 0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Save Address & Deliver Here ➔',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 15.5),
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String category, IconData icon) {
    final isSelected = _selectedCategory == category;

    return Expanded(
      child: Bounceable(
        onTap: () => _onCategorySelected(category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppDesignSystem.slate900 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppDesignSystem.slate500,
              ),
              const SizedBox(width: 6),
              Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppDesignSystem.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11),
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.slate500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppDesignSystem.slate400),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w700,
                    color: slateDark,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 12.5),
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                    ),
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionChip(String text) {
    final isSelected = _selectedInstructions.contains(text);

    return Bounceable(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedInstructions.remove(text);
          } else {
            _selectedInstructions.add(text);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppDesignSystem.orange50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryOrange : AppDesignSystem.slate200,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 11.5),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? primaryOrange : slateDark,
          ),
        ),
      ),
    );
  }
}
