import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/order.dart';

/// Premium clean map style — reduces label clutter, hides POIs, softens roads
const String _premiumMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","stylers":[{"visibility":"simplified"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#e8edf3"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#d4dbe5"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#f0f3f7"}]},
  {"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#f8fafc"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#dbeafe"}]},
  {"featureType":"landscape.natural","elementType":"geometry.fill","stylers":[{"color":"#f1f5f9"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.fill","stylers":[{"color":"#f8fafc"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#94a3b8"}]}
]
''';

class TrackingMapView extends StatelessWidget {
  final LatLng initialTarget;
  final bool isDelivered;
  final Order? order;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final OutletLocation? primaryOutlet;
  final OutletLocation? restaurantOutlet;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback onFitBounds;
  final String etaText;
  final String distanceText;
  final int statusStep;
  final bool isMapExpanded;
  final VoidCallback? onToggleExpand;

  const TrackingMapView({
    super.key,
    required this.initialTarget,
    required this.isDelivered,
    required this.order,
    required this.markers,
    required this.polylines,
    this.circles = const {},
    this.primaryOutlet,
    this.restaurantOutlet,
    this.onMapCreated,
    this.onZoomIn,
    this.onZoomOut,
    required this.onFitBounds,
    this.etaText = '',
    this.distanceText = '',
    this.statusStep = 3,
    this.isMapExpanded = false,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final rawShop = order?.shopName ?? 'FastMinute Store';
    final shopName = rawShop.replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute');

    final bool isOutForDelivery = statusStep >= 3;
    final String badgeTitle = isOutForDelivery
        ? (etaText.isNotEmpty ? 'Arriving in $etaText' : 'Out for Delivery')
        : (statusStep >= 2 ? 'Packed & Assigning' : 'Store Preparing');

    final String badgeSubtitle = isOutForDelivery
        ? (distanceText.isNotEmpty ? '$distanceText • Live GPS' : 'FastMinute Express')
        : 'Direct Store to Home Route';

    // Outlet display name
    final rawName = primaryOutlet?.name ?? shopName;
    String displayStoreName = rawName;
    final lower = displayStoreName.toLowerCase();
    if (lower.contains('dark store') || lower.contains('fastkirana') || lower.contains('fastminute')) {
      displayStoreName = 'FastMinute';
    } else if (lower.contains('a.s') || lower.contains('as ')) {
      displayStoreName = 'A.S. Rest';
    } else if (lower.contains('wedson')) {
      displayStoreName = 'Wedson';
    } else if (lower.contains('bal udyan') || lower.contains('baludyan')) {
      displayStoreName = 'Bal Udyan';
    }
    final isRest = primaryOutlet?.isRestaurant == true;

    return RepaintBoundary(
      child: Stack(
        children: [
          // ── 1. Google Map Viewport with Zero Gesture Conflict ──
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 14.2,
              ),
              markers: markers,
              polylines: polylines,
              circles: circles,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
              },
              style: _premiumMapStyle,
              onMapCreated: onMapCreated,
            ),
          ),

          // ── 2. Top Fade Gradient for Visual Clarity ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 50,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 3. Floating Live ETA Pill (Top-Left of Hero Map) ──
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pulsing Live Green Dot
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOutForDelivery ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
                      boxShadow: [
                        BoxShadow(
                          color: (isOutForDelivery ? const Color(0xFF16A34A) : const Color(0xFF0284C7)).withValues(alpha: 0.5),
                          blurRadius: 5,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        badgeTitle,
                        style: GoogleFonts.outfit(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        badgeSubtitle,
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 4. Floating Action Controls Column (Bottom-Right of Map) ──
          Positioned(
            bottom: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fullscreen / Shrink Toggle Button
                if (onToggleExpand != null) ...[
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isMapExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          size: 22,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Sleek Re-center FAB
                GestureDetector(
                  onTap: onFitBounds,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.my_location_rounded, size: 21, color: Color(0xFF00A344)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 5. Structured, Unified Route Progress Pill (Bottom Safe Dock, never collides with FAB) ──
          Positioned(
            bottom: 14,
            left: 14,
            right: 68, // Leaves 68px safe clearance for the FABs on the right!
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
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
                  // Origin Store Icon & Label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: (isRest ? const Color(0xFF7C3AED) : const Color(0xFF059669)).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            isRest ? Icons.restaurant_rounded : Icons.storefront_rounded,
                            size: 11,
                            color: isRest ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        displayStoreName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  // Connecting Progress Bar
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Base road line
                          Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          // Active animated colored line
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: isOutForDelivery ? 0.70 : (statusStep >= 2 ? 0.45 : 0.20),
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: isOutForDelivery ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ),
                          ),
                          // Middle Icon (Motorbike or Package)
                          Center(
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: isOutForDelivery ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isOutForDelivery ? const Color(0xFF10B981) : const Color(0xFF0284C7)).withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isOutForDelivery ? Icons.two_wheeler_rounded : Icons.inventory_2_rounded,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Destination Home Icon & Label
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.home_rounded,
                            size: 11,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Home',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
