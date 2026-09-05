import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/design_system.dart';
import '../../data/models/address.dart';
import '../../providers/address_provider.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  final Address? initialAddress;
  const AddAddressScreen({super.key, this.initialAddress});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen>
    with SingleTickerProviderStateMixin {
  final _houseController = TextEditingController();
  final _streetController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController(text: 'Kanpur Nagar');
  final _pincodeController = TextEditingController(text: '209206');
  final _phoneController = TextEditingController();

  int _selectedTypeIndex = 0; // 0: Home, 1: Work, 2: Friends, 3: Other
  bool _isDefault = true;
  bool _isLocatingGps = false;
  bool _isSaving = false;

  double _latitude = AppConfig.darkstoreLat;
  double _longitude = AppConfig.darkstoreLng;
  double _distanceKm = 0.8;
  bool _isServiceable = true;
  String _detectedFormattedAddress = 'FastKirana Central Zone, Kanpur Nagar - 209206';

  late AnimationController _pinPulseController;
  late Animation<double> _pinScaleAnimation;

  static const Color primaryRed = AppDesignSystem.primary;
  static const Color brandGreen = AppDesignSystem.green700;
  static const Color slateDark = AppDesignSystem.slate900;
  static const Color slateMuted = AppDesignSystem.slate500;
  static const Color slateBorder = AppDesignSystem.slate200;

  final List<Map<String, dynamic>> _addressTypes = const [
    {'label': 'Home', 'icon': Icons.home_rounded, 'tag': 'Home'},
    {'label': 'Work', 'icon': Icons.work_rounded, 'tag': 'Work'},
    {'label': 'Friends & Family', 'icon': Icons.favorite_rounded, 'tag': 'Friends'},
    {'label': 'Other', 'icon': Icons.location_on_rounded, 'tag': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _pinPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pinScaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pinPulseController, curve: Curves.easeInOut),
    );

    if (widget.initialAddress != null) {
      final a = widget.initialAddress!;
      _houseController.text = a.houseNo;
      _streetController.text = a.street;
      _areaController.text = a.area;
      _cityController.text = a.city;
      _pincodeController.text = a.pincode;
      _phoneController.text = a.phone;
      _latitude = a.latitude ?? AppConfig.darkstoreLat;
      _longitude = a.longitude ?? AppConfig.darkstoreLng;
      _isDefault = a.isDefault;
      _detectedFormattedAddress = a.fullAddress;
    } else {
      _loadSavedPhone();
      _fetchCurrentGpsLocation(isSilent: true);
    }
  }

  Future<void> _loadSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('user_phone') ?? '';
    final clean = saved.replaceAll('+91', '').replaceAll(' ', '').trim();
    if (clean.isNotEmpty && _phoneController.text.isEmpty) {
      setState(() => _phoneController.text = clean);
    }
  }

  @override
  void dispose() {
    _pinPulseController.dispose();
    _houseController.dispose();
    _streetController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentGpsLocation({bool isSilent = false}) async {
    if (!isSilent) HapticFeedback.mediumImpact();
    setState(() => _isLocatingGps = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final details = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _latitude = pos.latitude;
            _longitude = pos.longitude;
            _distanceKm = details.distanceKm;
            _isServiceable = details.isServiceable;
            _detectedFormattedAddress = details.formattedAddress;

            if (details.houseNo.isNotEmpty && details.houseNo != '.') {
              _houseController.text = details.houseNo;
            }
            if (details.street.isNotEmpty && details.street != '.') {
              _streetController.text = details.street;
            }
            if (details.area.isNotEmpty && details.area != '.') {
              _areaController.text = details.area;
            }
            if (details.city.isNotEmpty && details.city != '.') {
              _cityController.text = details.city;
            }
            if (details.pincode.isNotEmpty && details.pincode != '.') {
              _pincodeController.text = details.pincode;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('GPS detection notice: $e');
    } finally {
      if (mounted) setState(() => _isLocatingGps = false);
    }
  }

  Future<void> _handleSaveAddress() async {
    final house = _houseController.text.trim();
    final street = _streetController.text.trim();
    final area = _areaController.text.trim();
    final city = _cityController.text.trim();
    final pincode = _pincodeController.text.trim();
    final phone = _phoneController.text.trim();
    final landmark = _landmarkController.text.trim();

    if (house.isEmpty) {
      _showToast('Please enter House / Flat / Floor number', isError: true);
      return;
    }

    if (street.isEmpty && area.isEmpty) {
      _showToast('Please enter Street / Society or Area name', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'usr_current';
      final label = _addressTypes[_selectedTypeIndex]['tag'] as String;

      final addressData = {
        if (widget.initialAddress != null) 'id': widget.initialAddress!.id,
        'userId': userId,
        'label': label,
        'houseNo': house,
        'street': street.isNotEmpty ? street : 'Main Road',
        'area': area.isNotEmpty ? area : 'Express Zone',
        'landmark': landmark,
        'city': city.isNotEmpty ? city : 'Kanpur Nagar',
        'pincode': pincode.isNotEmpty ? pincode : '209206',
        'phone': phone,
        'lat': _latitude,
        'lng': _longitude,
        'isDefault': _isDefault,
      };

      Address saved;
      if (widget.initialAddress != null) {
        saved = await ref.read(addressesProvider.notifier).updateAddress(addressData);
      } else {
        saved = await ref.read(addressesProvider.notifier).addAddress(addressData);
      }

      // Automatically select as current delivery address
      ref.read(selectedAddressProvider.notifier).state = saved;

      HapticFeedback.heavyImpact();
      if (mounted) {
        _showToast('Address saved & selected for delivery! 🎉', isError: false);
        Navigator.pop(context, saved);
      }
    } catch (e) {
      debugPrint('Save address error: $e');
      if (mounted) _showToast('Could not save address. Please retry.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? primaryRed : brandGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.slate50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppDesignSystem.slate100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.initialAddress != null ? 'Edit Delivery Address' : 'Select Delivery Location',
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 16),
            fontWeight: FontWeight.w900,
            color: slateDark,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Interactive Pinned Radar Map Viewfinder
                  _buildInteractiveMapPinboard(),

                  // 2. Doorstep Address Details Form
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENTER COMPLETE ADDRESS',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w900,
                            color: slateMuted,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Save As Type Chips
                        _buildAddressTypeSelector(),
                        const SizedBox(height: 16),

                        // House / Flat No
                        _buildInputField(
                          controller: _houseController,
                          label: 'House / Flat / Floor No. *',
                          hint: 'e.g. Flat 402, 4th Floor, Tower B',
                          icon: Icons.home_work_rounded,
                        ),
                        const SizedBox(height: 12),

                        // Apartment / Street Name
                        _buildInputField(
                          controller: _streetController,
                          label: 'Apartment / Road / Society *',
                          hint: 'e.g. Shanti Nagar, Main Market Road',
                          icon: Icons.signpost_rounded,
                        ),
                        const SizedBox(height: 12),

                        // Area & Landmark
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _areaController,
                                label: 'Area / Locality',
                                hint: 'e.g. Central Zone',
                                icon: Icons.map_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildInputField(
                                controller: _landmarkController,
                                label: 'Landmark (Optional)',
                                hint: 'e.g. Near Shiv Mandir',
                                icon: Icons.flag_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // City & Pincode
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _cityController,
                                label: 'City',
                                hint: 'Kanpur Nagar',
                                icon: Icons.location_city_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildInputField(
                                controller: _pincodeController,
                                label: 'Pincode',
                                hint: '209206',
                                icon: Icons.pin_drop_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Phone Number
                        _buildInputField(
                          controller: _phoneController,
                          label: 'Receiver Contact Number',
                          hint: '10-digit mobile number',
                          icon: Icons.phone_rounded,
                          keyboardType: TextInputType.phone,
                          prefixText: '+91 ',
                        ),
                        const SizedBox(height: 16),

                        // Default Address Switch
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: slateBorder),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isDefault,
                            onChanged: (v) => setState(() => _isDefault = v),
                            title: Text(
                              'Set as default delivery address',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13),
                                fontWeight: FontWeight.w700,
                                color: slateDark,
                              ),
                            ),
                            activeColor: primaryRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Sticky Bottom Deliver Here Button
          _buildStickyBottomBar(),
        ],
      ),
    );
  }

  /// 🌟 Interactive Map Pinboard (Blinkit / Zepto Style)
  Widget _buildInteractiveMapPinboard() {
    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppDesignSystem.slate900,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated Radar Grid Background
          CustomPaint(
            size: const Size(double.infinity, 230),
            painter: _RadarGridPainter(),
          ),

          // Animated Central Pinned Marker
          ScaleTransition(
            scale: _pinScaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Tooltip Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppDesignSystem.lime500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isServiceable ? 'Order Delivers Here' : 'Outside Service Zone',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Red Pin Head with Glow
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryRed,
                    boxShadow: [
                      BoxShadow(
                        color: primaryRed.withValues(alpha: 0.6),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                  ),
                ),
                // Pin Point Shadow
                Container(
                  width: 12,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),

          // Top Info Pill (Location String)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: primaryRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _detectedFormattedAddress,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w700,
                        color: slateDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.green100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_distanceKm.toStringAsFixed(1)} KM',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w900,
                        color: AppDesignSystem.green700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Right GPS Auto-Detect Button
          Positioned(
            bottom: 12,
            right: 16,
            child: GestureDetector(
              onTap: _isLocatingGps ? null : () => _fetchCurrentGpsLocation(isSilent: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isLocatingGps
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryRed),
                          )
                        : const Icon(Icons.gps_fixed_rounded, size: 14, color: primaryRed),
                    const SizedBox(width: 6),
                    Text(
                      _isLocatingGps ? 'Locating...' : 'Use Current GPS',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11),
                        fontWeight: FontWeight.w800,
                        color: slateDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: slateBorder),
      ),
      child: Row(
        children: List.generate(_addressTypes.length, (index) {
          final isSelected = _selectedTypeIndex == index;
          final item = _addressTypes[index];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTypeIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppDesignSystem.rose50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? primaryRed : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 16,
                      color: isSelected ? primaryRed : slateMuted,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 10),
                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected ? primaryRed : slateMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 10.5),
              fontWeight: FontWeight.w800,
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
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 12.5),
                fontWeight: FontWeight.w500,
                color: AppDesignSystem.slate400,
              ),
              prefixText: prefixText,
              prefixStyle: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 13.5),
                fontWeight: FontWeight.w800,
                color: slateDark,
              ),
              suffixIcon: Icon(icon, size: 18, color: AppDesignSystem.slate400),
              suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSaveAddress,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Save & Deliver Here',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 14.5),
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
    );
  }
}

/// Custom Canvas Painter for Map Radar Grid
class _RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final paintGrid = Paint()
      ..color = AppDesignSystem.slate700.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric Radar Rings
    for (double r = 30; r < size.width; r += 45) {
      canvas.drawCircle(center, r, paintGrid);
    }

    // Grid Cross Lines
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paintGrid);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paintGrid);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}