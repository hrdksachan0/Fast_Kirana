import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/utils/restaurant_utils.dart';
import '../../../data/models/order.dart';

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

  Widget _buildMapCircleBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = order?.shopName ?? 'FastKirana Store';
    const slateBorder = Color(0xFFE2E8F0);
    const slateDark = Color(0xFF0F172A);

    return RepaintBoundary(
      child: Column(
        children: [
          Container(
            height: MediaQuery.sizeOf(context).height < 500
                ? MediaQuery.sizeOf(context).height * 0.35
                : 290,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: slateBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 14.0,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                  },
                  onMapCreated: onMapCreated,
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: slateBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live GPS Active',
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
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMapCircleBtn(icon: Icons.add_rounded, onTap: onZoomIn),
                      const SizedBox(height: 6),
                      _buildMapCircleBtn(icon: Icons.remove_rounded, onTap: onZoomOut),
                      const SizedBox(height: 6),
                      _buildMapCircleBtn(icon: Icons.crop_free_rounded, onTap: onFitBounds),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: slateBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                            const SizedBox(width: 4),
                            Text(
                              'Darkstore',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                            const SizedBox(width: 4),
                            Text(
                              restaurantOutlet?.name ?? 'Kitchen',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                            const SizedBox(width: 4),
                            Text(
                              '1 Rider',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🏠', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                            const SizedBox(width: 4),
                            Text(
                              'Home',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 11),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(isRest ? '🍽️' : '🏪', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                              const SizedBox(width: 4),
                              Text(
                                displayStoreName,
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: isRest ? const Color(0xFF7C3AED) : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                              const SizedBox(width: 4),
                              Text(
                                'On the Way',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🏠', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                              const SizedBox(width: 4),
                              Text(
                                'Your Home',
                                style: GoogleFonts.inter(
                                  fontSize: Responsive.scaledFontSize(context, 11),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ],
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
