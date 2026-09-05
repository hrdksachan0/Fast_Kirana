import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../core/theme/responsive.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/address.dart';
import 'doorstep_details_screen.dart';

class MapPickerScreen extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen>
    with SingleTickerProviderStateMixin {
  // Store default coordinates (Ghatampur Central Hub)
  static const double storeLat = 26.1534185;
  static const double storeLng = 80.1714024;
  static const double maxRadiusKm = 5.0;

  late final MapController _mapController;
  late double _currentLat;
  late double _currentLng;

  bool _isLocating = false;
  String _areaName = 'Ghatampur Central';
  String _fullAddress = 'Ghatampur, Kanpur Nagar, Uttar Pradesh 209206, India';
  double _distanceKm = 0.0;
  bool _isServiceable = true;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  static const Color slateDark = AppDesignSystem.slate900;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentLat = widget.initialLat ?? storeLat;
    _currentLng = widget.initialLng ?? storeLng;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateLocationDetails(_currentLat, _currentLng);
    _fetchCurrentGpsLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  Future<void> _updateLocationDetails(double lat, double lng) async {
    final dist = _calculateDistance(storeLat, storeLng, lat, lng);
    final serviceable = dist <= maxRadiusKm;

    if (mounted) {
      setState(() {
        _currentLat = lat;
        _currentLng = lng;
        _distanceKm = dist;
        _isServiceable = serviceable;
      });
    }

    try {
      if (!kIsWeb) {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final area = place.subLocality?.isNotEmpty == true
              ? place.subLocality!
              : (place.locality?.isNotEmpty == true ? place.locality! : 'Ghatampur');
          final full = '${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? 'Ghatampur'}, ${place.postalCode ?? '209206'}, Uttar Pradesh, India'
              .replaceAll(RegExp(r',\s*,'), ',')
              .trim();

          setState(() {
            _areaName = area;
            _fullAddress = full.startsWith(',') ? full.substring(1).trim() : full;
          });
          return;
        }
      }
    } catch (e, _) { LoggerService.error('MapPickerScreen: silent catch', e); }

    if (mounted) {
      setState(() {
        _areaName = dist <= 0.8 ? 'Ghatampur Central' : 'Sihari / Ghatampur';
        _fullAddress = 'Ghatampur, Kanpur Nagar, Uttar Pradesh 209206, India';
      });
    }
  }

  Future<void> _fetchCurrentGpsLocation() async {
    setState(() => _isLocating = true);
    HapticFeedback.lightImpact();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );

        final target = LatLng(pos.latitude, pos.longitude);
        _mapController.move(target, 16.5);
        await _updateLocationDetails(pos.latitude, pos.longitude);
      }
    } catch (e, _) { LoggerService.error('MapPickerScreen: silent catch', e); }

    if (mounted) {
      setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.slate100,
      body: Stack(
        children: [
          // 1. 100% REAL INTERACTIVE OPENSTREETMAP / CARTO TILES VIEWPORT
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(_currentLat, _currentLng),
                initialZoom: 16.0,
                minZoom: 11.0,
                maxZoom: 18.5,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) {
                    _updateLocationDetails(camera.center.latitude, camera.center.longitude);
                  }
                },
              ),
              children: [
                // Clean high-resolution CartoDB Voyager map tiles
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fastkirana.app',
                ),

                // 5.0 KM Service Zone Circular Boundary
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: const LatLng(storeLat, storeLng),
                      radius: 5000,
                      useRadiusInMeter: true,
                      color: AppDesignSystem.green600.withValues(alpha: 0.08),
                      borderColor: AppDesignSystem.green600.withValues(alpha: 0.4),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. CENTER PIN MARKER WITH BOUNCING SHADOW (Swiggy Style)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating Tooltip Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isServiceable ? AppDesignSystem.slate900 : AppDesignSystem.red600,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isServiceable ? Icons.check_circle_rounded : Icons.warning_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isServiceable
                              ? 'Order will be delivered here'
                              : 'Outside 5.0 km Delivery Zone',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Pin Icon
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnim.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isServiceable ? AppDesignSystem.orange600 : AppDesignSystem.red600,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: (_isServiceable ? AppDesignSystem.orange600 : AppDesignSystem.red600)
                                .withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Pin Drop Shadow Dot
                  Container(
                    width: 14,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. TOP APP BAR & SEARCH BAR
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  // Back Button
                  Bounceable(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Search Pill
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 20, color: AppDesignSystem.orange600),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _areaName.isNotEmpty ? _areaName : 'Search area or address...',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 13.5),
                                fontWeight: FontWeight.w700,
                                color: slateDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. FLOATING "CURRENT LOCATION" BUTTON
          Positioned(
            right: 16,
            bottom: 230,
            child: Bounceable(
              onTap: _fetchCurrentGpsLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.orange600),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18, color: AppDesignSystem.orange600),
                    const SizedBox(width: 7),
                    Text(
                      'Current location',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12.5),
                        fontWeight: FontWeight.w800,
                        color: AppDesignSystem.orange600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. BOTTOM CONFIRMATION SHEET CARD (Swiggy Style)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 28,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Status
                    Text(
                      'Order will be delivered here',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 12),
                        fontWeight: FontWeight.w600,
                        color: AppDesignSystem.slate500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Area & Location Details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.orange50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 24,
                            color: AppDesignSystem.orange600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _areaName,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 17),
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.slate900,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fullAddress,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 12.5),
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

                    const SizedBox(height: 18),

                    // Confirm & Proceed Button
                    Bounceable(
                      onTap: () async {
                        if (!_isServiceable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppDesignSystem.red600,
                              content: Text('Delivery is available within 5.0 km of our active operational hub (${_distanceKm.toStringAsFixed(1)} km away)'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        HapticFeedback.mediumImpact();
                        final nav = Navigator.of(context);
                        final savedAddress = await nav.push<Address>(
                          FadeSlideRoute(
                            page: DoorstepDetailsScreen(
                              lat: _currentLat,
                              lng: _currentLng,
                              areaName: _areaName,
                              fullAddress: _fullAddress,
                            ),
                          ),
                        );

                        if (savedAddress != null && mounted) {
                          Navigator.pop(context, savedAddress);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppDesignSystem.orange600, AppDesignSystem.orange500],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.orange600.withValues(alpha: 0.38),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Confirm & proceed',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 15.5),
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
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
}

