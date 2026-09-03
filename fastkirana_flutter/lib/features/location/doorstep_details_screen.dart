import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/responsive.dart';
import '../../data/models/address.dart';
import '../../providers/auth_provider.dart';
import '../../providers/address_provider.dart';

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

  bool _useAccountDetails = true;
  String _selectedCategory = 'House'; // 'House' | 'Office' | 'Other'
  final Set<String> _selectedInstructions = {};
  bool _isSaving = false;

  static const Color primaryOrange = Color(0xFFEA580C);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _customLabelController.text = 'Home';

    final user = ref.read(authProvider).value;
    if (user != null) {
      _receiverNameController.text = user.name?.isNotEmpty == true ? user.name! : 'Customer';
      _receiverPhoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _houseNoController.dispose();
    _streetController.dispose();
    _customLabelController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
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

  Future<void> _handleSaveAddress() async {
    final houseNo = _houseNoController.text.trim();
    if (houseNo.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Please enter Building / House / Floor No.', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final user = ref.read(authProvider).value;
      final receiverPhone = _useAccountDetails
          ? (user?.phone ?? '')
          : _receiverPhoneController.text.trim();

      final label = _customLabelController.text.trim().isNotEmpty
          ? _customLabelController.text.trim()
          : _selectedCategory;

      final street = _streetController.text.trim();

      final savedAddress = await ref.read(addressesProvider.notifier).addAddress({
        'label': label,
        'houseNo': houseNo,
        'street': street.isNotEmpty ? street : widget.areaName,
        'area': widget.areaName,
        'city': 'Ghatampur',
        'pincode': '209206',
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
        final localAddress = Address(
          id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'local',
          label: _customLabelController.text.trim().isNotEmpty ? _customLabelController.text.trim() : _selectedCategory,
          houseNo: _houseNoController.text.trim(),
          street: _streetController.text.trim().isNotEmpty ? _streetController.text.trim() : widget.areaName,
          area: widget.areaName,
          city: 'Ghatampur',
          pincode: '209206',
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
    final accountPhone = (user?.phone != null && user!.phone!.isNotEmpty) ? user.phone! : '+91 70544 70303';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
              widget.areaName,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 15),
                fontWeight: FontWeight.w800,
                color: slateDark,
              ),
            ),
            Text(
              widget.fullAddress,
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
          child: Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.04),
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
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 18),
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
                                          color: const Color(0xFF0F172A),
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
                                          'YOU',
                                          style: GoogleFonts.inter(
                                            fontSize: Responsive.scaledFontSize(context, 9),
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF16A34A),
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
                                      color: const Color(0xFF15803D),
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
                                  border: Border.all(color: const Color(0xFF86EFAC)),
                                ),
                                child: Text(
                                  'Edit',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 11.5),
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF16A34A),
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
                          border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
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
                                      color: const Color(0xFF16A34A),
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
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFFED7AA)),
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
                                    color: const Color(0xFFF8FAFC),
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
                                            const Text('🇮🇳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 14))),
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
                                              color: const Color(0xFF94A3B8),
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
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: slateBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Tabs Pill (House / Office / Other)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
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

                      // Building / Floor
                      _buildInputField(
                        controller: _houseNoController,
                        label: 'Building / Floor *',
                        hint: 'Flat no., House no., Floor, Building',
                      ),

                      const SizedBox(height: 12),

                      // Street (Recommended)
                      _buildInputField(
                        controller: _streetController,
                        label: 'Street (Recommended)',
                        hint: 'Street name, lane, or landmark',
                      ),

                      const SizedBox(height: 12),

                      // Area / Locality with Map Thumbnail & Change Button
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Area / Locality',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11),
                                      fontWeight: FontWeight.w600,
                                      color: slateMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.fullAddress,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 12),
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Bounceable(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFED7AA)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 16, color: primaryOrange),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Change',
                                      style: GoogleFonts.inter(
                                        fontSize: Responsive.scaledFontSize(context, 10),
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
                      ),

                      const SizedBox(height: 12),

                      // Save address as
                      _buildInputField(
                        controller: _customLabelController,
                        label: 'Save address as *',
                        hint: 'e.g. Home, Shop, Dukan',
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
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
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
                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryOrange.withValues(alpha: 0.38),
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
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12.5),
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 11),
              fontWeight: FontWeight.w600,
              color: slateMuted,
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 13.5),
              fontWeight: FontWeight.w700,
              color: slateDark,
            ),
            decoration: InputDecoration(
              icon: icon != null ? Icon(icon, size: 18, color: slateMuted) : null,
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w400,
                color: const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
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
          color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryOrange : const Color(0xFFE2E8F0),
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
