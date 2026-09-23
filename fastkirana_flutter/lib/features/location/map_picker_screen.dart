import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fastkirana_flutter/core/theme/design_system.dart';
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
import '../../core/services/map_tile_cache_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/routes/page_transitions.dart';
import '../../data/models/address.dart';
import '../../data/models/store_hub.dart';
import '../../providers/store_hub_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/hub_conflict_dialog.dart';
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
  late final MapController _mapController;
  late double _currentLat;
  late double _currentLng;

  bool _isLocating = false;
  String _areaName = 'Locating area...';
  String _fullAddress = 'Fetching address...';
  double _distanceKm = 0.0;
  bool _isServiceable = true;
  StoreHub? _matchedHub;
  List<StoreHub> _activeHubs = [];

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  static const Color slateDark = AppDesignSystem.slate900;

  String _calculateEtaText(double distanceKm) {
    if (distanceKm <= 2.5) return '10-15 mins';
    if (distanceKm <= 4.5) return '15-25 mins';
    return '20-30 mins';
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    const defaultHub = StoreHub.defaultGhatampur;
    _currentLat = widget.initialLat ?? defaultHub.latitude;
    _currentLng = widget.initialLng ?? defaultHub.longitude;
    _matchedHub = defaultHub;
    _activeHubs = StoreHub.defaultHubs;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hubs = ref.read(activeStoreHubsProvider).valueOrNull ?? StoreHub.defaultHubs;
      setState(() => _activeHubs = hubs);
      _updateLocationDetails(_currentLat, _currentLng);
    });

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
    final hubs = _activeHubs.isNotEmpty
        ? _activeHubs
        : (ref.read(activeStoreHubsProvider).valueOrNull ?? StoreHub.defaultHubs);

    StoreHub nearest = hubs.first;
    double minDistanceKm = double.infinity;
    StoreHub? matchedZoneHub;

    for (final hub in hubs) {
      if (!hub.isActive) continue;
      final dist = _calculateDistance(hub.latitude, hub.longitude, lat, lng);
      if (hub.isPointInsideGeofence(lat, lng) || dist <= hub.deliveryRadiusKm) {
        matchedZoneHub = hub;
      }
      if (dist < minDistanceKm) {
        minDistanceKm = dist;
        nearest = hub;
      }
    }

    final activeHub = matchedZoneHub ?? nearest;
    final distKm = matchedZoneHub != null
        ? _calculateDistance(matchedZoneHub.latitude, matchedZoneHub.longitude, lat, lng)
        : minDistanceKm;
    final serviceable = matchedZoneHub != null;

    if (mounted) {
      setState(() {
        _currentLat = lat;
        _currentLng = lng;
        _distanceKm = distKm;
        _isServiceable = serviceable;
        _matchedHub = activeHub;
        _activeHubs = hubs;
      });
    }

    try {
      if (!kIsWeb) {
        final placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final area = place.subLocality?.isNotEmpty == true
              ? place.subLocality!
              : (place.locality?.isNotEmpty == true ? place.locality! : activeHub.city);
          final full = '${place.name ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? activeHub.city}, ${place.postalCode ?? (activeHub.city.toLowerCase().contains('akbarpur') ? '224122' : '209206')}, Uttar Pradesh, India'
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
        _areaName = distKm <= 1.0 ? '${activeHub.city} Central' : '${activeHub.city} Area';
        _fullAddress = '${activeHub.name}, ${activeHub.city}, Uttar Pradesh, India';
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

  void _openAreaSearchSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AreaSearchModal(
        currentArea: _areaName,
        onLocationSelected: (lat, lng, name, address) {
          final target = LatLng(lat, lng);
          _mapController.move(target, 16.8);
          _updateLocationDetails(lat, lng);
        },
      ),
    );
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
                // Clean high-resolution CartoDB / OSM tiles with offline disk caching
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fastkirana.app',
                  tileProvider: CachedMapTileProvider(),
                ),

                // Dynamic Multi-Hub Service Zone Circular Boundaries
                CircleLayer(
                  circles: (_activeHubs.isNotEmpty ? _activeHubs : StoreHub.defaultHubs).map((hub) {
                    final isThisMatched = _matchedHub?.id == hub.id;
                    final isInsideThis = _isServiceable && isThisMatched;
                    return CircleMarker(
                      point: LatLng(hub.latitude, hub.longitude),
                      radius: (hub.deliveryRadiusKm * 1000).toDouble(),
                      useRadiusInMeter: true,
                      color: isInsideThis
                          ? AppDesignSystem.green600.withValues(alpha: 0.12)
                          : (isThisMatched
                              ? AppDesignSystem.orange600.withValues(alpha: 0.09)
                              : const Color(0xFF6366F1).withValues(alpha: 0.05)),
                      borderColor: isInsideThis
                          ? AppDesignSystem.green600.withValues(alpha: 0.75)
                          : (isThisMatched
                              ? AppDesignSystem.orange600.withValues(alpha: 0.5)
                              : const Color(0xFF6366F1).withValues(alpha: 0.35)),
                      borderStrokeWidth: isThisMatched ? 2.5 : 1.5,
                    );
                  }).toList(),
                ),

                // Hub Center Markers with Badges
                MarkerLayer(
                  markers: (_activeHubs.isNotEmpty ? _activeHubs : StoreHub.defaultHubs).map((hub) {
                    return Marker(
                      point: LatLng(hub.latitude, hub.longitude),
                      width: 110,
                      height: 52,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppDesignSystem.slate900,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🏪', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 3),
                                Text(
                                  '${hub.city} Hub',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: AppDesignSystem.slate900, size: 14),
                        ],
                      ),
                    );
                  }).toList(),
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
                          _isServiceable ? Icons.bolt_rounded : Icons.warning_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isServiceable
                              ? '⚡ ~${_calculateEtaText(_distanceKm)} • ${_distanceKm.toStringAsFixed(1)} km (${_matchedHub?.name ?? "Hub"})'
                              : '🟠 ${(_distanceKm - (_matchedHub?.deliveryRadiusKm ?? 5.0)).clamp(0.1, 99.0).toStringAsFixed(1)} km outside zone (${_matchedHub?.city ?? "Hub"})',
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

          // 3. TOP APP BAR & SEARCH BAR + QUICK HUB CHIPS
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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

                      // Search Pill (Interactive Area Search)
                      Expanded(
                        child: Bounceable(
                          onTap: _openAreaSearchSheet,
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
                                    _areaName.isNotEmpty ? _areaName : 'Search area, colony or landmark...',
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 13.5),
                                      fontWeight: FontWeight.w700,
                                      color: slateDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFF7ED),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    size: 14,
                                    color: AppDesignSystem.orange600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Quick Store Hub Pills
                  if (_activeHubs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _activeHubs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final hub = _activeHubs[index];
                          final isSelected = _matchedHub?.id == hub.id;
                          return Bounceable(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _mapController.move(LatLng(hub.latitude, hub.longitude), 15.5);
                              _updateLocationDetails(hub.latitude, hub.longitude);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppDesignSystem.slate900 : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppDesignSystem.slate900 : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isSelected ? '📍 ' : '🏪 ',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    '${hub.city} Hub',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? Colors.white : AppDesignSystem.slate800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${hub.deliveryRadiusKm.toInt()}km)',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white70 : AppDesignSystem.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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

                    const SizedBox(height: 12),

                    // Live Delivery ETA & Distance Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isServiceable ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isServiceable ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isServiceable ? Icons.bolt_rounded : Icons.info_outline_rounded,
                            size: 16,
                            color: _isServiceable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isServiceable
                                  ? '⚡ ~${_calculateEtaText(_distanceKm)} Delivery • ${_distanceKm.toStringAsFixed(1)} km from ${_matchedHub?.name ?? "Hub"}'
                                  : 'Outside active zone (${_distanceKm.toStringAsFixed(1)} km to nearest hub)',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11.5),
                                fontWeight: FontWeight.w700,
                                color: _isServiceable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

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

                        final nav = Navigator.of(context);

                        // Smart Cart Protection: Check if user has grocery items from a different hub
                        if (_matchedHub != null) {
                          final conflictingHubId = ref.read(cartProvider.notifier).checkHubConflict(_matchedHub!.id);
                          if (conflictingHubId != null) {
                            final currentHub = ref.read(currentStoreHubProvider);
                            final proceed = await HubConflictDialog.show(
                              context,
                              oldHubName: currentHub.name,
                              newHubName: _matchedHub!.name,
                            );
                            if (!proceed || !mounted) return;
                          }
                        }

                        HapticFeedback.mediumImpact();
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

                        if (savedAddress != null && context.mounted) {
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

// ---------------------------------------------------------------------------
// Realtime Interactive Area Search Modal (Nominatim Geocoding + Quick Area Chips)
// ---------------------------------------------------------------------------
class _AreaSearchModal extends StatefulWidget {
  final String currentArea;
  final void Function(double lat, double lng, String name, String address) onLocationSelected;

  const _AreaSearchModal({
    required this.currentArea,
    required this.onLocationSelected,
  });

  @override
  State<_AreaSearchModal> createState() => _AreaSearchModalState();
}

class _AreaSearchModalState extends State<_AreaSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Popular local shops, markets, medical stores, & landmarks in Ghatampur / Sihari
  static const List<Map<String, dynamic>> popularAreas = [
    // Local Shops & Markets
    {
      'title': 'Ghatampur Sabzi Mandi',
      'subtitle': 'Daily Fresh Vegetable & Fruit Market, Ghatampur, 209206',
      'lat': 26.1528,
      'lng': 80.1702,
      'tag': 'Market',
    },
    {
      'title': 'Purana Bazaar / Cloth Market',
      'subtitle': 'Main Market Road, Near Chowk, Ghatampur, 209206',
      'lat': 26.1542,
      'lng': 80.1720,
      'tag': 'Market',
    },
    {
      'title': 'Mishra Mishthan Bhandar',
      'subtitle': 'Famous Sweet Shop, Chowk, Ghatampur, 209206',
      'lat': 26.1538,
      'lng': 80.1718,
      'tag': 'Shop',
    },
    {
      'title': 'Gupta Kirana Store',
      'subtitle': 'Grocery Store, Sihari Road, Ghatampur, 209206',
      'lat': 26.1575,
      'lng': 80.1670,
      'tag': 'Shop',
    },
    {
      'title': 'Verma Medical Store',
      'subtitle': 'Chemist & Druggist, Hospital Road, Ghatampur, 209206',
      'lat': 26.1548,
      'lng': 80.1735,
      'tag': 'Medical',
    },
    {
      'title': 'Community Health Centre (CHC) Hospital',
      'subtitle': 'Government Hospital Road, Ghatampur, 209206',
      'lat': 26.1550,
      'lng': 80.1742,
      'tag': 'Hospital',
    },
    {
      'title': 'State Bank of India (SBI) Branch',
      'subtitle': 'Bank Road, Near Tehsil, Ghatampur, 209206',
      'lat': 26.1560,
      'lng': 80.1705,
      'tag': 'Bank',
    },
    {
      'title': 'Ghatampur Bus Stand',
      'subtitle': 'UPSRTC Bus Stand, NH34, Ghatampur, 209206',
      'lat': 26.1525,
      'lng': 80.1725,
      'tag': 'Transit',
    },
    {
      'title': 'Railway Station Ghatampur',
      'subtitle': 'North Central Railway, Station Road, 209206',
      'lat': 26.1480,
      'lng': 80.1760,
      'tag': 'Transit',
    },
    // Akbarpur Hub Landmarks
    {
      'title': 'Akbarpur Tehsil & Court',
      'subtitle': 'Main Tehsil Complex, Akbarpur, Ambedkar Nagar, 224122',
      'lat': 26.4380,
      'lng': 82.5400,
      'tag': 'Landmark',
    },
    {
      'title': 'Akbarpur Railway Station',
      'subtitle': 'Station Road, Akbarpur Junction, 224122',
      'lat': 26.4420,
      'lng': 82.5480,
      'tag': 'Transit',
    },
    {
      'title': 'Shahzadpur Main Market',
      'subtitle': 'Cloth, Electronics & Grocery Bazaar, Akbarpur, 224122',
      'lat': 26.4310,
      'lng': 82.5360,
      'tag': 'Market',
    },
    {
      'title': 'Patel Nagar Akbarpur',
      'subtitle': 'Residential Colony, Near Bus Station, Akbarpur, 224122',
      'lat': 26.4350,
      'lng': 82.5420,
      'tag': 'Colony',
    },
    {
      'title': 'Dostpur Road Akbarpur',
      'subtitle': 'Dostpur Bypass Road, Akbarpur, 224122',
      'lat': 26.4280,
      'lng': 82.5330,
      'tag': 'Area',
    },
    {
      'title': 'Kushmanda Devi Mandir',
      'subtitle': 'Ancient Pilgrimage Temple, Ghatampur, 209206',
      'lat': 26.1585,
      'lng': 80.1785,
      'tag': 'Landmark',
    },
    {
      'title': 'Sihari Village / Gram',
      'subtitle': 'Sihari, Ghatampur Delivery Zone, 209206',
      'lat': 26.1601,
      'lng': 80.1650,
      'tag': 'Area',
    },
    {
      'title': 'Jahanabad Road Bypass',
      'subtitle': 'NH34 / Jahanabad Crossing, Ghatampur, 209206',
      'lat': 26.1450,
      'lng': 80.1620,
      'tag': 'Zone',
    },
    {
      'title': 'Tehsil Campus / SDM Office',
      'subtitle': 'Administrative Complex, Ghatampur, 209206',
      'lat': 26.1555,
      'lng': 80.1690,
      'tag': 'Civil',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final dio = Dio();
      final List<Map<String, dynamic>> results = [];
      final lower = query.toLowerCase();

      // 1. Immediate Match with Local Shops & Landmarks (Instant response for local businesses)
      final localMatches = popularAreas.where((p) {
        final t = (p['title'] as String).toLowerCase();
        final s = (p['subtitle'] as String).toLowerCase();
        final tag = (p['tag'] as String).toLowerCase();
        return t.contains(lower) || s.contains(lower) || tag.contains(lower);
      }).toList();
      results.addAll(localMatches);

      // 2. OpenStreetMap / Nominatim with Bounding Box around Ghatampur
      // viewbox: minLon, maxLat, maxLon, minLat (covers Ghatampur, Sihari, surrounding areas)
      try {
        final response = await dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {
            'q': query.contains('ghatampur') ? query : '$query, Ghatampur',
            'format': 'json',
            'addressdetails': 1,
            'limit': 8,
            'countrycodes': 'in',
            'viewbox': '80.05,26.25,80.30,26.05',
            'bounded': 0, // Prefer nearby within 15km
          },
          options: Options(
            headers: {'User-Agent': 'FastKirana-Mobile/1.0 (support@fastkirana.in)'},
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

        if (response.statusCode == 200 && response.data is List) {
          for (final item in (response.data as List)) {
            final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            final displayName = (item['display_name'] ?? '').toString();
            final addr = item['address'] as Map<String, dynamic>?;
            final title = addr?['shop'] ??
                addr?['amenity'] ??
                addr?['suburb'] ??
                addr?['village'] ??
                addr?['neighbourhood'] ??
                addr?['road'] ??
                displayName.split(',').first;

            if (lat != 0.0 && lon != 0.0) {
              final alreadyAdded = results.any((r) =>
                  ((r['lat'] as num) - lat).abs() < 0.001 &&
                  ((r['lng'] as num) - lon).abs() < 0.001);

              if (!alreadyAdded) {
                results.add({
                  'title': title.toString().trim(),
                  'subtitle': displayName,
                  'lat': lat,
                  'lng': lon,
                });
              }
            }
          }
        }
      } catch (_) {}

      // 3. If still empty, try broader query on Nominatim
      if (results.isEmpty) {
        try {
          final broadResp = await dio.get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {
              'q': query,
              'format': 'json',
              'addressdetails': 1,
              'limit': 5,
              'countrycodes': 'in',
            },
            options: Options(
              headers: {'User-Agent': 'FastKirana-Mobile/1.0 (support@fastkirana.in)'},
              sendTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
            ),
          );

          if (broadResp.statusCode == 200 && broadResp.data is List) {
            for (final item in (broadResp.data as List)) {
              final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
              final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
              final displayName = (item['display_name'] ?? '').toString();
              final title = displayName.split(',').first;

              if (lat != 0.0 && lon != 0.0) {
                results.add({
                  'title': title.trim(),
                  'subtitle': displayName,
                  'lat': lat,
                  'lng': lon,
                });
              }
            }
          }
        } catch (_) {}
      }

      // 4. Fallback to native geocoding if still empty
      if (results.isEmpty && !kIsWeb) {
        try {
          final locations = await locationFromAddress('$query, UP');
          for (final loc in locations.take(3)) {
            results.add({
              'title': query,
              'subtitle': '$query, Uttar Pradesh, India',
              'lat': loc.latitude,
              'lng': loc.longitude,
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final lower = query.toLowerCase();
        final fallback = popularAreas.where((p) {
          final t = (p['title'] as String).toLowerCase();
          return t.contains(lower);
        }).toList();

        setState(() {
          _searchResults = fallback;
          _isLoading = false;
        });
      }
    }
  }

  void _selectLocation(double lat, double lng, String title, String subtitle) {
    HapticFeedback.selectionClick();
    Navigator.pop(context);
    widget.onLocationSelected(lat, lng, title, subtitle);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Delivery Area',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 17),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Type colony, road, landmark or pincode',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 11.5),
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),

          // Search Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _performSearch,
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 14),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Try "Sihari", "Bypass", "Station Road"...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13),
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppDesignSystem.orange600, size: 22),
                  suffixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppDesignSystem.orange600),
                          ),
                        )
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Popular Area Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchResults.isEmpty ? 'QUICK AREAS' : 'RESULTS',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 10.5),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // List View of Search Results or Quick Areas
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (_searchResults.isEmpty && _searchController.text.isEmpty) ...[
                  // Show Popular Localities
                  ...popularAreas.map((area) {
                    final lat = (area['lat'] as num).toDouble();
                    final lng = (area['lng'] as num).toDouble();
                    final title = area['title'] as String;
                    final subtitle = area['subtitle'] as String;
                    final tag = area['tag'] as String;

                    return Bounceable(
                      onTap: () => _selectLocation(lat, lng, title, subtitle),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.location_on_rounded, size: 18, color: AppDesignSystem.orange600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.inter(
                                          fontSize: Responsive.scaledFontSize(context, 13.5),
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tag,
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      color: const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else if (_searchResults.isNotEmpty) ...[
                  ..._searchResults.map((item) {
                    final lat = (item['lat'] as num).toDouble();
                    final lng = (item['lng'] as num).toDouble();
                    final title = (item['title'] ?? '').toString();
                    final subtitle = (item['subtitle'] ?? '').toString();

                    return Bounceable(
                      onTap: () => _selectLocation(lat, lng, title, subtitle),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                          boxShadow: [
                            BoxShadow(
                              color: AppDesignSystem.orange600.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.place_rounded, size: 18, color: AppDesignSystem.orange600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 13.5),
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: Responsive.scaledFontSize(context, 11.5),
                                      color: const Color(0xFF64748B),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppDesignSystem.orange600),
                          ],
                        ),
                      ),
                    );
                  }),
                ] else if (!_isLoading && _searchController.text.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.location_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 8),
                        Text(
                          'No matching areas found',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13.5),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You can also drag the map pin directly to your doorstep',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11.5),
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
