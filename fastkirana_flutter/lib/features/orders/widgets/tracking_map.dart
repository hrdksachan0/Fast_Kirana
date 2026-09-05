import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackingMap extends StatelessWidget {
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Function(GoogleMapController) onMapCreated;
  final VoidCallback? onRecenter;

  const TrackingMap({
    super.key,
    required this.initialPosition,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
    this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: 15.0,
            ),
            markers: markers,
            polylines: polylines,
            onMapCreated: onMapCreated,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
          ),
          if (onRecenter != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter_map_btn',
                backgroundColor: Colors.white,
                foregroundColor: AppDesignSystem.slate900,
                elevation: 4,
                onPressed: onRecenter,
                child: const Icon(Icons.my_location_rounded, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}
