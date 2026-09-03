import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../core/theme/responsive.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/banner_provider.dart';
import '../../widgets/sponsored_ad_card.dart';
import '../profile/add_review_screen.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  final Order? initialOrder;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  Order? _order;
  bool _isLoading = true;
  bool _isRealtimeConnected = false;
  String _etaText = 'Calculating ETA...';
  String _distanceText = '';

  // Google Maps state
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _riderPosition;
  LatLng? _customerPosition;
  LatLng? _storePosition;
  LatLng? _restaurantPosition; // Dedicated for restaurant in combined orders
  OutletLocation? _primaryOutlet;
  OutletLocation? _restaurantOutlet; // Dedicated for combined orders
  double _riderHeading = 0.0;

  // Custom Rich Bitmap Markers (Store 🏪, Restaurant 🍽️, Rider 🛵, Home 🏠)
  BitmapDescriptor? _storeMarkerIcon;
  BitmapDescriptor? _restaurantMarkerIcon;
  BitmapDescriptor? _riderMarkerIcon;
  BitmapDescriptor? _customerMarkerIcon;

  // Subscriptions & Timers
  RealtimeChannel? _supabaseChannel;
  Timer? _pollTimer;
  Timer? _etaUpdateTimer;
  StreamSubscription<String>? _sseLineSubscription;
  Razorpay? _razorpay;
  bool _isProcessingPayment = false;

  // Animation controller for smooth rider marker movement
  late AnimationController _riderAnimController;
  LatLng? _prevRiderPosition;
  LatLng? _targetRiderPosition;

  // Confetti for Delivery Celebration
  late ConfettiController _confettiController;

  static const Color primaryRed = Color(0xFFE20A22);
  static const Color brandGreen = Color(0xFF00A344);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color slateBorder = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _isLoading = false;
      _setupCoordinatesFromOrder(widget.initialOrder!);
    }

    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _riderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(_interpolateRiderMarker);

    _initCustomMarkers();
    _checkAndRequestLocationPermission();
    _initRazorpay();
    _fetchLiveOrder();
    _initSupabaseRealtime();

    // Fallback polling every 8 seconds to back up Supabase Realtime WebSocket
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _silentPollOrder();
    });
  }

  Future<void> _checkAndRequestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _etaUpdateTimer?.cancel();
    _sseLineSubscription?.cancel();
    _riderAnimController.dispose();
    _confettiController.dispose();
    _mapController?.dispose();
    _razorpay?.clear();
    SupabaseService.unsubscribe(_supabaseChannel);
    super.dispose();
  }

  void _initRazorpay() {
    try {
      _razorpay = Razorpay();
      _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    } catch (e) {
      debugPrint('Razorpay init error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    HapticFeedback.heavyImpact();
    setState(() => _isProcessingPayment = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/api/orders/${widget.orderId}', data: {
        'paymentStatus': 'PAID',
        'paymentMethod': 'UPI',
      });
      await _fetchLiveOrder();
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: brandGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 Payment Received! Order #${widget.orderId} is now PAID.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating paid status: $e');
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            'Payment Incomplete: ${response.message ?? "Transaction cancelled"}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _payOrderOnline() async {
    final grandTotal = _order?.total ?? 0.0;
    if (grandTotal <= 0) return;

    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final phone = _order?.customerPhone ?? prefs.getString('user_phone') ?? '';
    final email = prefs.getString('user_email') ?? 'customer@fastkirana.in';

    final options = {
      'key': AppConfig.razorpayKeyId,
      'amount': (grandTotal * 100).toInt(),
      'name': 'FastKirana Express',
      'description': 'Order Payment #${_order?.readableId ?? widget.orderId}',
      'prefill': {
        'contact': phone,
        'email': email,
      },
      'theme': {
        'color': '#00A344',
      },
    };

    try {
      _razorpay?.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text('Could not open payment gateway: $e'),
        ),
      );
    }
  }

  /// Initialize Supabase Realtime subscription for live location and order status updates
  Future<void> _initSupabaseRealtime() async {
    try {
      await SupabaseService.initialize();
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      _supabaseChannel = SupabaseService.subscribeToOrderLocation(
        orderId: cleanId,
        onLocationUpdate: (locationData) {
          if (!mounted) return;
          final lat = locationData['lat'] as double?;
          final lng = locationData['lng'] as double?;
          final heading = (locationData['heading'] as num?)?.toDouble() ?? 0.0;

          if (lat != null && lng != null) {
            _updateRiderLocation(LatLng(lat, lng), heading);
          }
        },
        onStatusUpdate: (newStatusStr) {
          if (!mounted) return;
          debugPrint('[OrderTracking] Realtime status change: $newStatusStr');
          _fetchLiveOrder();
        },
      );

      if (_supabaseChannel != null && mounted) {
        setState(() => _isRealtimeConnected = true);
      }
    } catch (e) {
      debugPrint('[OrderTracking] Supabase realtime init warning: $e');
    }
  }

  Future<void> _fetchLiveOrder() async {
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      final order = await repo.getOrder(cleanId);
      if (mounted) {
        final prevStatus = _order?.status;
        setState(() {
          _order = order;
          _isLoading = false;
        });

        if (order.status == OrderStatus.delivered && prevStatus != OrderStatus.delivered) {
          _confettiController.play();
          HapticFeedback.heavyImpact();
        }

        _setupCoordinatesFromOrder(order);
      }
    } catch (e) {
      debugPrint('[OrderTracking] Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentPollOrder() async {
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      final order = await repo.getOrder(cleanId);
      if (mounted) {
        setState(() => _order = order);
        _setupCoordinatesFromOrder(order);
      }
    } catch (_) {}
  }

  void _setupCoordinatesFromOrder(Order order) {
    // 1. Customer Position (Delivery Address Coordinates)
    final custLat = (order.addressRaw?['lat'] as num?)?.toDouble() ??
        (order.addressRaw?['latitude'] as num?)?.toDouble() ??
        order.address?.lat;
    final custLng = (order.addressRaw?['lng'] as num?)?.toDouble() ??
        (order.addressRaw?['longitude'] as num?)?.toDouble() ??
        order.address?.lng;

    if (custLat != null && custLng != null && custLat != 0.0 && custLng != 0.0) {
      _customerPosition = LatLng(custLat, custLng);
    } else {
      _customerPosition = LatLng(AppConfig.darkstoreLat + 0.008, AppConfig.darkstoreLng + 0.006);
    }

    // 2. Dynamic Store / Restaurant Hub Resolution
    _primaryOutlet = getOutletLocation(
      restaurantId: order.restaurantId,
      shopName: order.shopName,
      items: order.items,
      rawOrder: order.toJson(),
    );
    _storePosition = LatLng(_primaryOutlet!.lat, _primaryOutlet!.lng);

    // 3. Check for Combined Order Multi-Outlets
    if (order.isCombined && order.subOrders != null && order.subOrders!.isNotEmpty) {
      // Find Restaurant Sub-Order
      final restSub = order.subOrders!.firstWhere(
        (s) => s.restaurantId != null || (s.readableId != null && s.readableId!.toUpperCase().endsWith('-R')),
        orElse: () => order.subOrders!.first,
      );
      _restaurantOutlet = getOutletLocation(
        restaurantId: restSub.restaurantId,
        shopName: restSub.shopName,
        items: restSub.items ?? order.items,
        rawOrder: restSub.toJson(),
      );
      _restaurantPosition = LatLng(_restaurantOutlet!.lat, _restaurantOutlet!.lng);
      // Darkstore location for Grocery Sub-Order
      _storePosition = LatLng(darkstoreLocation.lat, darkstoreLocation.lng);
    } else {
      _restaurantPosition = null;
      _restaurantOutlet = null;
    }

    // 4. Rider Position
    if (order.status == OrderStatus.shipped || order.status == OrderStatus.packed) {
      if (order.deliveryLat != null && order.deliveryLng != null && order.deliveryLat != 0.0 && order.deliveryLng != 0.0) {
        _updateRiderLocation(LatLng(order.deliveryLat!, order.deliveryLng!), 0.0);
      } else if (_riderPosition == null) {
        _updateRiderLocation(_storePosition!, 0.0);
      }
    }

    _refreshMapElements();
    _calculateETA();
  }

  /// Smoothly animate rider marker between positions
  void _updateRiderLocation(LatLng newPos, double heading) {
    if (_riderPosition == null) {
      setState(() {
        _riderPosition = newPos;
        _riderHeading = heading;
      });
      _refreshMapElements();
      _calculateETA();
      return;
    }

    _prevRiderPosition = _riderPosition;
    _targetRiderPosition = newPos;
    _riderHeading = heading;

    _riderAnimController.reset();
    _riderAnimController.forward();
  }

  void _interpolateRiderMarker() {
    if (_prevRiderPosition == null || _targetRiderPosition == null) return;
    final progress = _riderAnimController.value;
    final curLat = _prevRiderPosition!.latitude + (_targetRiderPosition!.latitude - _prevRiderPosition!.latitude) * progress;
    final curLng = _prevRiderPosition!.longitude + (_targetRiderPosition!.longitude - _prevRiderPosition!.longitude) * progress;

    setState(() {
      _riderPosition = LatLng(curLat, curLng);
    });
    _refreshMapElements();
  }

  /// Calculate distance & estimated arrival time using Haversine formula (Throttled, No excess API calls)
  void _calculateETA() {
    if (_customerPosition == null) return;
    final start = _riderPosition ?? _storePosition ?? _customerPosition!;
    final distanceKm = _getHaversineDistance(start, _customerPosition!);

    setState(() {
      _distanceText = '${distanceKm.toStringAsFixed(1)} km away';
      if (_order?.status == OrderStatus.delivered) {
        _etaText = 'Delivered 🎉';
      } else if (_order?.status == OrderStatus.shipped) {
        // Average speed 22 km/h in city + 3 min buffer
        final estMinutes = math.max(3, ((distanceKm / 22.0) * 60).round() + 3);
        _etaText = '$estMinutes mins';
      } else if (_order?.status == OrderStatus.packed) {
        _etaText = '15-20 mins';
      } else {
        _etaText = '20-25 mins';
      }
    });
  }

  double _getHaversineDistance(LatLng pos1, LatLng pos2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = math.cos;
    final a = 0.5 -
        c((pos2.latitude - pos1.latitude) * p) / 2 +
        c(pos1.latitude * p) * c(pos2.latitude * p) * (1 - c((pos2.longitude - pos1.longitude) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<void> _initCustomMarkers() async {
    try {
      _storeMarkerIcon = await _createCustomMarkerBitmap(
        label: 'STORE',
        emoji: '🏪',
        color: const Color(0xFF16A34A),
      );
      _restaurantMarkerIcon = await _createCustomMarkerBitmap(
        label: 'FOOD',
        emoji: '🍽️',
        color: const Color(0xFF7C3AED),
      );
      _riderMarkerIcon = await _createCustomMarkerBitmap(
        label: 'RIDER',
        emoji: '🛵',
        color: const Color(0xFFEA580C),
      );
      _customerMarkerIcon = await _createCustomMarkerBitmap(
        label: 'HOME',
        emoji: '🏠',
        color: const Color(0xFFDC2626),
      );
      if (mounted) {
        setState(() {
          _refreshMapElements();
        });
      }
    } catch (_) {}
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap({
    required String label,
    required String emoji,
    required Color color,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const width = 100.0;
    const height = 110.0;
    const center = Offset(50, 42);

    // 1. Soft Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center.translate(0, 4), 32, shadowPaint);

    // 2. White Disc Fill
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 32, whitePaint);

    // 3. Pointer Pin Triangle at bottom
    final pinPath = Path()
      ..moveTo(38, 64)
      ..lineTo(62, 64)
      ..lineTo(50, 84)
      ..close();
    canvas.drawPath(pinPath, whitePaint);

    // 4. Vibrant Colored Border Ring
    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 32, borderPaint);
    canvas.drawPath(pinPath, borderPaint);

    // 5. Centered Large Emoji Icon
    final emojiPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 26)),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    emojiPainter.paint(canvas, Offset(50 - emojiPainter.width / 2, 42 - emojiPainter.height / 2));

    // 6. Bottom Micro Label Pill
    final labelBgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final labelRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 86, 64, 18),
      const Radius.circular(9),
    );
    canvas.drawRRect(labelRRect, labelBgPaint);

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: Responsive.scaledFontSize(context, 9.5),
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    labelPainter.paint(canvas, Offset(50 - labelPainter.width / 2, 95 - labelPainter.height / 2));

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  List<LatLng> _roadPolylinePoints = [];
  LatLng? _lastRouteStart;
  LatLng? _lastRouteEnd;
  bool _isFetchingRoute = false;

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingRoute) return;
    if (_lastRouteStart != null && _lastRouteEnd != null) {
      final dStart = _getHaversineDistance(_lastRouteStart!, start);
      final dEnd = _getHaversineDistance(_lastRouteEnd!, end);
      if (dStart < 0.03 && dEnd < 0.03 && _roadPolylinePoints.length > 2) {
        return; // Position hasn't significantly moved
      }
    }

    _isFetchingRoute = true;
    try {
      final dio = Dio();
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final response = await dio.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.data != null) {
        final routes = response.data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes.first['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List?;
          if (coordinates != null && coordinates.isNotEmpty) {
            final points = <LatLng>[];
            for (final coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final lng = (coord[0] as num).toDouble();
                final lat = (coord[1] as num).toDouble();
                points.add(LatLng(lat, lng));
              }
            }

            if (points.isNotEmpty && mounted) {
              _lastRouteStart = start;
              _lastRouteEnd = end;
              setState(() {
                _roadPolylinePoints = points;
                _polylines.clear();
                _polylines.add(
                  Polyline(
                    polylineId: const PolylineId('delivery_route'),
                    points: _roadPolylinePoints,
                    color: const Color(0xFF2563EB),
                    width: 5,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                );
              });
              _isFetchingRoute = false;
              return;
            }
          }
        }
      }
    } catch (_) {}

    _isFetchingRoute = false;
  }

  /// Build Google Map markers and polyline
  void _refreshMapElements() {
    final markers = <Marker>{};
    final polylineCoords = <LatLng>[];

    // 1. Store / Restaurant Hub Markers
    if (_order?.isCombined == true && _restaurantPosition != null) {
      // Combined Order: Pin 1 (Darkstore Grocery)
      if (_storePosition != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('store_darkstore'),
            position: _storePosition!,
            anchor: const Offset(0.5, 0.8),
            icon: _storeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(
              title: '🛒 FastKirana Darkstore',
              snippet: 'Grocery Fulfillment Hub',
            ),
          ),
        );
      }
      // Combined Order: Pin 2 (Restaurant Kitchen)
      markers.add(
        Marker(
          markerId: const MarkerId('store_restaurant'),
          position: _restaurantPosition!,
          anchor: const Offset(0.5, 0.8),
          icon: _restaurantMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
          infoWindow: InfoWindow(
            title: '🍽️ ${_restaurantOutlet?.name ?? "Restaurant Kitchen"}',
            snippet: _restaurantOutlet?.address ?? 'Fresh Food Kitchen',
          ),
        ),
      );
    } else if (_storePosition != null) {
      // Single Order: Darkstore OR Specific Restaurant (A.S. Restaurant, Wedson, etc.)
      final isRest = _primaryOutlet?.isRestaurant == true;
      final outletName = _primaryOutlet?.name ?? (_order?.shopName ?? 'FastKirana Store');
      final outletAddress = _primaryOutlet?.address ?? 'Pickup Location';

      markers.add(
        Marker(
          markerId: const MarkerId('store'),
          position: _storePosition!,
          anchor: const Offset(0.5, 0.8),
          icon: isRest
              ? (_restaurantMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
              : (_storeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
          infoWindow: InfoWindow(
            title: '${isRest ? "🍽️" : "🏪"} $outletName',
            snippet: outletAddress,
          ),
        ),
      );
    }

    // 2. Customer Doorstep Marker
    if (_customerPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerPosition!,
          anchor: const Offset(0.5, 0.8),
          icon: _customerMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Your Delivery Location',
            snippet: _order?.address?.formattedAddress ?? 'Doorstep',
          ),
        ),
      );
    }

    // 3. Live Moving Rider Marker
    if (_riderPosition != null && (_order?.status == OrderStatus.shipped || _order?.status == OrderStatus.packed)) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderPosition!,
          icon: _riderMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: _riderHeading,
          flat: true,
          anchor: const Offset(0.5, 0.8),
          infoWindow: const InfoWindow(
            title: '🛵 Delivery Executive',
            snippet: 'Live On the Way',
          ),
        ),
      );
    }

    // 4. Trigger Turn-by-Turn Road-Wise Polyline Route
    final startPoint = _riderPosition ?? _storePosition;
    if (startPoint != null && _customerPosition != null) {
      _fetchRoadRoute(startPoint, _customerPosition!);
      if (_roadPolylinePoints.length >= 2) {
        polylineCoords.addAll(_roadPolylinePoints);
      } else {
        polylineCoords.add(startPoint);
        polylineCoords.add(_customerPosition!);
      }
    }

    final polylines = <Polyline>{};
    if (polylineCoords.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: polylineCoords,
          color: const Color(0xFF2563EB),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }

    setState(() {
      _markers.clear();
      _markers.addAll(markers);
      _polylines.clear();
      _polylines.addAll(polylines);
    });
  }

  void _fitMapBounds() {
    if (_mapController == null || !mounted) return;
    try {
      final points = <LatLng>[];
      if (_storePosition != null) points.add(_storePosition!);
      if (_restaurantPosition != null) points.add(_restaurantPosition!);
      if (_customerPosition != null) points.add(_customerPosition!);
      if (_riderPosition != null) points.add(_riderPosition!);

      if (points.isEmpty) return;

      if (points.length == 1) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 14.5));
        return;
      }

      double minLat = points.first.latitude;
      double maxLat = points.first.latitude;
      double minLng = points.first.longitude;
      double maxLng = points.first.longitude;

      for (final p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      final latSpan = (maxLat - minLat).abs();
      final lngSpan = (maxLng - minLng).abs();
      final latMargin = math.max(0.005, latSpan * 0.35);
      final lngMargin = math.max(0.005, lngSpan * 0.35);

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latMargin, minLng - lngMargin),
        northeast: LatLng(maxLat + latMargin, maxLng + lngMargin),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 30));
    } catch (e) {
      debugPrint('[OrderTracking] _fitMapBounds error: $e');
    }
  }

  int _getStatusStep(OrderStatus? status) {
    if (status == null) return 1;
    switch (status) {
      case OrderStatus.pending:
        return 0; // Order Confirmed
      case OrderStatus.confirmed:
        return 1; // Preparing
      case OrderStatus.packed:
        return 2; // Ready for Pickup / Rider Assigned
      case OrderStatus.shipped:
        return 3; // Out for Delivery
      case OrderStatus.delivered:
        return 4; // Delivered
      case OrderStatus.cancelled:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStep = _getStatusStep(_order?.status);
    final isCancelled = _order?.status == OrderStatus.cancelled || statusStep < 0;
    final isDelivered = _order?.status == OrderStatus.delivered || statusStep >= 4;
    final isPaid = _order?.paymentStatus == 'PAID';
    final displayNum = _order?.displayId ?? (_order?.readableId ?? widget.orderId);
    final cleanDisplayId = '#${displayNum.replaceAll('#', '').replaceAll('FK-', '').trim()}';

    final initialTarget = _riderPosition ?? _storePosition ?? LatLng(AppConfig.darkstoreLat, AppConfig.darkstoreLng);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: slateDark, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Tracking',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 16),
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              cleanDisplayId,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w700, color: slateMuted),
            ),
          ],
        ),
        actions: [
          // Supabase Realtime Live Badge
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _isRealtimeConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isRealtimeConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRealtimeConnected ? const Color(0xFF00A344) : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isRealtimeConnected ? 'LIVE GPS' : 'SYNC',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 8.5),
                    fontWeight: FontWeight.w900,
                    color: _isRealtimeConnected ? const Color(0xFF059669) : const Color(0xFFB45309),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: slateDark),
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchLiveOrder();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: brandGreen))
              : ResponsiveContainer(
                  maxWidth: Responsive.defaultMaxContentWidth,
                  fillHeight: true,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 0. Cancelled Order Alert Card
                        if (isCancelled) ...[
                          _buildCancelledOrderCard(),
                          const SizedBox(height: 14),
                        ] else ...[
                          // Pay Online Banner (if COD)
                          if (!isPaid && !isDelivered && _order?.deliveryMethod != 'PICKUP') ...[
                            _buildPayOnlineCard(),
                            const SizedBox(height: 12),
                          ],

                          // 1. Google Maps Viewport (ONLY WHEN ON THE WAY / RIDER ASSIGNED)
                          if (statusStep >= 2 && !isDelivered) ...[
                            _buildGoogleMapsCard(initialTarget, isDelivered),
                            const SizedBox(height: 14),
                          ] else if (!isDelivered) ...[
                            _buildPreparingOrderCard(),
                            const SizedBox(height: 14),
                          ],
                        ],

                        // 2. Dedicated Sponsored Ad Banner Slot (Type: sponsored_ad)
                        Consumer(
                          builder: (context, ref, _) {
                            final bannersAsync = ref.watch(bannersProvider('sponsored_ad'));
                            return bannersAsync.when(
                              data: (banners) {
                                final activeBanner = banners.where((b) => b.isActive).firstOrNull;
                                if (activeBanner != null) {
                                  return SponsoredAdCard(
                                    title: activeBanner.title,
                                    subtitle: activeBanner.subtitle ?? 'Special Partner Offer on FastKirana',
                                    imageUrl: activeBanner.imageUrl,
                                    discountText: 'EXCLUSIVE PROMO',
                                    actionText: 'View Details',
                                    onTap: () {
                                      if (activeBanner.link != null && activeBanner.link!.isNotEmpty) {
                                        launchUrl(Uri.parse(activeBanner.link!), mode: LaunchMode.externalApplication);
                                      }
                                    },
                                  );
                                }
                                return SponsoredAdCard(
                                  title: '📢 Feature Your Restaurant or Shop Here!',
                                  subtitle: 'Reach thousands of daily shoppers in Ghatampur. Tap to partner.',
                                  discountText: 'PARTNER WITH US',
                                  actionText: 'Contact Admin',
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    launchUrl(
                                      Uri.parse('https://wa.me/918112849854?text=Hi%20FastKirana%2C%20I%20want%20to%20feature%20my%20business%20on%20FastKirana%20App'),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => SponsoredAdCard(
                                title: '📢 Feature Your Restaurant or Shop Here!',
                                subtitle: 'Reach thousands of daily shoppers in Ghatampur. Tap to partner.',
                                discountText: 'PARTNER WITH US',
                                actionText: 'Contact Admin',
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  launchUrl(
                                    Uri.parse('https://wa.me/918112849854?text=Hi%20FastKirana%2C%20I%20want%20to%20feature%20my%20business%20on%20FastKirana%20App'),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // 3. Rider Profile & Contact Card (When Assigned/Out for Delivery)
                        if (statusStep >= 2 && !isDelivered && !isCancelled) ...[
                          _buildRiderCard(),
                          const SizedBox(height: 14),
                        ],

                        // 4. Swiggy/Zomato Multi-Stage Order Stepper
                        _buildStatusStepperCard(statusStep, isDelivered, isCancelled, cleanDisplayId),
                        const SizedBox(height: 14),

                        // 5. Delivery Address Card
                        if (_order?.deliveryMethod != 'PICKUP') ...[
                          _buildDeliveryDestinationCard(),
                          const SizedBox(height: 12),
                        ],

                        // 6. Order Items & Receipt Card
                        _buildOrderReceiptCard(),
                        const SizedBox(height: 14),

                        // 7. Review Card (If delivered)
                        if (isDelivered) ...[
                          _buildReviewCard(),
                          const SizedBox(height: 12),
                        ],

                        // 8. Help & Support
                        _buildSupportFooter(),
                      ],
                    ),
                  ),
                ),

          // Confetti Overlay on Delivery
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFFE20A22),
                Color(0xFF00A344),
                Color(0xFF2563EB),
                Color(0xFFF59E0B),
                Color(0xFFEC4899),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 0. Order Preparation Hero Card (When Order is Confirmed / Packing)
  Widget _buildPreparingOrderCard() {
    final shopName = _order?.shopName ?? 'FastKirana Store';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
            ),
            child: const Center(
              child: Text('👨‍🍳', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 24))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'STORE ACCEPTED & PREPARING',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Packing Fresh at $shopName',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 13.5),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Live GPS tracking map will automatically open as soon as your rider picks up the order.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF92400E),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Interactive Google Map Card with Live Rider, Store & Customer Pinpoints
  Widget _buildGoogleMapsCard(LatLng initialTarget, bool isDelivered) {
    final shopName = _order?.shopName ?? 'FastKirana Store';
    return Column(
      children: [
        Container(
          height: 290,
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
                markers: _markers,
                polylines: _polylines,
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
                onMapCreated: (controller) {
                  _mapController = controller;
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (mounted) _fitMapBounds();
                  });
                },
              ),

              // Bottom-Left Live GPS Pill
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

              // Bottom-Right Floating Controls (Zoom In, Zoom Out, Fit Bounds)
              Positioned(
                bottom: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom In
                    _buildMapCircleBtn(
                      icon: Icons.add_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _mapController?.animateCamera(CameraUpdate.zoomIn());
                      },
                    ),
                    const SizedBox(height: 6),
                    // Zoom Out
                    _buildMapCircleBtn(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _mapController?.animateCamera(CameraUpdate.zoomOut());
                      },
                    ),
                    const SizedBox(height: 6),
                    // Fit All
                    _buildMapCircleBtn(
                      icon: Icons.crop_free_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _fitMapBounds();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Clean Delivery Journey Legend Bar Beneath Map
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
          child: _order?.isCombined == true
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Dark Store
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🛒', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
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
                      // 2. Restaurant
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🍽️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
                          const SizedBox(width: 4),
                          Text(
                            _restaurantOutlet?.name ?? 'Kitchen',
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
                      // 3. Rider
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
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
                      // 4. Home
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏠', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
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
                    final rawName = _primaryOutlet?.name ?? shopName;
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

                    final isRest = _primaryOutlet?.isRestaurant == true;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 1. Store / Restaurant
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(isRest ? '🍽️' : '🏪', style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
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
                        // 2. Rider
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
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
                        // 3. You
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏠', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 13))),
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
    );
  }

  Widget _buildMapCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: slateBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, size: 18, color: slateDark),
        ),
      ),
    );
  }

  /// 3. Redesigned Premium Delivery Partner (Rider) Profile Card
  Widget _buildRiderCard() {
    final riderName = _order?.deliveryUser?.name?.isNotEmpty == true ? _order!.deliveryUser!.name! : 'Aryan';
    final riderPhone = _order?.deliveryUser?.phone?.isNotEmpty == true ? _order!.deliveryUser!.phone! : '+918112849854';
    final cleanPhone = riderPhone.replaceAll(RegExp(r'[^0-9]'), '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                      'DELIVERY PARTNER ASSIGNED',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF16A34A)),
                      const SizedBox(width: 3),
                      Text(
                        'Verified',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 9.5),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Avatar with Scooter Icon & Online Badge
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🛵', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22))),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),

                // Rider Details (Name + Rating)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              riderName,
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 14.5),
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 11, color: Color(0xFFD97706)),
                                const SizedBox(width: 1.5),
                                Text(
                                  '4.9',
                                  style: GoogleFonts.inter(
                                    fontSize: Responsive.scaledFontSize(context, 10),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '500+ orders',
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 10.5),
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Quick Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WhatsApp Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        launchUrl(
                          Uri.parse('https://wa.me/$cleanPhone?text=Hi%20FastKirana%20Rider%2C%20regarding%20my%20order'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Center(
                          child: Text('💬', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 17))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Call Button
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        launchUrl(Uri.parse('tel:$riderPhone'));
                      },
                      icon: const Icon(Icons.phone_rounded, size: 13, color: Colors.white),
                      label: Text(
                        'Call',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 12),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 0. Cancelled Order Alert Card
  Widget _buildCancelledOrderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ORDER CANCELLED',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 9),
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This order has been cancelled',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 14),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'If you have already paid online via UPI/Card, a full refund has been initiated to your original payment method within 2-4 business days.',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11.5),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB91C1C),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Swiggy/Zomato Status Stepper Card
  Widget _buildStatusStepperCard(int statusStep, bool isDelivered, bool isCancelled, String cleanDisplayId) {
    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
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
                  'Live Order Status',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: slateDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    'CANCELLED',
                    style: GoogleFonts.inter(
                      fontSize: Responsive.scaledFontSize(context, 10),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFDC2626),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFDC2626),
                  ),
                  child: const Center(
                    child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Closed & Cancelled',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w900, color: const Color(0xFF991B1B)),
                      ),
                      Text(
                        'Items were returned to stock. You can place a new order anytime.',
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: slateMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final steps = [
      {'title': 'Order Confirmed', 'subtitle': 'Store has accepted your order', 'icon': Icons.check_circle_outline_rounded},
      {'title': 'Preparing Fresh', 'subtitle': 'Packing fresh items from warehouse', 'icon': Icons.inventory_2_outlined},
      {'title': 'Ready for Pickup', 'subtitle': 'Rider assigned and picking up', 'icon': Icons.storefront_outlined},
      {'title': 'Out for Delivery', 'subtitle': 'Rider on the way to your door', 'icon': Icons.two_wheeler_rounded},
      {'title': 'Delivered', 'subtitle': 'Delivered safely at your location', 'icon': Icons.done_all_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slateBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                'Live Order Status',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 15), fontWeight: FontWeight.w900, color: slateDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDelivered ? 'COMPLETED' : 'IN TRANSIT',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 10),
                    fontWeight: FontWeight.w900,
                    color: isDelivered ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Combined Order Multi-Outlet Live Breakdown Strip
          if (_order?.isCombined == true && _order?.subOrders != null && _order!.subOrders!.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Text(
                        'COMBINED ORDER FULFILLMENT',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 11),
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF7C3AED),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._order!.subOrders!.map((sub) {
                    final isRest = sub.restaurantId != null || (sub.readableId != null && sub.readableId!.toUpperCase().endsWith('-R'));
                    final subOutletName = isRest ? (_restaurantOutlet?.name ?? 'Restaurant') : 'Dark Store (Grocery)';
                    final subIcon = isRest ? '🍽️' : '🛒';
                    final subStatusText = sub.status.displayName;
                    final isSubDone = sub.status == OrderStatus.packed || sub.status == OrderStatus.shipped || sub.status == OrderStatus.delivered;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF3E8FF)),
                      ),
                      child: Row(
                        children: [
                          Text(subIcon, style: const TextStyle(fontSize: Responsive.scaledFontSize(context, 16))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subOutletName,
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: const Color(0xFF1E1B4B)),
                                ),
                                Text(
                                  isSubDone ? 'Ready for pickup' : 'Preparing items...',
                                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), color: const Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isSubDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              subStatusText.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: Responsive.scaledFontSize(context, 9),
                                fontWeight: FontWeight.w900,
                                color: isSubDone ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Text(
                    '🛵 1 delivery partner is collecting both outlet packages for a single doorstep drop.',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10.5), fontWeight: FontWeight.w600, color: const Color(0xFF6B21A8)),
                  ),
                ],
              ),
            ),
          ],
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final isCompleted = idx <= statusStep;
            final isCurrent = idx == statusStep;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? (isCurrent ? primaryRed : brandGreen)
                            : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isCompleted ? Colors.transparent : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          item['icon'] as IconData,
                          size: 14,
                          color: isCompleted ? Colors.white : slateMuted,
                        ),
                      ),
                    ),
                    if (idx < steps.length - 1)
                      Container(
                        width: 2,
                        height: 24,
                        color: isCompleted ? brandGreen : const Color(0xFFE2E8F0),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 13),
                            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                            color: isCurrent ? slateDark : (isCompleted ? const Color(0xFF1E293B) : slateMuted),
                          ),
                        ),
                        Text(
                          item['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            color: slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// Pay Online Card (For COD Orders)
  Widget _buildPayOnlineCard() {
    final grandTotal = _order?.total ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF00A344).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A344).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PAY ONLINE',
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 9.5),
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF00A344),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 11, color: Color(0xFF16A34A)),
                    const SizedBox(width: 3),
                    Text('Instant & Secure', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 9.5), fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Pay ₹${grandTotal.toInt()} Online',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14.5), fontWeight: FontWeight.w900, color: slateDark)),
          const SizedBox(height: 3),
          Text(
            'Order is currently set to Cash on Delivery. You can pay online using Google Pay, PhonePe, Paytm, BHIM, UPI or Cards.',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), color: const Color(0xFF475569), height: 1.3),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isProcessingPayment ? null : _payOrderOnline,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00A344), Color(0xFF008736)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: const Color(0xFF00A344).withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: _isProcessingPayment
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, color: Colors.white, size: 15),
                        const SizedBox(width: 6),
                        Text('Pay ₹${grandTotal.toInt()} Online Now',
                            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2)),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Delivery Destination Address Card
  Widget _buildDeliveryDestinationCard() {
    final addr = _order?.address;
    final raw = _order?.addressRaw;

    // Build full address from individual parts if formattedAddress is missing
    String fullAddress = addr?.formattedAddress ?? '';
    if (fullAddress.isEmpty || fullAddress == 'Ghatampur Zone') {
      if (raw != null) {
        final parts = [
          raw['houseNo'],
          raw['street'],
          raw['area'],
          raw['landmark'],
          raw['city'],
          raw['pincode'],
        ]
            .where((p) => p != null && p.toString().trim().isNotEmpty && p.toString() != 'null')
            .map((p) => p.toString().trim())
            .toList();
        if (parts.isNotEmpty) {
          fullAddress = parts.join(', ');
        }
      }
      // Fallback to customerAddress
      if (fullAddress.isEmpty) {
        fullAddress = _order?.customerAddress ?? 'Ghatampur, Kanpur Nagar - 209206';
      }
    }

    // Determine label - use "Delivery Address" as header if label is generic
    String labelText = 'Delivery Address';
    final rawLabel = addr?.label ?? '';
    if (rawLabel.isNotEmpty &&
        rawLabel != 'Delivery Location' &&
        !rawLabel.toLowerCase().contains('express delivery')) {
      labelText = rawLabel;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slateBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, color: primaryRed, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelText,
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: slateDark),
                ),
                const SizedBox(height: 3),
                Text(
                  fullAddress,
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: slateMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Order Items and Billing Receipt Card
  Widget _buildOrderReceiptCard() {
    final items = _order?.items ?? [];

    // Calculate item total from actual items (price * qty) for accuracy
    double calculatedItemTotal = 0.0;
    for (final item in items) {
      calculatedItemTotal += item.price * item.quantity;
    }

    // Use calculated item total if it's > 0, else fallback to subtotal
    final subtotal = calculatedItemTotal > 0 ? calculatedItemTotal : (_order?.subtotal ?? 0.0);
    final deliveryFee = _order?.deliveryFee ?? 0.0;
    final miscFee = _order?.miscFee ?? 0.0;
    final taxes = _order?.taxes ?? 0.0;
    final discount = _order?.discount ?? 0.0;
    final total = _order?.total ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: slateBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bill Details',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14.5), fontWeight: FontWeight.w900, color: slateDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} ITEMS',
                  style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: slateMuted, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    // Qty badge
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: slateBorder),
                      ),
                      child: Center(
                        child: Text(
                          '${item.quantity}x',
                          style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w800, color: slateDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.name,
                        style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w600, color: slateDark),
                      ),
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toInt()}',
                      style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12.5), fontWeight: FontWeight.w700, color: slateDark),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          const Divider(height: 1, color: slateBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Item Total', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
              Text('₹${subtotal.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateDark)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Fee', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
              Text(
                deliveryFee > 0 ? '₹${deliveryFee.toInt()}' : 'FREE',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 12),
                  fontWeight: deliveryFee > 0 ? FontWeight.w600 : FontWeight.w800,
                  color: deliveryFee > 0 ? slateDark : brandGreen,
                ),
              ),
            ],
          ),
          if (miscFee > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Packaging Charge', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
                Text('₹${miscFee.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateDark)),
              ],
            ),
          ],
          if (taxes > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Handling & Taxes', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted)),
                Text('₹${taxes.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: slateDark)),
              ],
            ),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount Savings', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w600, color: brandGreen)),
                Text('-₹${discount.toInt()}', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: brandGreen)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: slateBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Paid', style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 14), fontWeight: FontWeight.w900, color: slateDark)),
                  Text(
                    _order?.paymentMethod.displayName ?? 'COD',
                    style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 10), fontWeight: FontWeight.w600, color: slateMuted),
                  ),
                ],
              ),
              Text(
                '₹${total.toInt()}',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 16), fontWeight: FontWeight.w900, color: primaryRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Review & Rating Card (Delivered State)
  Widget _buildReviewCard() {
    final riderName = _order?.deliveryUser?.name ?? 'Delivery Partner';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'DELIVERED SAFELY',
                      style: GoogleFonts.inter(
                        fontSize: Responsive.scaledFontSize(context, 9.5),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'How was your delivery with $riderName?',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 14.5),
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            'Rate your experience to help us reward top delivery partners.',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11.5), color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Interactive 5 Gold Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddReviewScreen(
                        productName: (_order?.items != null && _order!.items!.isNotEmpty)
                            ? _order!.items!.first.name
                            : 'FastKirana Delivery',
                        restaurantId: _order?.restaurantId,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 26,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Rate Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddReviewScreen(
                      productName: (_order?.items != null && _order!.items!.isNotEmpty)
                          ? _order!.items!.first.name
                          : 'FastKirana Delivery',
                      restaurantId: _order?.restaurantId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.rate_review_rounded, size: 16, color: Colors.white),
              label: Text(
                'Write Detailed Review',
                style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 13), fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Help & Support Footer
  Widget _buildSupportFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.headset_mic_rounded, size: 14, color: slateMuted),
            const SizedBox(width: 6),
            Text(
              'Need assistance with this order?',
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), color: slateMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('tel:${AppConfig.supportPhone}')),
          child: Text(
            'Call FastKirana Support (${AppConfig.supportPhone})',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 12), fontWeight: FontWeight.w800, color: primaryRed),
          ),
        ),
      ],
    );
  }
}
