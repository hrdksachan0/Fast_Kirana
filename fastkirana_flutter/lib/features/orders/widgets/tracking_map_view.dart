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
  final OutletLocation? primaryOutlet;
  final OutletLocation? restaurantOutlet;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitBounds;

  const TrackingMapView({
    super.key,
    required this.initialTarget,
    required this.isDelivered,
    required this.order,
    required this.markers,
    required this.polylines,
    this.primaryOutlet,
    this.restaurantOutlet,
    this.onMapCreated,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitBounds,
  });

  Widget _buildZoomBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, size: 18, color: const Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _buildRouteStep({
    required String emoji,
    required String label,
    required Color color,
    required BuildContext context,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: Responsive.scaledFontSize(context, 10.5),
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFCBD5E1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = order?.shopName ?? 'FastKirana Store';

    return RepaintBoundary(
      child: Column(
        children: [
          // ── Map Container ──
          Container(
            height: MediaQuery.sizeOf(context).height < 500
                ? MediaQuery.sizeOf(context).height * 0.38
                : 310,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Google Map with premium style
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 14.5,
                  ),
                  markers: markers,
                  polylines: polylines,
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

                // Top fade gradient for depth
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 40,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.5),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Live GPS Badge — top left
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF16A34A),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Live GPS',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 10),
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Zoom Controls — bottom right
                Positioned(
                  bottom: 14,
                  right: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildZoomBtn(icon: Icons.add_rounded, onTap: onZoomIn),
                      const SizedBox(height: 6),
                      _buildZoomBtn(icon: Icons.remove_rounded, onTap: onZoomOut),
                      const SizedBox(height: 6),
                      _buildZoomBtn(icon: Icons.fullscreen_rounded, onTap: onFitBounds),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Route Trail Bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: order?.isCombined == true
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRouteStep(
                          emoji: '🛒',
                          label: 'Darkstore',
                          color: const Color(0xFF15803D),
                          context: context,
                        ),
                        _buildArrow(),
                        _buildRouteStep(
                          emoji: '🍽️',
                          label: restaurantOutlet?.name ?? 'Kitchen',
                          color: const Color(0xFF7C3AED),
                          context: context,
                        ),
                        _buildArrow(),
                        _buildRouteStep(
                          emoji: '🛵',
                          label: '1 Rider',
                          color: const Color(0xFFEA580C),
                          context: context,
                        ),
                        _buildArrow(),
                        _buildRouteStep(
                          emoji: '🏠',
                          label: 'Home',
                          color: const Color(0xFFDC2626),
                          context: context,
                        ),
                      ],
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final rawName = primaryOutlet?.name ?? shopName;
                      String displayStoreName = rawName;
                      final lower = displayStoreName.toLowerCase();
                      if (lower.contains('dark store') || lower.contains('fastkirana')) {
                        displayStoreName = 'FastKirana';
                      } else if (lower.contains('a.s') || lower.contains('as ')) {
                        displayStoreName = 'A.S. Restaurant';
                      } else if (lower.contains('wedson')) {
                        displayStoreName = 'Wedson';
                      } else if (lower.contains('bal udyan') || lower.contains('baludyan')) {
                        displayStoreName = 'Bal Udyan';
                      }

                      final isRest = primaryOutlet?.isRestaurant == true;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRouteStep(
                            emoji: isRest ? '🍽️' : '🏪',
                            label: displayStoreName,
                            color: isRest ? const Color(0xFF7C3AED) : const Color(0xFF15803D),
                            context: context,
                          ),
                          _buildArrow(),
                          _buildRouteStep(
                            emoji: '🛵',
                            label: 'On the Way',
                            color: const Color(0xFFEA580C),
                            context: context,
                          ),
                          _buildArrow(),
                          _buildRouteStep(
                            emoji: '🏠',
                            label: 'Your Home',
                            color: const Color(0xFFDC2626),
                            context: context,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
