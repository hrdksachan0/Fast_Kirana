import 'package:collection/collection.dart';
import 'package:fastminute_flutter/core/services/logger_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import '../../core/utils/app_url_launcher.dart';
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
import '../../core/models/order_event.dart';
import '../../core/services/order_event_bus.dart';
import '../../core/services/alert_engine.dart';
import '../../core/theme/design_system.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/restaurant_utils.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/banner_provider.dart';
import 'orders_screen.dart';
import '../../widgets/sponsored_ad_card.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/shimmer_box.dart';
import 'widgets/tracking_map_view.dart';
import 'widgets/tracking_status_stepper.dart';
import 'widgets/tracking_rider_card.dart';
import 'widgets/tracking_payment_card.dart';
import 'widgets/tracking_receipt_card.dart';
import 'widgets/tracking_preparing_card.dart';
import 'widgets/tracking_cancel_card.dart';
import 'widgets/tracking_review_card.dart';
import 'widgets/swiggy_cancel_bottom_sheet.dart';
import '../../widgets/app_confirmation_dialog.dart';
import '../../core/utils/app_toast.dart';
import 'utils/geo_math_utils.dart';
import 'utils/map_marker_generator.dart';
import 'services/route_polyline_service.dart';

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

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> with TickerProviderStateMixin {
  Order? _order;
  bool _isLoading = true;
  bool _isRealtimeConnected = false;
  String _etaText = '';
  String _distanceText = '';

  // Google Maps state
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
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
  StreamSubscription<OrderEvent>? _eventBusSub;
  Timer? _pollTimer;
  Timer? _etaUpdateTimer;
  StreamSubscription<String>? _sseLineSubscription;
  final CFPaymentGatewayService _cfService = CFPaymentGatewayService();
  bool _isProcessingPayment = false;
  bool _isCancelling = false;
  bool _isMapExpanded = false;

  // Animation controller for smooth rider marker movement
  late AnimationController _riderAnimController;
  // Animation controller for flowing/pulsing animated Polyline tween
  late AnimationController _polyTweenController;
  // Ambient breathing pulse for live status card and radar aura
  late AnimationController _heroPulseController;
  late Animation<double> _heroPulseAnim;
  final List<LatLng> _coveredPolylinePoints = [];
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
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    // Initialize animation & confetti controllers first so subroutines (_setupCoordinatesFromOrder) never hit LateInitializationError
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _riderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(_interpolateRiderMarker);

    _polyTweenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(_onPolyTweenTick);

    _heroPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _heroPulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _heroPulseController, curve: Curves.easeInOut),
    );

    if (widget.initialOrder != null) {
      _order = widget.initialOrder;
      _isLoading = false;
      _setupCoordinatesFromOrder(widget.initialOrder!);
    }

    _initCustomMarkers();
    _checkAndRequestLocationPermission();
    _initCashfree();
    _fetchLiveOrder();
    _initSupabaseRealtime();
    _initEventBusListener();

    // Active order polling: 3s fallback so customer screen syncs within 3 seconds whenever admin changes status
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final st = _order?.status;
      if (st != OrderStatus.delivered && st != OrderStatus.cancelled) {
        _silentPollOrder();
      }
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

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _eventBusSub?.cancel();
    _pollTimer?.cancel();
    _etaUpdateTimer?.cancel();
    _sseLineSubscription?.cancel();
    try {
      _riderAnimController.dispose();
    } catch (_) {}
    try {
      _polyTweenController.dispose();
    } catch (_) {}
    try {
      _heroPulseController.dispose();
    } catch (_) {}
    try {
      _confettiController.dispose();
    } catch (_) {}
    _mapController?.dispose();
    _audioPlayer.dispose();
    for (final ch in _supabaseChannels) {
      SupabaseService.unsubscribe(ch);
    }
    _supabaseChannels.clear();
    _subscribedChannelKeys.clear();
    super.dispose();
  }

  void _initCashfree() {
    try {
      _cfService.setCallback(_handleCashfreeSuccess, _handleCashfreeError);
    } catch (e) {
      debugPrint('Payment gateway init error: $e');
    }
  }

  Future<void> _handleCashfreeSuccess(String cfOrderId, {bool alreadyVerified = false}) async {
    HapticFeedback.heavyImpact();
    setState(() => _isProcessingPayment = true);
    try {
      if (!alreadyVerified) {
        final dio = ref.read(dioProvider);
        final verifyRes = await dio.post('/api/payment/cashfree/verify', data: {
          'orderId': widget.orderId,
          'cfOrderId': cfOrderId,
        });
        if (verifyRes.statusCode != 200 || verifyRes.data == null || (verifyRes.data['isPaid'] != true && verifyRes.data['paymentStatus'] != 'PAID')) {
          if (mounted) {
            setState(() => _isProcessingPayment = false);
            AppToast.showWarning(
              context,
              'Payment Incomplete',
              subtitle: 'Payment was cancelled or could not be verified. Please retry or choose Cash on Delivery.',
            );
          }
          return;
        }
      }

      await _fetchLiveOrder();
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        AppToast.showSuccess(
          context,
          'Payment Received 🎉',
          subtitle: 'Order #${_order?.readableId ?? widget.orderId} is now marked PAID.',
        );
      }
      return;
    } catch (e) {
      debugPrint('Error updating paid status from Cashfree: $e');
    }

    if (mounted) {
      setState(() => _isProcessingPayment = false);
      AppToast.showWarning(
        context,
        'Payment Notice',
        subtitle: 'Payment was cancelled or could not be verified. Please retry or choose Cash on Delivery.',
      );
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
        await _handleCashfreeSuccess(cfOrderId, alreadyVerified: true);
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isProcessingPayment = false);
      AppToast.showError(
        context,
        'Payment Failed',
        subtitle: errorResponse.getMessage() ?? 'Payment was cancelled or could not be completed.',
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
    final email = prefs.getString('user_email') ?? 'customer@fastminute.in';
    final customerName = _order?.customerName ?? 'FastMinute Customer';

    // Cashfree PG
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

        const env = AppConfig.cashfreeEnv == 'SANDBOX' ? CFEnvironment.SANDBOX : CFEnvironment.PRODUCTION;
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
        return;
      }
    } catch (cfErr) {
      debugPrint('Cashfree create-order error: $cfErr');
    }

    if (mounted) {
      setState(() => _isProcessingPayment = false);
      AppToast.showError(
        context,
        'Gateway Error',
        subtitle: 'Could not open payment gateway. Please retry.',
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
          final lat = (locationData['lat'] ?? locationData['latitude']) as num?;
          final lng = (locationData['lng'] ?? locationData['longitude']) as num?;
          final heading = ((locationData['heading'] ?? locationData['bearing']) as num?)?.toDouble() ?? 0.0;

          if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
            _updateRiderLocation(LatLng(lat.toDouble(), lng.toDouble()), heading);
          }
        },
        onStatusUpdate: (newStatusStr) {
          if (!mounted) return;
          debugPrint('[OrderTracking] Realtime status change via key=$key: $newStatusStr');
          final parsed = Order.parseStatus(newStatusStr);
          if (_order != null && _order!.status != parsed) {
            final prevStatus = _order!.status;
            setState(() {
              final updatedSubs = _order!.subOrders?.map((s) => s.copyWith(status: parsed)).toList();
              _order = _order!.copyWith(status: parsed, subOrders: updatedSubs);
            });
            _triggerStatusHaptic(parsed, prevStatus);
            NotificationService().updateLiveOrderActivity(
              order: _order!,
              customEtaText: _etaText.isNotEmpty ? _etaText : null,
            );
            if (parsed == OrderStatus.cancelled || parsed == OrderStatus.delivered) {
              ref.invalidate(ordersProvider(''));
            }
          }
          _fetchLiveOrder();
        },
        onRiderAssigned: (riderName, riderPhone) {
          if (!mounted || _order == null) return;
          debugPrint('[OrderTracking] Realtime rider assigned via key=$key: $riderName ($riderPhone)');
          setState(() {
            _order = _order!.copyWith(
              deliveryBoyName: riderName,
              deliveryBoyPhone: riderPhone,
            );
          });
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

  void _initEventBusListener() {
    _eventBusSub?.cancel();
    _eventBusSub = OrderEventBus.instance.forOrder(widget.orderId).listen((event) {
      if (!mounted) return;
      debugPrint('[OrderTracking] ⚡ Instant sync from EventBus: tag=${event.tag} status=${event.status}');

      final parsed = Order.parseStatus(event.status);
      if (_order != null && _order!.status != parsed) {
        setState(() {
          final updatedSubs = _order!.subOrders?.map((s) => s.copyWith(status: parsed)).toList();
          _order = _order!.copyWith(status: parsed, subOrders: updatedSubs);
        });
        AlertEngine.handle(event, currentUserRole: 'CUSTOMER', context: context);
        NotificationService().updateLiveOrderActivity(
          order: _order!,
          customEtaText: _etaText.isNotEmpty ? _etaText : null,
        );
        if (parsed == OrderStatus.cancelled || parsed == OrderStatus.delivered) {
          ref.invalidate(ordersProvider(''));
        }
      } else {
        AlertEngine.handle(event, currentUserRole: 'CUSTOMER', context: context);
      }

      // Background silent verification
      _silentPollOrder();
    });
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

        NotificationService().updateLiveOrderActivity(
          order: order,
          customEtaText: _etaText.isNotEmpty ? _etaText : null,
        );

        _triggerStatusHaptic(order.status, prevStatus);

        _setupCoordinatesFromOrder(order);
        _syncRiderLocationFromEndpoint(order);

        // Re-subscribe with newly discovered order IDs (readableId, combinedId)
        final newKeys = _collectTrackingChannelKeys();
        _subscribeToChannelKeys(newKeys);
      }
    } catch (e) {
      debugPrint('[OrderTracking] Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _playStatusChime([String soundAsset = 'sounds/status_step_tick.wav']) {
    try {
      _audioPlayer.stop().then((_) {
        try {
          _audioPlayer.play(
            AssetSource(soundAsset),
            volume: 0.85,
            mode: PlayerMode.lowLatency,
          ).catchError((_) {
            SystemSound.play(SystemSoundType.alert);
          });
        } catch (_) {
          SystemSound.play(SystemSoundType.alert);
        }
      }).catchError((_) {
        SystemSound.play(SystemSoundType.alert);
      });
    } catch (_) {
      try { SystemSound.play(SystemSoundType.alert); } catch (_) {}
    }
  }

  void _triggerStatusHaptic(OrderStatus? newStatus, OrderStatus? oldStatus) {
    if (newStatus == null || oldStatus == newStatus) return;
    _playStatusChime();
    // Elegant, non-intrusive micro-haptic clicks (Swiggy/Zepto style: zero annoying continuous buzzing)
    switch (newStatus) {
      case OrderStatus.confirmed:
      case OrderStatus.packed:
      case OrderStatus.shipped:
        HapticFeedback.lightImpact();
        break;
      case OrderStatus.delivered:
        HapticFeedback.mediumImpact();
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
    String resolveCleanTrackingId() {
      final rawReadable = _order?.readableId?.trim();
      if (rawReadable != null &&
          rawReadable.isNotEmpty &&
          !rawReadable.toLowerCase().contains('ord') &&
          rawReadable.length <= 10) {
        final clean = rawReadable.replaceAll('#', '').replaceAll('FK-', '').trim();
        return clean.startsWith('FK-') ? '#$clean' : '#FK-$clean';
      }
      final rawDisplay = _order?.displayId.replaceAll('#', '').trim() ?? '';
      if (rawDisplay.isNotEmpty &&
          !rawDisplay.toLowerCase().contains('ord') &&
          rawDisplay.length <= 10) {
        return rawDisplay.startsWith('FK-') ? '#$rawDisplay' : '#FK-$rawDisplay';
      }
      final raw = widget.orderId.replaceAll('#', '').replaceAll('FK-', '').trim();
      final clean = raw.replaceAll('order_', '').replaceAll('ord_', '').replaceAll('_', '').trim();
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 4) {
        return '#FK-${digits.substring(digits.length - 4)}';
      }
      if (clean.length >= 4) {
        return '#FK-${clean.substring(clean.length - 4).toUpperCase()}';
      }
      return '#FK-$clean';
    }

    final cleanDisplayId = resolveCleanTrackingId();

    final cancelReason = await SwiggyCancelBottomSheet.show(
      context: context,
      displayId: cleanDisplayId,
      isPaid: isPaid,
      totalAmount: totalAmount,
    );

    if (cancelReason == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isCancelling = true);

    try {
      final dio = ref.read(dioProvider);
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      await dio.patch('/api/orders/$cleanId', data: {
        'status': 'CANCELLED',
        'cancelReason': cancelReason,
      });

      await NotificationService().clearLiveOrderActivity(
        _order?.id ?? cleanId,
        readableId: _order?.readableId ?? cleanId,
      );
      if (!mounted) return;
      ref.invalidate(ordersProvider(''));

      if (mounted) {
        AppToast.showSuccess(
          context,
          'Order Cancelled',
          subtitle: 'Your order was successfully cancelled.',
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
        AppToast.showError(
          context,
          'Cancellation Failed',
          subtitle: errorMsg,
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
    final displayNum = _order?.displayId ?? (_order?.readableId ?? widget.orderId);

    final shouldSwitch = await AppConfirmationDialog.showCODConversion(
      context: context,
      displayId: displayNum,
      totalAmount: grandTotal,
      queueMessage: 'Pay with cash or rider QR/UPI upon doorstep delivery',
    );

    if (shouldSwitch != true || !mounted) return;

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
        AppToast.showSuccess(
          context,
          'Switched to COD',
          subtitle: 'Order payment switched to Cash on Delivery (COD)!',
        );
      }

      await _fetchLiveOrder();
    } catch (e) {
      LoggerService.error("Switch COD error", e);
      if (mounted) {
        AppToast.showError(
          context,
          'Switch Failed',
          subtitle: 'Failed to switch to COD. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  /// High-reliability multi-channel GPS sync from /api/delivery/location
  Future<void> _syncRiderLocationFromEndpoint(Order order) async {
    if (order.status != OrderStatus.shipped && order.status != OrderStatus.packed) return;
    try {
      final dio = ref.read(dioProvider);
      var cleanId = widget.orderId.trim().replaceAll('#', '');
      final candidateIds = <String>{
        cleanId,
        order.id,
        if (order.readableId != null && order.readableId!.isNotEmpty)
          order.readableId!.replaceAll('#', '').trim(),
        if (order.combinedId != null && order.combinedId!.isNotEmpty)
          order.combinedId!.replaceAll('#', '').trim(),
        if (cleanId.startsWith('FK-')) cleanId.substring(3),
        if (RegExp(r'^\d+$').hasMatch(cleanId)) 'FK-$cleanId',
      };

      for (final qId in candidateIds) {
        try {
          final locRes = await dio.get('/api/delivery/location', queryParameters: {'orderId': qId});
          if (locRes.data is Map<String, dynamic>) {
            final locData = locRes.data as Map<String, dynamic>;
            final riderMap = locData['rider'] is Map<String, dynamic>
                ? locData['rider'] as Map<String, dynamic>
                : null;
            final rLat = (riderMap?['lat'] as num?)?.toDouble() ??
                (locData['deliveryLat'] as num?)?.toDouble() ??
                (locData['lat'] as num?)?.toDouble() ??
                (locData['latitude'] as num?)?.toDouble();
            final rLng = (riderMap?['lng'] as num?)?.toDouble() ??
                (locData['deliveryLng'] as num?)?.toDouble() ??
                (locData['lng'] as num?)?.toDouble() ??
                (locData['longitude'] as num?)?.toDouble();
            final heading = ((riderMap?['heading'] ?? locData['heading'] ?? locData['bearing']) as num?)?.toDouble() ?? 0.0;
            if (rLat != null && rLng != null && rLat != 0.0 && rLng != 0.0) {
              _updateRiderLocation(LatLng(rLat, rLng), heading);
              break;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _silentPollOrder() async {
    if (!mounted || _isDisposed) return;
    try {
      final repo = OrderRepository(ref.read(dioProvider));
      var cleanId = widget.orderId.trim();
      if (cleanId.startsWith('#')) cleanId = cleanId.substring(1);

      final order = await repo.getOrder(cleanId);
      if (order == null) return;
      if (mounted) {
        final prevStatus = _order?.status;
        setState(() => _order = order);

        NotificationService().updateLiveOrderActivity(
          order: order,
          customEtaText: _etaText.isNotEmpty ? _etaText : null,
        );

        _triggerStatusHaptic(order.status, prevStatus);

        // Stale-data protection: if live GPS arrived in last 15 seconds,
        // don't let polled DB coordinates snap the rider marker backwards
        final hasRecentLiveGps = _lastLocationUpdateTime != null &&
            DateTime.now().difference(_lastLocationUpdateTime!).inSeconds < 15;

        if (!hasRecentLiveGps) {
          _setupCoordinatesFromOrder(order);
        }

        // 🛵 Active Delivery GPS sync directly from delivery location endpoint
        await _syncRiderLocationFromEndpoint(order);
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
      final restSub = order.subOrders!.firstWhereOrNull((s) => s.isRestaurantOrder);
      if (restSub != null) {
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
    } else {
      _restaurantPosition = null;
      _restaurantOutlet = null;
    }

    // 4. Rider Position
    if (order.status == OrderStatus.shipped || order.status == OrderStatus.packed) {
      bool hasValidRiderCoords = false;
      if (order.deliveryLat != null && order.deliveryLng != null && order.deliveryLat != 0.0 && order.deliveryLng != 0.0) {
        // Sanity check: Ensure deliveryLat/Lng isn't an accidental copy of customer position
        if (_customerPosition != null) {
          final distToCust = Geolocator.distanceBetween(
            order.deliveryLat!,
            order.deliveryLng!,
            _customerPosition!.latitude,
            _customerPosition!.longitude,
          );
          if (distToCust > 35.0 || order.status == OrderStatus.delivered) {
            hasValidRiderCoords = true;
          }
        } else {
          hasValidRiderCoords = true;
        }
      }

      if (hasValidRiderCoords) {
        _updateRiderLocation(LatLng(order.deliveryLat!, order.deliveryLng!), 0.0);
      } else if (_riderPosition == null && _storePosition != null) {
        // Rider starts at the store/kitchen
        _updateRiderLocation(_storePosition!, 0.0);
      }
    }

    // Manage animated Polyline tween lifecycle during active delivery
    try {
      if (order.status == OrderStatus.shipped) {
        if (!_polyTweenController.isAnimating) {
          _polyTweenController.repeat();
        }
      } else if (order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled) {
        if (_polyTweenController.isAnimating) {
          _polyTweenController.stop();
        }
      }
    } catch (_) {}

    _refreshMapElements();
    _calculateETA();
  }

  /// Calculate bearing between two geographic coordinates (degrees 0-360)
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    return GeoMathUtils.calculateBearing(lat1, lng1, lat2, lng2);
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
    if (!mounted || _prevRiderPosition == null || _targetRiderPosition == null) return;
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
        zIndexInt: 10,
      ));
    }
    if (!mounted) return;
    setState(() {});

    // Dynamic route truncation behind rider (100% on device, 0 API calls)
    _trimPolylineBehindRider(_riderPosition!);

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

  /// Polyline tween animation tick: modulates soft ambient glow pulse beneath the solid line
  void _onPolyTweenTick() {
    if (!mounted || _polylines.isEmpty) return;
    if (_order?.status != OrderStatus.shipped && _order?.status != OrderStatus.packed) return;

    final t = _polyTweenController.value;
    final alpha = (0.16 + 0.12 * math.sin(t * 2 * math.pi)).clamp(0.12, 0.32);

    final shadowRoute = _polylines.firstWhereOrNull((p) => p.polylineId.value == 'delivery_route_shadow');
    if (shadowRoute != null) {
      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'delivery_route_shadow');
        _polylines.add(
          shadowRoute.copyWith(
            colorParam: const Color(0xFF00C853).withValues(alpha: alpha),
          ),
        );
      });
    }
  }

  /// Truncates the route polyline ahead of the rider using local Haversine geometry.
  /// Zero external API calls, pure device math like Blinkit/Swiggy.
  void _trimPolylineBehindRider(LatLng riderPos) {
    if (_roadPolylinePoints.length < 2) return;

    // Find the closest point index on the polyline to the current rider position
    int closestIdx = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _roadPolylinePoints.length; i++) {
      final d = _getHaversineDistance(riderPos, _roadPolylinePoints[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIdx = i;
      }
    }

    // Only truncate if rider is within reasonable road tolerance (< 150 meters)
    if (minDistance < 0.15 && closestIdx < _roadPolylinePoints.length - 1) {
      _coveredPolylinePoints.clear();
      _coveredPolylinePoints.addAll([
        ..._roadPolylinePoints.sublist(0, closestIdx),
        riderPos,
      ]);
      final remainingPoints = <LatLng>[riderPos, ..._roadPolylinePoints.sublist(closestIdx + 1)];

      _polylines.removeWhere((p) =>
          p.polylineId.value == 'delivery_route' ||
          p.polylineId.value == 'delivery_route_shadow' ||
          p.polylineId.value == 'delivery_route_covered');

      if (_coveredPolylinePoints.length >= 2) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('delivery_route_covered'),
            points: _coveredPolylinePoints,
            color: const Color(0xFFCBD5E1), // Swiggy/Zomato muted slate for covered path
            width: 4,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: remainingPoints,
          color: const Color(0xFF00C853), // Electric emerald solid active line (Zero cut dashes!)
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route_shadow'),
          points: remainingPoints,
          color: const Color(0xFF00C853).withValues(alpha: 0.22),
          width: 10,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }
  }

  /// Calculate distance & estimated arrival time using Haversine formula (Throttled, No excess API calls)
  void _calculateETA() {
    if (_customerPosition == null) return;
    final start = _riderPosition ?? _storePosition ?? _customerPosition!;
    final distanceKm = _getHaversineDistance(start, _customerPosition!);

    setState(() {
      if (_order?.status == OrderStatus.shipped) {
        // 🛵 Out for Delivery: Show clean, professional distance metric
        if (distanceKm < 0.08) {
          _distanceText = 'At your doorstep';
        } else if (distanceKm < 1.0) {
          _distanceText = '${(distanceKm * 1000).round()}m away';
        } else {
          _distanceText = '${distanceKm.toStringAsFixed(1)} km away';
        }

        // Check proximity: when rider is within 120m of customer gate, trigger Arrival chime
        if (distanceKm <= 0.12 && !_hasPlayedArrivalChime) {
          _hasPlayedArrivalChime = true;
          _playStatusChime();
          HapticFeedback.heavyImpact();
        }

        // Realistic ETA calculation with speed history or distance-aware fallback
        if (distanceKm < 0.08) {
          _etaText = 'Arriving now';
        } else {
          int estMinutes;
          if (_riderPosition != null && distanceKm > 0.05) {
            estMinutes = GeoMathUtils.estimateEtaWeightedAverage(
              _riderPosition!,
              _customerPosition!,
              distanceKm,
            );
          } else {
            // Speed model: ~22 km/h city average + 2 mins buffer for signals/turns
            final driveMinutes = ((distanceKm / 22.0) * 60).round();
            estMinutes = math.max(3, driveMinutes + 2);
          }
          _etaText = '$estMinutes mins';
        }

        if (_order != null) {
          NotificationService().updateLiveOrderActivity(
            order: _order!,
            customEtaText: _etaText,
          );
        }
      } else if (_order?.status == OrderStatus.delivered) {
        _etaText = 'Delivered 🎉';
        _distanceText = '';
        if (_order != null) {
          NotificationService().clearLiveOrderActivity(_order!.id, readableId: _order!.readableId);
        }
      } else {
        // Before Out for Delivery (adminPending, pending, confirmed, packed):
        // Neither ETA nor distance should be shown until order is Out for Delivery!
        _etaText = '';
        _distanceText = '';
      }
    });
  }

  double _getHaversineDistance(LatLng pos1, LatLng pos2) {
    return GeoMathUtils.getHaversineDistance(pos1, pos2);
  }

  Future<void> _initCustomMarkers() async {
    try {
      final markers = await MapMarkerGenerator.initCustomMarkers();
      _storeMarkerIcon = markers['store'];
      _restaurantMarkerIcon = markers['restaurant'];
      _riderMarkerIcon = markers['rider'];
      _customerMarkerIcon = markers['customer'];
      if (mounted) {
        setState(() {
          _refreshMapElements();
        });
      }
    } catch (e) {
      LoggerService.error("Init custom markers error", e);
    }
  }

  List<LatLng> _roadPolylinePoints = [];
  LatLng? _lastRouteStart;
  LatLng? _lastRouteEnd;
  bool _isFetchingRoute = false;

  void _applyRoutePoints(List<LatLng> points, LatLng start, LatLng end) {
    if (!mounted || points.isEmpty) return;
    _lastRouteStart = start;
    _lastRouteEnd = end;
    setState(() {
      _roadPolylinePoints = points;
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: _roadPolylinePoints,
          color: const Color(0xFF00C853), // Electric emerald continuous route (Zero cuts/dashes!)
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route_shadow'),
          points: _roadPolylinePoints,
          color: const Color(0xFF00C853).withValues(alpha: 0.24),
          width: 10,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    });
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    if (_isFetchingRoute) return;

    if (_lastRouteStart != null && _lastRouteEnd != null) {
      final dStart = _getHaversineDistance(_lastRouteStart!, start);
      final dEnd = _getHaversineDistance(_lastRouteEnd!, end);
      if (dStart < 0.05 && dEnd < 0.05 && _roadPolylinePoints.length > 2) {
        return; // Position hasn't significantly moved (>50m)
      }
    }

    _isFetchingRoute = true;
    try {
      final points = await RoutePolylineService.fetchRoadRoute(
        start: start,
        end: end,
        backendDio: ref.read(dioProvider),
      );
      if (points != null && points.isNotEmpty) {
        _applyRoutePoints(points, start, end);
      } else {
        _applyRoutePoints([start, end], start, end);
      }
    } catch (e) {
      LoggerService.info('Road route fetch fallback: $e');
      _applyRoutePoints([start, end], start, end);
    } finally {
      if (mounted) {
        _isFetchingRoute = false;
      }
    }
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
        ),
      );
    } else if (_storePosition != null) {
      // Single Order: Darkstore OR Specific Restaurant (A.S. Restaurant, Wedson, etc.)
      final isRest = _primaryOutlet?.isRestaurant == true;

      markers.add(
        Marker(
          markerId: const MarkerId('store'),
          position: _storePosition!,
          anchor: const Offset(0.5, 0.8),
          icon: isRest
              ? (_restaurantMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
              : (_storeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
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
        ),
      );
    }

    // 3. Live Moving Rider Marker (Single marker, real-time GPS oriented)
    if (_riderPosition != null && (_order?.status == OrderStatus.shipped || _order?.status == OrderStatus.packed)) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: _riderPosition!,
          icon: _riderMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          rotation: _riderHeading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 15,
        ),
      );
    }

    // 4. Trigger Turn-by-Turn Road-Wise Polyline Route (Zero-load: fetched once or on major deviation)
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

    final circles = <Circle>{};
    if (_customerPosition != null) {
      circles.add(
        Circle(
          circleId: const CircleId('customer_drop_halo'),
          center: _customerPosition!,
          radius: 65,
          fillColor: const Color(0xFF10B981).withValues(alpha: 0.12),
          strokeColor: const Color(0xFF10B981).withValues(alpha: 0.45),
          strokeWidth: 2,
        ),
      );
    }

    final polylines = <Polyline>{};
    if (polylineCoords.length >= 2) {
      if (_coveredPolylinePoints.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('delivery_route_covered'),
            points: _coveredPolylinePoints,
            color: const Color(0xFFCBD5E1),
            width: 4,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        );
      }
      // Main route line (Electric emerald continuous ribbon)
      polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: polylineCoords,
          color: const Color(0xFF00C853),
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
      // Subtle ambient shadow line underneath
      polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route_shadow'),
          points: polylineCoords,
          color: const Color(0xFF00C853).withValues(alpha: 0.24),
          width: 10,
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
      _circles.clear();
      _circles.addAll(circles);
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
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 13.8));
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
      final latMargin = math.max(0.008, latSpan * 0.45);
      final lngMargin = math.max(0.008, lngSpan * 0.45);

      final bounds = LatLngBounds(
        southwest: LatLng(minLat - latMargin, minLng - lngMargin),
        northeast: LatLng(maxLat + latMargin, maxLng + lngMargin),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 45));
    } catch (e) {
      debugPrint('[OrderTracking] _fitMapBounds error: $e');
    }
  }

  void _followRiderWithCamera() {
    if (_mapController == null || _riderPosition == null || !mounted) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _riderPosition!,
          zoom: 14.8,
          bearing: _riderHeading,
          tilt: 15.0,
        ),
      ),
    );
  }

  int _getStatusStep(OrderStatus? status) {
    if (status == null) return 0;

    // Safety guard for combined orders: if any active sub-order is not delivered,
    // the status step MUST NOT advance to Delivered (4)!
    if (_order != null && (_order!.isCombined || (_order!.subOrders != null && _order!.subOrders!.isNotEmpty)) && _order!.subOrders != null && _order!.subOrders!.isNotEmpty) {
      final activeSubs = _order!.subOrders!.where((s) => s.status != OrderStatus.cancelled).toList();
      if (activeSubs.isNotEmpty && !activeSubs.every((s) => s.status == OrderStatus.delivered)) {
        if (activeSubs.any((s) => s.status == OrderStatus.adminPending || s.status == OrderStatus.pending)) {
          return 0; // Stage 0: Admin & Store Verification
        } else if (activeSubs.any((s) => s.status == OrderStatus.confirmed)) {
          return 1; // Stage 1: Order Confirmed & Accepted
        } else if (activeSubs.any((s) => s.status == OrderStatus.packed)) {
          return 2; // Stage 2: Ready for Pickup / Packed in Bag
        } else if (activeSubs.any((s) => s.status == OrderStatus.shipped)) {
          return 3; // Stage 3: Out for Delivery (Rider in Transit)
        }
      } else if (activeSubs.isNotEmpty && activeSubs.every((s) => s.status == OrderStatus.delivered)) {
        return 4; // Stage 4: Delivered Safely
      }
    }

    switch (status) {
      case OrderStatus.adminPending:
      case OrderStatus.pending:
        return 0; // Stage 0: Admin & Store Verification
      case OrderStatus.confirmed:
        return 1; // Stage 1: Order Confirmed & Accepted
      case OrderStatus.packed:
        return 2; // Stage 2: Ready for Pickup / Packed in Bag
      case OrderStatus.shipped:
        return 3; // Stage 3: Out for Delivery (Rider in Transit)
      case OrderStatus.delivered:
        return 4; // Stage 4: Delivered Safely
      case OrderStatus.cancelled:
        return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStep = _getStatusStep(_order?.status);
    final isCancelled = _order?.status == OrderStatus.cancelled || statusStep == -1;
    final isDelivered = (_order?.status == OrderStatus.delivered || statusStep >= 4) &&
        (_order?.subOrders == null || _order!.subOrders!.isEmpty || _order!.subOrders!.where((s) => s.status != OrderStatus.cancelled).every((s) => s.status == OrderStatus.delivered));
    final isPaid = _order?.paymentStatus == 'PAID';
    String resolveCleanTrackingId() {
      final rawReadable = _order?.readableId?.trim();
      if (rawReadable != null &&
          rawReadable.isNotEmpty &&
          !rawReadable.toLowerCase().contains('ord') &&
          rawReadable.length <= 10) {
        final clean = rawReadable.replaceAll('#', '').replaceAll('FK-', '').trim();
        return clean.startsWith('FK-') ? '#$clean' : '#FK-$clean';
      }
      final rawDisplay = _order?.displayId.replaceAll('#', '').trim() ?? '';
      if (rawDisplay.isNotEmpty &&
          !rawDisplay.toLowerCase().contains('ord') &&
          rawDisplay.length <= 10) {
        return rawDisplay.startsWith('FK-') ? '#$rawDisplay' : '#FK-$rawDisplay';
      }
      final raw = widget.orderId.replaceAll('#', '').replaceAll('FK-', '').trim();
      final clean = raw.replaceAll('order_', '').replaceAll('ord_', '').replaceAll('_', '').trim();
      final digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 4) {
        return '#FK-${digits.substring(digits.length - 4)}';
      }
      if (clean.length >= 4) {
        return '#FK-${clean.substring(clean.length - 4).toUpperCase()}';
      }
      return '#FK-$clean';
    }

    final cleanDisplayId = resolveCleanTrackingId();
    final isPreConfirmation = (_order?.status == OrderStatus.pending || _order?.status == OrderStatus.adminPending);
    // User requested rule: Can freely cancel as long as admin/store has not verified/accepted order
    final canCancel = isPreConfirmation &&
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
              ? _buildTrackingSkeleton(context)
              : (isDelivered || isCancelled)
                  ? ResponsiveContainer(
                      maxWidth: Responsive.defaultMaxContentWidth,
                      fillHeight: true,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context).clamp(12.0, 20.0), 10, Responsive.horizontalPadding(context).clamp(12.0, 20.0), 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Offline Network Recovery Banner
                            OfflineBanner(
                              onRetry: () {
                                _fetchLiveOrder();
                              },
                              offlineText: 'Offline • Live tracking paused',
                              onlineText: 'Back Online • Live tracking updated',
                            ),

                            // Cancelled Order Alert Card
                            if (isCancelled) ...[
                              const TrackingCancelCard(),
                              const SizedBox(height: 14),
                            ],

                            // Refund Notice Card (If applicable)
                            if ((_order?.refundAmount ?? 0) > 0 || ((_order?.notes ?? '').toLowerCase().contains('refund'))) ...[
                              TrackingRefundNoticeCard(order: _order),
                              const SizedBox(height: 11),
                            ],

                            // Gift Card Share & Live Tracking Card (When order is a gift or has gift card)
                            if (_isGiftOrder(_order)) ...[
                              _buildTrackingGiftShareCard(_order!),
                              const SizedBox(height: 11),
                            ],

                            // Multi-Stage Order Stepper (Live status, ETA & milestones)
                            TrackingStatusStepper(
                              order: _order,
                              statusStep: statusStep,
                              isDelivered: isDelivered,
                              isCancelled: isCancelled,
                              cleanDisplayId: cleanDisplayId,
                              etaText: _etaText,
                              distanceText: _distanceText,
                            ),
                            const SizedBox(height: 11),

                            // Delivery Address Card
                            if (_order?.deliveryMethod != 'PICKUP') ...[
                              TrackingDestinationCard(order: _order),
                              const SizedBox(height: 12),
                            ],

                            // Order Items & Receipt Card (Bill Details)
                            TrackingReceiptCard(order: _order),
                            const SizedBox(height: 14),

                            // Review Card (If delivered)
                            if (isDelivered) ...[
                              TrackingReviewCard(order: _order),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // ── 1. HERO MAP VIEWPORT (Blinkit / Zepto Style, Top 44% or Fullscreen) ──
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          height: _isMapExpanded
                              ? (MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top - kToolbarHeight)
                              : (MediaQuery.sizeOf(context).height * 0.44).clamp(280.0, 420.0),
                          child: TrackingMapView(
                            initialTarget: initialTarget,
                            isDelivered: isDelivered,
                            order: _order,
                            markers: _markers,
                            polylines: _polylines,
                            circles: _circles,
                            primaryOutlet: _primaryOutlet,
                            restaurantOutlet: _restaurantOutlet,
                            etaText: _etaText,
                            distanceText: _distanceText,
                            statusStep: statusStep,
                            isMapExpanded: _isMapExpanded,
                            onToggleExpand: () {
                              HapticFeedback.mediumImpact();
                              setState(() => _isMapExpanded = !_isMapExpanded);
                              Future.delayed(const Duration(milliseconds: 350), () {
                                if (mounted) _fitMapBounds();
                              });
                            },
                            onMapCreated: (controller) {
                              _mapController = controller;
                              Future.delayed(const Duration(milliseconds: 350), () {
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
                        ),

                        // ── 2. BOTTOM SLIDING CONTENT SHEET (Animated Slide & Fade Transition) ──
                        if (!_isMapExpanded)
                          Expanded(
                            child: AnimatedSlide(
                              offset: _isMapExpanded ? const Offset(0, 1) : Offset.zero,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeInOutCubic,
                              child: AnimatedOpacity(
                                opacity: _isMapExpanded ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 240),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x140F172A),
                                        blurRadius: 18,
                                        offset: Offset(0, -4),
                                      ),
                                    ],
                                  ),
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      Responsive.horizontalPadding(context).clamp(12.0, 20.0),
                                      6,
                                      Responsive.horizontalPadding(context).clamp(12.0, 20.0),
                                      36,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Subtle Animated Drag Handle Pill
                                        Center(
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 250),
                                            width: 38,
                                            height: 4.5,
                                            margin: const EdgeInsets.only(top: 4, bottom: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCBD5E1),
                                              borderRadius: BorderRadius.circular(3),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.04),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Offline Network Recovery Banner
                                        OfflineBanner(
                                          onRetry: () {
                                            _fetchLiveOrder();
                                          },
                                          offlineText: 'Offline • Live tracking paused',
                                          onlineText: 'Back Online • Live tracking updated',
                                        ),

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

                                        // 🌟 Hero Live Status & Accurate ETA Card (Blinkit/Zepto Ultra-Clean White Style)
                                        Builder(
                                          builder: (context) {
                                            String heroTitle;
                                            String heroSubtitle;
                                            IconData heroIcon;
                                            Color heroAccent;
                                            String statusBadgeText;

                                            final riderName = _order?.deliveryBoyName?.trim().isNotEmpty == true
                                                ? _order!.deliveryBoyName!.trim()
                                                : (_order?.deliveryUser?.name?.trim().isNotEmpty == true
                                                    ? _order!.deliveryUser!.name!.trim()
                                                    : '');

                                            if (statusStep >= 3) {
                                              // Out for Delivery (SHIPPED)
                                              heroAccent = const Color(0xFF16A34A);
                                              heroIcon = Icons.two_wheeler_rounded;
                                              statusBadgeText = 'ON THE WAY';

                                              if (_etaText.isNotEmpty && _etaText != 'Delivered 🎉') {
                                                heroTitle = _etaText == 'Arriving now' ? 'Arriving Now!' : 'Arriving in $_etaText';
                                                final isAtDoorstep = _distanceText.toLowerCase().contains('doorstep');
                                                heroSubtitle = riderName.isNotEmpty
                                                    ? (isAtDoorstep
                                                        ? '$riderName has arrived at your doorstep • Live GPS'
                                                        : '$riderName is on the way • ${_distanceText.isNotEmpty ? '$_distanceText • ' : ''}Live GPS')
                                                    : (_distanceText.isNotEmpty
                                                        ? (isAtDoorstep
                                                            ? 'Rider has arrived at your doorstep • Live GPS'
                                                            : (_distanceText.toLowerCase().contains('away')
                                                                ? '$_distanceText • Live GPS Tracking'
                                                                : '$_distanceText away • Live GPS Tracking'))
                                                        : 'Rider is on the way to your doorstep');
                                              } else if (_order?.estimatedDelivery != null && _order!.estimatedDelivery!.isAfter(DateTime.now())) {
                                                final est = _order!.estimatedDelivery!;
                                                final hourMin = "${est.hour > 12 ? est.hour - 12 : (est.hour == 0 ? 12 : est.hour)}:${est.minute.toString().padLeft(2, '0')} ${est.hour >= 12 ? 'PM' : 'AM'}";
                                                heroTitle = 'Expected by $hourMin';
                                                heroSubtitle = riderName.isNotEmpty
                                                    ? '$riderName is delivering your order'
                                                    : 'Rider is heading to your doorstep';
                                              } else {
                                                heroTitle = 'Out for Delivery';
                                                final isAtDoorstep = _distanceText.toLowerCase().contains('doorstep');
                                                heroSubtitle = riderName.isNotEmpty
                                                    ? (isAtDoorstep
                                                        ? '$riderName has arrived at your doorstep • Live GPS'
                                                        : '$riderName is on the way • ${_distanceText.isNotEmpty ? _distanceText : 'Live GPS'}')
                                                    : (_distanceText.isNotEmpty
                                                        ? (isAtDoorstep
                                                            ? 'Rider has arrived at your doorstep • Live GPS'
                                                            : (_distanceText.toLowerCase().contains('away')
                                                                ? '$_distanceText • On the way'
                                                                : '$_distanceText away • On the way'))
                                                        : 'Rider is heading to your doorstep');
                                              }
                                            } else if (statusStep == 2) {
                                              // Packed / Rider Assigned
                                              heroAccent = const Color(0xFF0284C7);
                                              heroIcon = Icons.inventory_2_rounded;
                                              statusBadgeText = 'PACKED';
                                              heroTitle = 'Order Packed';
                                              heroSubtitle = riderName.isNotEmpty
                                                  ? '$riderName is assigned & picking up package'
                                                  : 'Delivery partner is picking up your package';
                                            } else if (statusStep == 1) {
                                              // Confirmed & Preparing
                                              heroAccent = const Color(0xFF059669);
                                              heroIcon = Icons.check_circle_outline_rounded;
                                              statusBadgeText = 'CONFIRMED';
                                              heroTitle = 'Order Confirmed';
                                              heroSubtitle = 'Store accepted your order & preparing dispatch';
                                            } else {
                                              // Admin & Store Verification (statusStep == 0)
                                              heroAccent = const Color(0xFFD97706);
                                              heroIcon = Icons.fact_check_outlined;
                                              statusBadgeText = 'VERIFYING';
                                              heroTitle = 'Store Verification';
                                              final rawShop = _order?.shopName?.trim();
                                              final storeName = (rawShop != null && rawShop.isNotEmpty)
                                                  ? rawShop.replaceAll('FastKirana', 'FastMinute').replaceAll('fastkirana', 'fastminute')
                                                  : 'Ghatampur Hub';
                                              heroSubtitle = '$storeName is verifying stock & freshness';
                                            }

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: heroAccent.withValues(alpha: 0.28),
                                                  width: 1.2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: heroAccent.withValues(alpha: 0.08),
                                                    blurRadius: 16,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                  BoxShadow(
                                                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  // Live Animated Breathing Icon Aura
                                                  AnimatedBuilder(
                                                    animation: _heroPulseAnim,
                                                    builder: (context, _) => Transform.scale(
                                                      scale: _heroPulseAnim.value,
                                                      child: Container(
                                                        width: 38,
                                                        height: 38,
                                                        decoration: BoxDecoration(
                                                          color: heroAccent.withValues(alpha: 0.12),
                                                          shape: BoxShape.circle,
                                                          border: Border.all(
                                                            color: heroAccent.withValues(alpha: 0.28),
                                                            width: 1.2,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: heroAccent.withValues(alpha: 0.20),
                                                              blurRadius: 8 * _heroPulseAnim.value,
                                                              spreadRadius: 1.0,
                                                            ),
                                                          ],
                                                        ),
                                                        child: Center(
                                                          child: Icon(heroIcon, color: heroAccent, size: 20),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Wrap(
                                                          crossAxisAlignment: WrapCrossAlignment.center,
                                                          spacing: 6,
                                                          runSpacing: 3,
                                                          children: [
                                                            AnimatedSwitcher(
                                                              duration: const Duration(milliseconds: 300),
                                                              transitionBuilder: (child, anim) => FadeTransition(
                                                                opacity: anim,
                                                                child: SlideTransition(
                                                                  position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
                                                                  child: child,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                heroTitle,
                                                                key: ValueKey(heroTitle),
                                                                style: GoogleFonts.inter(
                                                                  fontSize: Responsive.scaledFontSize(context, 14.5),
                                                                  fontWeight: FontWeight.w900,
                                                                  color: const Color(0xFF0F172A),
                                                                  letterSpacing: -0.3,
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: heroAccent.withValues(alpha: 0.12),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                statusBadgeText,
                                                                style: GoogleFonts.inter(
                                                                  fontSize: Responsive.scaledFontSize(context, 9.0),
                                                                  fontWeight: FontWeight.w800,
                                                                  color: heroAccent,
                                                                  letterSpacing: 0.4,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Row(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            AnimatedBuilder(
                                                              animation: _heroPulseAnim,
                                                              builder: (context, _) => Container(
                                                                margin: const EdgeInsets.only(top: 4),
                                                                width: 5.5,
                                                                height: 5.5,
                                                                decoration: BoxDecoration(
                                                                  color: heroAccent,
                                                                  shape: BoxShape.circle,
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: heroAccent.withValues(alpha: 0.5 * _heroPulseAnim.value),
                                                                      blurRadius: 4 * _heroPulseAnim.value,
                                                                      spreadRadius: 1.2,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 5),
                                                            Expanded(
                                                              child: AnimatedSwitcher(
                                                                duration: const Duration(milliseconds: 300),
                                                                child: Text(
                                                                  heroSubtitle,
                                                                  key: ValueKey(heroSubtitle),
                                                                  style: GoogleFonts.inter(
                                                                    fontSize: Responsive.scaledFontSize(context, 11.0),
                                                                    fontWeight: FontWeight.w600,
                                                                    color: const Color(0xFF475569),
                                                                    letterSpacing: -0.1,
                                                                    height: 1.25,
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
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
                                          },
                                        ),
                                        const SizedBox(height: 12),

                                    // Store Preparing Card (displayed during preparing / confirmed stages)
                                    if (statusStep < 3) ...[
                                      TrackingPreparingCard(order: _order),
                                      const SizedBox(height: 11),
                                    ],

                                    // Refund Notice Card (If applicable)
                                    if ((_order?.refundAmount ?? 0) > 0 || ((_order?.notes ?? '').toLowerCase().contains('refund'))) ...[
                                      TrackingRefundNoticeCard(order: _order),
                                      const SizedBox(height: 11),
                                    ],

                                    // Gift Card Share & Live Tracking Card (When order is a gift or has gift card)
                                    if (_isGiftOrder(_order)) ...[
                                      _buildTrackingGiftShareCard(_order!),
                                      const SizedBox(height: 11),
                                    ],

                                    // 2. Rider Profile & Contact Card (When Assigned/Out for Delivery)
                                    if (statusStep >= 2 && !isDelivered && !isCancelled) ...[
                                      TrackingRiderCard(order: _order),
                                      const SizedBox(height: 11),
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
                                    const SizedBox(height: 11),

                                    // Pre-Confirmation Cancel Option Banner (5-min window)
                                    if (canCancel) ...[
                                      TrackingCancelBanner(
                                        isCancelling: _isCancelling,
                                        onCancel: _confirmAndCancelOrder,
                                        createdAt: _order?.createdAt,
                                      ),
                                      const SizedBox(height: 11),
                                    ],

                                    // 4. Delivery Address Card
                                    if (_order?.deliveryMethod != 'PICKUP') ...[
                                      TrackingDestinationCard(order: _order),
                                      const SizedBox(height: 12),
                                    ],

                                    // 5. Sponsored Partner Ad Banner (Placed between Address and Bill Details)
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final bannersAsync = ref.watch(bannersProvider('sponsored_ad'));
                                        return bannersAsync.when(
                                          data: (banners) {
                                            final activeBanner = banners.where((b) => b.isActive).firstOrNull;
                                            if (activeBanner != null) {
                                              final extra = activeBanner.extraData;
                                              final discountTag = extra?['discountText']?.toString() ??
                                                  extra?['eyebrowTag']?.toString() ??
                                                  'EXCLUSIVE PROMO';
                                              final btnText = extra?['actionText']?.toString() ??
                                                  extra?['ctaText']?.toString() ??
                                                  'View Details';

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 14),
                                                child: SponsoredAdCard(
                                                  title: activeBanner.title,
                                                  subtitle: activeBanner.subtitle ?? 'Special Partner Offer on FastMinute',
                                                  imageUrl: activeBanner.imageUrl,
                                                  discountText: discountTag,
                                                  actionText: btnText,
                                                  onTap: () {
                                                    if (activeBanner.link != null && activeBanner.link!.isNotEmpty) {
                                                      AppUrlLauncher.launchString(
                                                        activeBanner.link!,
                                                        context: context,
                                                        mode: LaunchMode.externalApplication,
                                                      );
                                                    }
                                                  },
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                          loading: () => const SizedBox.shrink(),
                                          error: (_, __) => const SizedBox.shrink(),
                                        );
                                      },
                                    ),

                                    // 6. Order Items & Receipt Card (Bill Details)
                                    TrackingReceiptCard(order: _order),
                                    const SizedBox(height: 14),

                                    // 7. Review Card (If delivered)
                                    if (isDelivered) ...[
                                      TrackingReviewCard(order: _order),
                                      const SizedBox(height: 12),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

          // Minimalist Luxury CRED-Style Celebration Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 36,
              gravity: 0.12,
              emissionFrequency: 0.04,
              maxBlastForce: 24,
              minBlastForce: 10,
              colors: const [
                Color(0xFFF59E0B), // Warm Gold
                Color(0xFF10B981), // Emerald
                Color(0xFF3B82F6), // Royal Blue
                Color(0xFFF43F5E), // Rose Coral
                Color(0xFF8B5CF6), // Violet Silk
                Color(0xFFFCD34D), // Champagne Gold
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isGiftOrder(Order? order) {
    if (order == null) return false;
    final notes = order.notes ?? '';
    return notes.contains('Gift Note') ||
        notes.contains('SECRET GIFT') ||
        notes.contains('Order for:') ||
        notes.contains('[SEND LIVE TRACKING LINK');
  }

  Widget _buildTrackingGiftShareCard(Order order) {
    final notes = order.notes ?? '';
    String recipient = '';
    final toMatch = RegExp(r'🎁 Order for:\s*(.*?)(?:\(|\||$)').firstMatch(notes);
    if (toMatch != null && toMatch.group(1) != null) {
      recipient = toMatch.group(1)!.trim();
    }
    if (recipient.isEmpty) {
      recipient = order.customerName?.trim().isNotEmpty == true ? order.customerName!.trim() : 'Someone Special';
    }

    String giftNote = '';
    final noteMatch = RegExp(r'💌 Gift Note:\s*(.*?)(?:\||$)').firstMatch(notes);
    if (noteMatch != null && noteMatch.group(1) != null) {
      giftNote = noteMatch.group(1)!.trim();
    }

    final trackingUrl = 'https://fastminute.in/order/${order.id}/track';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7F9), Color(0xFFFDECEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF2D3DC), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B1728).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B1728),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      'SURPRISE GIFT ORDER ACTIVE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: const Color(0xFFFFE082),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text('✨', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'To: $recipient 💝',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4A0E1C),
            ),
          ),
          if (giftNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '“$giftNote”',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B1728),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF16A34A)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Price & bill 100% hidden on delivery box',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 1. Share on WhatsApp Button
              Expanded(
                flex: 6,
                child: Bounceable(
                  onTap: () => _shareGiftOrderTracking(order, recipient, giftNote, trackingUrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Share on WhatsApp',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Copy Tracking Link Button
              Expanded(
                flex: 4,
                child: Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(text: trackingUrl));
                    AppToast.showSuccess(
                      context,
                      'Link Copied 📋',
                      subtitle: 'Gift tracking link copied to clipboard!',
                      duration: const Duration(seconds: 2),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF2D3DC), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF4A0E1C)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Copy Link',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF4A0E1C),
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
        ],
      ),
    );
  }

  Future<void> _shareGiftOrderTracking(
    Order order,
    String recipient,
    String giftNote,
    String trackingUrl,
  ) async {
    HapticFeedback.lightImpact();
    final sender = (order.customerName != null && order.customerName!.trim().isNotEmpty)
        ? order.customerName!.trim()
        : 'A loved one';
    final noteSnippet = giftNote.isNotEmpty ? '\n💌 *Personal Note:* "$giftNote"' : '';

    final shareText = '🎁 *Surprise Gift Delivery for $recipient!* ✨\n\n'
        'From: *$sender*$noteSnippet\n\n'
        '📍 *Track your live surprise delivery:* \n$trackingUrl\n\n'
        '🚀 *FastMinute Express Delivery* — Arriving soon!\n'
        '(Complimentary handwritten message card • Prices & invoice 100% hidden)';

    final whatsappUrl = 'whatsapp://send?text=${Uri.encodeComponent(shareText)}';
    final success = await AppUrlLauncher.launchSafely(
      Uri.parse(whatsappUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!success) {
      await Share.share(shareText, subject: '🎁 Surprise Gift Delivery from FastMinute');
    }
  }

  Widget _buildTrackingSkeleton(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context).clamp(12.0, 20.0);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Hero Live Status Card Skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 140, height: 20, borderRadius: BorderRadius.circular(6)),
                    ShimmerBox(width: 80, height: 22, borderRadius: BorderRadius.circular(12)),
                  ],
                ),
                const SizedBox(height: 12),
                ShimmerBox(width: 200, height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 16),
                // Stepper 4 progress pills skeleton
                Row(
                  children: List.generate(4, (index) => Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                      child: ShimmerBox(width: double.infinity, height: 6, borderRadius: BorderRadius.circular(3)),
                    ),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Map / Animation View Skeleton
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppDesignSystem.shadowCard,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: const ShimmerBox(width: double.infinity, height: 180, borderRadius: BorderRadius.zero),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Order Items & Receipt Skeleton Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppDesignSystem.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 120, height: 16, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const ShimmerBox(width: 48, height: 48, borderRadius: BorderRadius.all(Radius.circular(10))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 6),
                          ShimmerBox(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerBox(width: 100, height: 16, borderRadius: BorderRadius.circular(4)),
                    ShimmerBox(width: 70, height: 16, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
