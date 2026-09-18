import 'package:fastkirana_flutter/core/services/logger_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
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
import '../../widgets/offline_banner.dart';
import 'widgets/tracking_map_view.dart';
import 'widgets/tracking_status_stepper.dart';
import 'widgets/tracking_rider_card.dart';
import 'widgets/tracking_payment_card.dart';
import 'widgets/tracking_receipt_card.dart';
import 'widgets/tracking_preparing_card.dart';
import 'widgets/tracking_cancel_card.dart';
import 'widgets/tracking_review_card.dart';

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
  String _etaText = '';
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
  final List<RealtimeChannel> _supabaseChannels = [];
  final Set<String> _subscribedChannelKeys = {};
  Timer? _pollTimer;
  Timer? _etaUpdateTimer;
  StreamSubscription<String>? _sseLineSubscription;
  Razorpay? _razorpay;
  String? _pendingRazorpayOrderId;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();
  bool _isProcessingPayment = false;
  bool _isCancelling = false;

  // Animation controller for smooth rider marker movement
  late AnimationController _riderAnimController;
  LatLng? _prevRiderPosition;
  LatLng? _targetRiderPosition;
  DateTime? _lastLocationUpdateTime;
  DateTime? _lastCameraFollowTime;
  double _startRiderHeading = 0.0;
  double _targetRiderHeading = 0.0;

  // Confetti for Delivery Celebration
  late ConfettiController _confettiController;

  // Audio Player for Order Chimes & Arrival Alerts
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasPlayedArrivalChime = false;

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

    // Fallback polling every 25 seconds to back up Supabase Realtime WebSocket
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _silentPollOrder();
    });
  }

  Future<void> _checkAndRequestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) { LoggerService.error("Bare catch", e); }
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
    _audioPlayer.dispose();
    for (final ch in _supabaseChannels) {
      SupabaseService.unsubscribe(ch);
    }
    _supabaseChannels.clear();
    _subscribedChannelKeys.clear();
    super.dispose();
  }

  void _initRazorpay() {
    try {
      _razorpay = Razorpay();
      _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      _cfService.setCallback(_handleCashfreeSuccess, _handleCashfreeError);
    } catch (e) {
      debugPrint('Payment gateway init error: $e');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Redirecting to ${response.walletName ?? "external wallet"}... Complete payment in your wallet app.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleCashfreeSuccess(String cfOrderId) async {
    HapticFeedback.heavyImpact();
    setState(() => _isProcessingPayment = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/payment/cashfree/verify', data: {
        'orderId': widget.orderId,
        'cfOrderId': cfOrderId,
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
                    '🎉 Payment Received! Order #${_order?.readableId ?? widget.orderId} is now PAID.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating paid status from Cashfree: $e');
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _handleCashfreeError(CFErrorResponse errorResponse, String cfOrderId) async {
    HapticFeedback.lightImpact();
    // Check if backend already confirmed payment (e.g. via webhook or external UPI app return)
    try {
      final dio = ref.read(dioProvider);
      final verifyRes = await dio.post('/api/payment/cashfree/verify', data: {
        'orderId': widget.orderId,
        'cfOrderId': cfOrderId,
      });
      if (verifyRes.data != null && (verifyRes.data['isPaid'] == true || verifyRes.data['paymentStatus'] == 'PAID')) {
        await _handleCashfreeSuccess(cfOrderId);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            errorResponse.getMessage() ?? 'Payment was cancelled or could not be completed.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    HapticFeedback.heavyImpact();
    setState(() => _isProcessingPayment = true);
    try {
      final dio = ref.read(dioProvider);
      final rzpOrderId = response.orderId ?? _pendingRazorpayOrderId;
      final paymentId = response.paymentId;
      final signature = response.signature;

      bool isVerified = false;

      // 1. Cryptographic HMAC-SHA256 signature verification with backend
      if (paymentId != null && signature != null && signature.isNotEmpty && rzpOrderId != null) {
        try {
          final verifyRes = await dio.post('/api/payment/razorpay/verify-signature', data: {
            'orderId': widget.orderId,
            'razorpay_order_id': rzpOrderId,
            'razorpay_payment_id': paymentId,
            'razorpay_signature': signature,
          });
          if (verifyRes.statusCode == 200) {
            isVerified = true;
          }
        } catch (verifyErr) {
          debugPrint('Razorpay signature verification endpoint error: $verifyErr');
        }
      }

      // 2. Fallback: Query Razorpay API directly from server if signature is missing or for external wallet flows
      if (!isVerified) {
        try {
          final syncRes = await dio.post('/api/payment/razorpay/sync-order', data: {
            'orderId': widget.orderId,
          });
          if (syncRes.data != null && (syncRes.data['paymentStatus'] == 'PAID' || syncRes.data['success'] == true)) {
            isVerified = true;
          }
        } catch (syncErr) {
          debugPrint('Razorpay sync-order error: $syncErr');
        }
      }

      if (isVerified) {
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
                      '🎉 Payment Verified! Order #${_order?.readableId ?? widget.orderId} is now PAID.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        // Payment was NOT verified — never mark as paid!
        if (mounted) {
          setState(() => _isProcessingPayment = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: primaryRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Text(
                'Payment could not be verified by gateway. If money was deducted, it will automatically update shortly.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error verifying paid status from Razorpay: $e');
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
    setState(() => _isProcessingPayment = true);
    final prefs = await SharedPreferences.getInstance();
    final phone = _order?.customerPhone ?? prefs.getString('user_phone') ?? '';
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '').replaceAll(RegExp(r'^91'), '');
    final email = prefs.getString('user_email') ?? 'customer@fastkirana.in';
    final customerName = _order?.customerName ?? 'FastKirana Customer';

    // 1. Primary Gateway: Cashfree PG
    bool cashfreeLaunched = false;
    try {
      final dio = ref.read(dioProvider);
      final cfRes = await dio.post(
        '/api/payment/cashfree/create-order',
        data: {
          'orderId': widget.orderId,
          'amount': grandTotal,
          'customerPhone': cleanPhone.isNotEmpty ? cleanPhone : '9999999999',
          'customerEmail': email,
          'customerName': customerName,
        },
        options: Options(sendTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15)),
      );

      if (cfRes.data != null && cfRes.data['paymentSessionId'] != null) {
        final paymentSessionId = cfRes.data['paymentSessionId'].toString();
        final cfOrderId = cfRes.data['orderId']?.toString() ?? widget.orderId;

        final env = AppConfig.cashfreeEnv == 'SANDBOX' ? CFEnvironment.SANDBOX : CFEnvironment.PRODUCTION;
        final session = CFSessionBuilder()
            .setEnvironment(env)
            .setOrderId(cfOrderId)
            .setPaymentSessionId(paymentSessionId)
            .build();

        final theme = CFThemeBuilder()
            .setNavigationBarBackgroundColorColor("#E20A22")
            .setNavigationBarTextColor("#FFFFFF")
            .setButtonBackgroundColor("#E20A22")
            .setButtonTextColor("#FFFFFF")
            .setPrimaryTextColor("#0F172A")
            .setBackgroundColor("#FFFFFF")
            .setPrimaryFont("Inter")
            .build();

        final cfPayment = CFWebCheckoutPaymentBuilder()
            .setSession(session)
            .setTheme(theme)
            .build();

        _cfService.doPayment(cfPayment);
        cashfreeLaunched = true;
        return;
      }
    } catch (cfErr) {
      debugPrint('Cashfree create-order error, falling back to Razorpay: $cfErr');
    }

    // 2. Fallback Gateway: Razorpay
    if (!cashfreeLaunched && _razorpay != null) {
      try {
        final dio = ref.read(dioProvider);
        final rzpOrderRes = await dio.post('/api/payment/razorpay/create-order', data: {
          'orderId': widget.orderId,
          'amount': grandTotal,
        });

        final rzpOrderId = rzpOrderRes.data?['razorpayOrderId']?.toString();
        _pendingRazorpayOrderId = rzpOrderId;
        final rzpKey = rzpOrderRes.data?['keyId']?.toString() ?? AppConfig.razorpayKeyId;

        final options = {
          'key': rzpKey,
          'amount': (grandTotal * 100).toInt(),
          'name': 'FastKirana Express',
          'description': 'Order Payment #${_order?.readableId ?? widget.orderId}',
          if (rzpOrderId != null && rzpOrderId.isNotEmpty) 'order_id': rzpOrderId,
          'prefill': {
            if (cleanPhone.isNotEmpty) 'contact': cleanPhone,
            'email': email,
          },
          'theme': {
            'color': '#00A344',
          },
        };

        _razorpay?.open(options);
        return;
      } catch (e) {
        debugPrint('Razorpay create-order / open error: $e');
      }
    }

    if (mounted) {
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: primaryRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Text('Could not open payment gateway. Please retry.'),
        ),
      );
    }
  }

  /// Collect all possible channel key aliases for this order
  Set<String> _collectTrackingChannelKeys() {
    final keys = <String>{};
    void addKey(String? raw) {
      if (raw == null || raw.trim().isEmpty) return;
      var clean = raw.trim().replaceAll('#', '');
      if (clean.isNotEmpty) {
        keys.add(clean);
        if (clean.startsWith('FK-')) {
          final numOnly = clean.substring(3);
          if (numOnly.isNotEmpty) keys.add(numOnly);
        } else if (RegExp(r'^\d+$').hasMatch(clean)) {
          keys.add('FK-$clean');
        }
      }
    }
    addKey(widget.orderId);
    if (_order != null) {
      addKey(_order!.id);
      addKey(_order!.readableId);
      if (_order!.combinedId != null && _order!.combinedId!.isNotEmpty) {
        addKey(_order!.combinedId);
      }
    }
    return keys;
  }

  /// Subscribe to ALL channel key aliases for the order
  void _subscribeToChannelKeys(Set<String> keys) {
    for (final key in keys) {
      if (_subscribedChannelKeys.contains(key)) continue;
      _subscribedChannelKeys.add(key);

      final ch = SupabaseService.subscribeToOrderLocation(
        orderId: key,
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
          debugPrint('[OrderTracking] Realtime status change via key=$key: $newStatusStr');
          _fetchLiveOrder();
        },
      );

      if (ch != null) {
        _supabaseChannels.add(ch);
        debugPrint('[OrderTracking] Subscribed to channel: order-live-tracking-$key');
      }
    }

    if (_supabaseChannels.isNotEmpty && mounted) {
      setState(() => _isRealtimeConnected = true);
    }
  }

  /// Initialize Supabase Realtime subscription for live location and order status updates
  Future<void> _initSupabaseRealtime() async {
    try {
      await SupabaseService.initialize();
      final keys = _collectTrackingChannelKeys();
      _subscribeToChannelKeys(keys);
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
      if (order == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      if (mounted) {
        final prevStatus = _order?.status;
        setState(() {
          _order = order;
          _isLoading = false;
        });

        _triggerStatusHaptic(order.status, prevStatus);

        _setupCoordinatesFromOrder(order);

        // Re-subscribe with newly discovered order IDs (readableId, combinedId)
        final newKeys = _collectTrackingChannelKeys();
        _subscribeToChannelKeys(newKeys);
      }
    } catch (e) {
      debugPrint('[OrderTracking] Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playStatusChime() {
    try {
      _audioPlayer.stop();
      _audioPlayer.play(
        AssetSource('sounds/order_chime.mp3'),
        volume: 0.9,
      );
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void _triggerStatusHaptic(OrderStatus? newStatus, OrderStatus? oldStatus) {
    if (newStatus == null || oldStatus == newStatus) return;
    switch (newStatus) {
      case OrderStatus.confirmed:
        HapticFeedback.lightImpact();
        _playStatusChime();
        break;
      case OrderStatus.packed:
        HapticFeedback.mediumImpact();
        _playStatusChime();
        break;
      case OrderStatus.shipped:
        HapticFeedback.heavyImpact();
        _playStatusChime();
        break;
      case OrderStatus.delivered:
        HapticFeedback.heavyImpact();
        _playStatusChime();
        _confettiController.play();
        break;
      case OrderStatus.cancelled:
        HapticFeedback.vibrate();
        break;
      default:
        HapticFeedback.selectionClick();
    }
  }

  Future<void> _confirmAndCancelOrder() async {
    HapticFeedback.lightImpact();
    final isPaid = _order?.paymentStatus == 'PAID';
    final totalAmount = _order?.total ?? 0.0;
    final displayNum = _order?.displayId ?? (_order?.readableId ?? widget.orderId);
    final cleanDisplayId = '#${displayNum.replaceAll('#', '').replaceAll('FK-', '').trim()}';

    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.cancel_outlined, size: 28, color: primaryRed),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cancel Order?',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to cancel $cleanDisplayId? This action cannot be undone.',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w500,
                  color: slateMuted,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              if (isPaid) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_rupee_rounded, size: 18, color: brandGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '₹${totalAmount.toStringAsFixed(0)} will be refunded back to your original payment method within 2-4 business days.',
                          style: GoogleFonts.inter(
                            fontSize: Responsive.scaledFontSize(context, 11),
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF166534),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: slateBorder, width: 1.2),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        'Keep Order',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: slateDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Yes, Cancel',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldCancel != true) return;

    HapticFeedback.mediumImpact();
    setState(() => _isCancelling = true);

    try {
      final dio = ref.read(dioProvider);
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      await dio.patch('/api/orders/$cleanId', data: {
        'status': 'CANCELLED',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: slateDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order cancelled successfully.',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await _fetchLiveOrder();
    } catch (e) {
      LoggerService.error("Cancel order error", e);
      String errorMsg = 'Failed to cancel order. Please try again.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          errorMsg = data['error'].toString();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              errorMsg,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  Future<void> _confirmAndSwitchToCOD() async {
    HapticFeedback.lightImpact();
    final grandTotal = _order?.total ?? 0.0;

    final shouldSwitch = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.local_atm_rounded, size: 28, color: brandGreen),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switch to Cash on Delivery?',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 17),
                  fontWeight: FontWeight.w900,
                  color: slateDark,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'You can pay ₹${grandTotal.toInt()} in cash or via UPI to the delivery rider when your order arrives at your door.',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 13),
                  fontWeight: FontWeight.w500,
                  color: slateMuted,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: slateBorder, width: 1.2),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(
                        'Keep Online',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w700,
                          color: slateDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Confirm COD',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 13),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldSwitch != true) return;

    HapticFeedback.mediumImpact();
    setState(() => _isProcessingPayment = true);

    try {
      final dio = ref.read(dioProvider);
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      await dio.patch('/api/orders/$cleanId', data: {
        'paymentMethod': 'COD',
      });

      if (mounted) {
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
                    'Order payment switched to Cash on Delivery (COD)!',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await _fetchLiveOrder();
    } catch (e) {
      LoggerService.error("Switch COD error", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              'Failed to switch to COD. Please try again.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  Future<void> _silentPollOrder() async {
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      final order = await repo.getOrder(cleanId);
      if (order == null) return;
      if (mounted) {
        final prevStatus = _order?.status;
        setState(() => _order = order);

        _triggerStatusHaptic(order.status, prevStatus);

        // Stale-data protection: if live GPS arrived in last 15 seconds,
        // don't let polled DB coordinates snap the rider marker backwards
        final hasRecentLiveGps = _lastLocationUpdateTime != null &&
            DateTime.now().difference(_lastLocationUpdateTime!).inSeconds < 15;

        if (!hasRecentLiveGps) {
          _setupCoordinatesFromOrder(order);
        }
      }
    } catch (e) { LoggerService.error("Bare catch", e); }
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
      // Darkstore location for Grocery Sub-Order (dynamic via AppConfig)
      _storePosition = LatLng(AppConfig.darkstoreLat, AppConfig.darkstoreLng);
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

  /// Calculate bearing between two geographic coordinates (degrees 0-360)
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final lat1Rad = lat1 * math.pi / 180.0;
    final lat2Rad = lat2 * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) - math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180.0 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Smoothly animate rider marker between positions with jitter rejection
  void _updateRiderLocation(LatLng newPos, double heading) {
    final now = DateTime.now();

    if (_riderPosition == null) {
      _lastLocationUpdateTime = now;
      setState(() {
        _riderPosition = newPos;
        _riderHeading = heading;
      });
      _refreshMapElements();
      _calculateETA();
      _followRiderWithCamera();
      return;
    }

    // GPS micro-jitter rejection: ignore updates less than 0.4 meters away
    final jitterDist = Geolocator.distanceBetween(
      _riderPosition!.latitude,
      _riderPosition!.longitude,
      newPos.latitude,
      newPos.longitude,
    );
    if (jitterDist < 0.4) return;

    // Dynamic animation pacing: match animation duration to GPS update interval
    if (_lastLocationUpdateTime != null) {
      final interval = now.difference(_lastLocationUpdateTime!).inMilliseconds;
      final clampedDuration = interval.clamp(300, 2000);
      _riderAnimController.duration = Duration(milliseconds: clampedDuration);
    }
    _lastLocationUpdateTime = now;

    _prevRiderPosition = _riderPosition;
    _targetRiderPosition = newPos;

    // Calculate true vector bearing for smooth heading transition
    _startRiderHeading = _riderHeading;
    if (heading != 0.0) {
      _targetRiderHeading = heading;
    } else {
      _targetRiderHeading = _calculateBearing(
        _prevRiderPosition!.latitude,
        _prevRiderPosition!.longitude,
        newPos.latitude,
        newPos.longitude,
      );
    }

    _riderAnimController.reset();
    _riderAnimController.forward();
  }

  void _interpolateRiderMarker() {
    if (_prevRiderPosition == null || _targetRiderPosition == null) return;
    final rawProgress = _riderAnimController.value;
    final progress = Curves.easeInOut.transform(rawProgress);
    final curLat = _prevRiderPosition!.latitude + (_targetRiderPosition!.latitude - _prevRiderPosition!.latitude) * progress;
    final curLng = _prevRiderPosition!.longitude + (_targetRiderPosition!.longitude - _prevRiderPosition!.longitude) * progress;

    // Shortest-arc angular interpolation for heading
    double deltaHeading = _targetRiderHeading - _startRiderHeading;
    if (deltaHeading > 180) deltaHeading -= 360;
    if (deltaHeading < -180) deltaHeading += 360;
    final curHeading = (_startRiderHeading + deltaHeading * progress) % 360;

    _riderPosition = LatLng(curLat, curLng);
    _riderHeading = curHeading;

    // Optimized: only update rider marker in the markers set, not full rebuild
    _markers.removeWhere((m) => m.markerId.value == 'rider');
    if (_riderMarkerIcon != null) {
      _markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderPosition!,
        icon: _riderMarkerIcon!,
        anchor: const Offset(0.5, 0.5),
        rotation: _riderHeading,
        flat: true,
        zIndex: 10,
      ));
    }
    setState(() {});

    // Throttle camera follow to every 1.5 seconds to avoid jank
    final now = DateTime.now();
    if (_lastCameraFollowTime == null || now.difference(_lastCameraFollowTime!).inMilliseconds > 1500) {
      _lastCameraFollowTime = now;
      _followRiderWithCamera();
    }

    // Recalculate ETA at end of animation
    if (progress >= 1.0) {
      _calculateETA();
    }
  }

  /// Calculate distance & estimated arrival time using Haversine formula (Throttled, No excess API calls)
  void _calculateETA() {
    if (_customerPosition == null) return;
    final start = _riderPosition ?? _storePosition ?? _customerPosition!;
    final distanceKm = _getHaversineDistance(start, _customerPosition!);

    setState(() {
      if (_order?.status == OrderStatus.shipped) {
        // 🛵 Out for Delivery: Show live distance and estimated arrival time
        _distanceText = '${distanceKm.toStringAsFixed(1)} km away';

        // Check proximity: when rider is within 120m of customer gate, trigger Arrival chime
        if (distanceKm <= 0.12 && !_hasPlayedArrivalChime) {
          _hasPlayedArrivalChime = true;
          _playStatusChime();
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: brandGreen,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              content: Row(
                children: [
                  const Text('🛵 ', style: TextStyle(fontSize: 18)),
                  Expanded(
                    child: Text(
                      'Rider is arriving at your door!',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Distance-wise calculation: ~20 km/h average speed (3 mins per km) + exactly 1 min extra buffer
        final driveMinutes = ((distanceKm / 20.0) * 60).round();
        final estMinutes = math.max(2, driveMinutes + 1);
        _etaText = '$estMinutes mins';
      } else if (_order?.status == OrderStatus.delivered) {
        _etaText = 'Delivered 🎉';
        _distanceText = '';
      } else {
        // Before Out for Delivery (adminPending, pending, confirmed, packed):
        // Neither ETA nor distance should be shown until order is Out for Delivery!
        _etaText = '';
        _distanceText = '';
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
      _riderMarkerIcon = await _createRiderMarkerBitmap();
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
    } catch (e) { LoggerService.error("Bare catch", e); }
  }

  /// Circular oriented rider marker optimized for smooth Google Maps rotation & heading
  Future<BitmapDescriptor> _createRiderMarkerBitmap() async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = 96.0;
    const center = Offset(48, 48);

    // 1. Soft glowing outer pulse shadow
    final shadowPaint = Paint()
      ..color = const Color(0xFFEA580C).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, 38, shadowPaint);

    // 2. White Disc Fill
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 34, whitePaint);

    // 3. Vibrant Orange Border Ring
    final borderPaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 34, borderPaint);

    // 4. Direction Arrow Indicator at top of circle (shows direction of travel)
    final arrowPaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.fill;
    final arrowPath = Path()
      ..moveTo(48, 6)
      ..lineTo(54, 16)
      ..lineTo(42, 16)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    // 5. Centered Bike Emoji
    final emojiPainter = TextPainter(
      text: TextSpan(
        text: '🛵',
        style: TextStyle(fontSize: Responsive.scaledFontSize(context, 26)),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    emojiPainter.paint(canvas, Offset(48 - emojiPainter.width / 2, 48 - emojiPainter.height / 2));

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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
        style: TextStyle(fontSize: Responsive.scaledFontSize(context, 26)),
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
        style: TextStyle(
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
    } catch (e) { LoggerService.error("Bare catch", e); }

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
          anchor: const Offset(0.5, 0.5),
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

  void _followRiderWithCamera() {
    if (_mapController == null || _riderPosition == null || !mounted) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(_riderPosition!, 16.0),
    );
  }

  int _getStatusStep(OrderStatus? status) {
    if (status == null) return 1;
    switch (status) {
      case OrderStatus.adminPending:
        return -2; // Admin verification stage (before pending)
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
    final isCancelled = _order?.status == OrderStatus.cancelled || statusStep == -1;
    final isDelivered = _order?.status == OrderStatus.delivered || statusStep >= 4;
    final isPaid = _order?.paymentStatus == 'PAID';
    final displayNum = _order?.displayId ?? (_order?.readableId ?? widget.orderId);
    final cleanDisplayId = '#${displayNum.replaceAll('#', '').replaceAll('FK-', '').trim()}';
    final canCancel = (_order?.status == OrderStatus.pending || _order?.status == OrderStatus.adminPending) &&
        !isCancelled &&
        !isDelivered &&
        (_order?.subOrders?.every((s) => s.status == OrderStatus.pending || s.status == OrderStatus.adminPending) ?? true);

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
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order Tracking',
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 15),
                fontWeight: FontWeight.w900,
                color: slateDark,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
            ),
            Text(
              cleanDisplayId,
              style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w700, color: slateMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Pre-Confirmation Cancel Header Action
          if (canCancel)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: _isCancelling ? null : _confirmAndCancelOrder,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, size: 13, color: primaryRed),
                      const SizedBox(width: 3),
                      Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10),
                          fontWeight: FontWeight.w800,
                          color: primaryRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Supabase Realtime Live Badge
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _isRealtimeConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _isRealtimeConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRealtimeConnected ? const Color(0xFF00A344) : const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  _isRealtimeConnected ? 'LIVE' : 'SYNC',
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.refresh_rounded, color: slateDark, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchLiveOrder();
            },
          ),
          const SizedBox(width: 4),
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
                        // Offline Network Recovery Banner
                        OfflineBanner(
                          onRetry: () {
                            _fetchLiveOrder();
                          },
                          offlineText: 'Offline • Connecting to live delivery tracker...',
                        ),

                        // 0. Cancelled Order Alert Card
                        if (isCancelled) ...[
                          const TrackingCancelCard(),
                          const SizedBox(height: 14),
                        ] else ...[
                          // Pay Online Banner (if unpaid COD)
                          if (!isPaid && !isDelivered && _order?.deliveryMethod != 'PICKUP') ...[
                            TrackingPaymentCard(
                              order: _order,
                              isProcessingPayment: _isProcessingPayment,
                              statusStep: statusStep,
                              onPayOnline: _payOrderOnline,
                              onSwitchToCOD: _confirmAndSwitchToCOD,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // 1. Google Maps Viewport (ONLY WHEN ON THE WAY / RIDER ASSIGNED)
                          if (statusStep >= 2 && !isDelivered) ...[
                            TrackingMapView(
                              initialTarget: initialTarget,
                              isDelivered: isDelivered,
                              order: _order,
                              markers: _markers,
                              polylines: _polylines,
                              primaryOutlet: _primaryOutlet,
                              restaurantOutlet: _restaurantOutlet,
                              onMapCreated: (controller) {
                                _mapController = controller;
                                Future.delayed(const Duration(milliseconds: 400), () {
                                  if (mounted) _fitMapBounds();
                                });
                              },
                              onZoomIn: () {
                                HapticFeedback.lightImpact();
                                _mapController?.animateCamera(CameraUpdate.zoomIn());
                              },
                              onZoomOut: () {
                                HapticFeedback.lightImpact();
                                _mapController?.animateCamera(CameraUpdate.zoomOut());
                              },
                              onFitBounds: () {
                                HapticFeedback.lightImpact();
                                _fitMapBounds();
                              },
                            ),
                            const SizedBox(height: 14),
                          ] else if (!isDelivered) ...[
                            TrackingPreparingCard(order: _order),
                            const SizedBox(height: 14),
                          ],
                        ],

                        // Refund Notice Card (If applicable)
                        if ((_order?.refundAmount ?? 0) > 0 || ((_order?.notes ?? '').toLowerCase().contains('refund'))) ...[
                          TrackingRefundNoticeCard(order: _order),
                          const SizedBox(height: 14),
                        ],

                        // 2. Rider Profile & Contact Card (When Assigned/Out for Delivery)
                        if (statusStep >= 2 && !isDelivered && !isCancelled) ...[
                          TrackingRiderCard(order: _order),
                          const SizedBox(height: 14),
                        ],

                        // 3. Multi-Stage Order Stepper (Live status, ETA & milestones)
                        TrackingStatusStepper(
                          order: _order,
                          statusStep: statusStep,
                          isDelivered: isDelivered,
                          isCancelled: isCancelled,
                          cleanDisplayId: cleanDisplayId,
                          etaText: _etaText,
                          distanceText: _distanceText,
                        ),
                        const SizedBox(height: 14),

                        // 4. Delivery Address Card
                        if (_order?.deliveryMethod != 'PICKUP') ...[
                          TrackingDestinationCard(order: _order),
                          const SizedBox(height: 12),
                        ],

                        // 5. Order Items & Receipt Card
                        TrackingReceiptCard(order: _order),
                        const SizedBox(height: 14),

                        // 6. Sponsored Partner Ad Banner (Placed at the bottom for clean UX)
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
                                return const SizedBox.shrink();
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // 7. Review Card (If delivered)
                        if (isDelivered) ...[
                          TrackingReviewCard(order: _order),
                          const SizedBox(height: 12),
                        ],
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

}
