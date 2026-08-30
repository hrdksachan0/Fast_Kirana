import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../../core/theme/responsive.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../widgets/sponsored_ad_card.dart';
import '../profile/add_review_screen.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  Order? _order;
  bool _isLoading = true;
  bool _isRealtimeConnected = false;

  // Google Maps Controller & State
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Live Location & ETA
  LatLng? _riderPosition;
  double _riderHeading = 0.0;
  LatLng? _storePosition;
  LatLng? _customerPosition;
  String _etaText = 'Calculating ETA...';
  String _distanceText = '-- km';

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
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _riderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(_interpolateRiderMarker);

    _initRazorpay();
    _fetchLiveOrder();
    _initSupabaseRealtime();

    // Fallback polling every 15 seconds to ensure absolute state consistency
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _silentPollOrder();
    });
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
    await SupabaseService.initialize();
    _supabaseChannel = SupabaseService.subscribeToOrderLocation(
      orderId: widget.orderId,
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

    if (_supabaseChannel != null) {
      setState(() => _isRealtimeConnected = true);
    }
  }

  Future<void> _fetchLiveOrder() async {
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      final order = await repo.getOrder(widget.orderId);
      if (mounted && order != null) {
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
      final order = await repo.getOrder(widget.orderId);
      if (mounted && order != null) {
        setState(() => _order = order);
        _setupCoordinatesFromOrder(order);
      }
    } catch (_) {}
  }

  void _setupCoordinatesFromOrder(Order order) {
    // 1. Customer Position
    final custLat = order.deliveryLat ?? order.address?.lat;
    final custLng = order.deliveryLng ?? order.address?.lng;
    if (custLat != null && custLng != null && custLat != 0.0 && custLng != 0.0) {
      _customerPosition = LatLng(custLat, custLng);
    } else {
      _customerPosition = LatLng(AppConfig.darkstoreLat + 0.008, AppConfig.darkstoreLng + 0.006);
    }

    // 2. Store Position
    _storePosition = LatLng(AppConfig.darkstoreLat, AppConfig.darkstoreLng);

    // 3. Rider Position
    if (order.status == OrderStatus.shipped) {
      if (order.deliveryLat != null && order.deliveryLng != null) {
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

  /// Build Google Map markers and polyline
  void _refreshMapElements() {
    final markers = <Marker>{};
    final polylineCoords = <LatLng>[];

    // Store Marker
    if (_storePosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('store'),
          position: _storePosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: _order?.shopName ?? 'FastKirana Store',
            snippet: 'Store / Pickup Location',
          ),
        ),
      );
    }

    // Customer Marker
    if (_customerPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Your Delivery Location',
            snippet: _order?.address?.formattedAddress ?? 'Doorstep',
          ),
        ),
      );
    }

    // Live Rider Marker
    if (_riderPosition != null && (_order?.status == OrderStatus.shipped || _order?.status == OrderStatus.packed)) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          rotation: _riderHeading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: '🛵 Delivery Executive',
            snippet: _etaText,
          ),
        ),
      );

      // Route Polyline from Rider to Customer
      if (_customerPosition != null) {
        polylineCoords.add(_riderPosition!);
        polylineCoords.add(_customerPosition!);
      }
    } else if (_storePosition != null && _customerPosition != null) {
      polylineCoords.add(_storePosition!);
      polylineCoords.add(_customerPosition!);
    }

    final polylines = <Polyline>{};
    if (polylineCoords.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: polylineCoords,
          color: primaryRed,
          width: 4,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          patterns: [PatternItem.dash(12), PatternItem.gap(6)],
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
    if (_mapController == null) return;
    final points = <LatLng>[];
    if (_storePosition != null) points.add(_storePosition!);
    if (_customerPosition != null) points.add(_customerPosition!);
    if (_riderPosition != null) points.add(_riderPosition!);

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15.5));
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

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
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
              'Live Delivery Tracking',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              cleanDisplayId,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: slateMuted),
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
                    fontSize: 8.5,
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
                        // Pay Online Banner (if COD)
                        if (!isPaid && !isDelivered && !isCancelled && _order?.deliveryMethod != 'PICKUP') ...[
                          _buildPayOnlineCard(),
                          const SizedBox(height: 12),
                        ],

                        // 1. Google Maps Viewport with Live Rider & ETA Overlay
                        _buildGoogleMapsCard(initialTarget, isDelivered),
                        const SizedBox(height: 14),

                        // 2. Sponsored Local-Business Ad Banner (BELOW MAP)
                        const SponsoredAdCard(
                          title: '🔥 Special Offer — 20% OFF at AS Restaurant',
                          subtitle: 'Craving delicious biryani, snacks & drinks? Order now.',
                          promoCode: 'FAST20',
                          discountText: 'FLAT 20% OFF',
                        ),
                        const SizedBox(height: 14),

                        // 3. Rider Profile & Contact Card (When Assigned/Out for Delivery)
                        if (statusStep >= 2 && !isDelivered && !isCancelled) ...[
                          _buildRiderCard(),
                          const SizedBox(height: 14),
                        ],

                        // 4. Swiggy/Zomato Multi-Stage Order Stepper
                        _buildStatusStepperCard(statusStep, isDelivered, cleanDisplayId),
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

  /// 1. Interactive Google Map Card with Live Rider, Store & Customer Pinpoints
  Widget _buildGoogleMapsCard(LatLng initialTarget, bool isDelivered) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: slateBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
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
              zoom: 14.5,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _fitMapBounds();
            },
          ),

          // Floating ETA & Distance Badge
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDelivered ? Icons.check_circle_rounded : Icons.delivery_dining_rounded,
                      color: isDelivered ? brandGreen : primaryRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isDelivered ? 'Order Delivered' : 'Estimated Delivery: $_etaText',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                          ),
                        ),
                        Text(
                          isDelivered ? 'Delivered safely at your doorstep' : '🛵 Rider is $_distanceText',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Map Re-center Floating Button
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_map',
              backgroundColor: Colors.white,
              foregroundColor: slateDark,
              elevation: 4,
              onPressed: _fitMapBounds,
              child: const Icon(Icons.my_location_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Rider Profile Card with Call Button & Delivery PIN
  Widget _buildRiderCard() {
    final riderName = _order?.deliveryUser?.name ?? 'FastKirana Delivery Partner';
    final riderPhone = _order?.deliveryUser?.phone ?? '+919696503759';
    final displayId = _order?.readableId ?? widget.orderId;
    final pin = (displayId.hashCode.abs() % 9000 + 1000).toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: slateBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text('🛵', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              // Rider Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          riderName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: slateDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          '4.9 (500+ Deliveries)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: slateMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Call Rider Button
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  launchUrl(Uri.parse('tel:$riderPhone'));
                },
                icon: const Icon(Icons.phone_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Call Rider',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: slateBorder),
          const SizedBox(height: 10),
          // Delivery PIN Handover Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delivery Security PIN:',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: slateMuted),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  pin,
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: slateDark,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. Swiggy/Zomato Status Stepper Card
  Widget _buildStatusStepperCard(int statusStep, bool isDelivered, String cleanDisplayId) {
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
            color: Colors.black.withOpacity(0.04),
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
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: slateDark),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isDelivered ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
                            color: isCurrent ? slateDark : (isCompleted ? const Color(0xFF1E293B) : slateMuted),
                          ),
                        ),
                        Text(
                          item['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
                    fontSize: 9.5,
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
                    Text('Instant & Secure', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Pay ₹${grandTotal.toInt()} Online',
              style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w900, color: slateDark)),
          const SizedBox(height: 3),
          Text(
            'Order is currently set to Cash on Delivery. You can pay online using Google Pay, PhonePe, Paytm, BHIM, UPI or Cards.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569), height: 1.3),
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
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2)),
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
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addr?.label ?? 'Delivery Address',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: slateDark),
                ),
                const SizedBox(height: 2),
                Text(
                  addr?.formattedAddress ?? 'Ghatampur, Kanpur Nagar - 209206',
                  style: GoogleFonts.inter(fontSize: 11.5, color: slateMuted, height: 1.3),
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
    final subtotal = _order?.subtotal ?? 0.0;
    final deliveryFee = _order?.deliveryFee ?? 0.0;
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
          Text(
            'Order Items (${items.length})',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: slateDark),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.name}',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: slateDark),
                      ),
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toInt()}',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: slateDark),
                    ),
                  ],
                ),
              )),
          const Divider(height: 16, color: slateBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: GoogleFonts.inter(fontSize: 12, color: slateMuted)),
              Text('₹${subtotal.toInt()}', style: GoogleFonts.inter(fontSize: 12, color: slateDark)),
            ],
          ),
          if (deliveryFee > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Delivery Fee', style: GoogleFonts.inter(fontSize: 12, color: slateMuted)),
                Text('₹${deliveryFee.toInt()}', style: GoogleFonts.inter(fontSize: 12, color: slateDark)),
              ],
            ),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Discount', style: GoogleFonts.inter(fontSize: 12, color: brandGreen)),
                Text('-₹${discount.toInt()}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: brandGreen)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Bill', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: slateDark)),
              Text('₹${total.toInt()}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: primaryRed)),
            ],
          ),
        ],
      ),
    );
  }

  /// Review Card (Delivered State)
  Widget _buildReviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Column(
        children: [
          const Icon(Icons.sentiment_very_satisfied_rounded, size: 36, color: brandGreen),
          const SizedBox(height: 6),
          Text(
            'How was your delivery experience?',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: slateDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Help us improve our delivery speed & quality.',
            style: GoogleFonts.inter(fontSize: 11.5, color: slateMuted),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddReviewScreen(
                    productName: _order?.items?.firstOrNull?.name ?? 'FastKirana Delivery',
                    restaurantId: _order?.restaurantId,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Rate Delivery Partner & Order',
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
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
              style: GoogleFonts.inter(fontSize: 12, color: slateMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('tel:${AppConfig.supportPhone}')),
          child: Text(
            'Call FastKirana Support (${AppConfig.supportPhone})',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: primaryRed),
          ),
        ),
      ],
    );
  }
}
