import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/order.dart';
import '../theme/design_system.dart';
import 'logger_service.dart';

/// Zomato/Swiggy style continuous loud order alarm service for store & kitchen staff.
class OrderAlarmService {
  OrderAlarmService._() {
    _initAudioContext();
  }
  static final OrderAlarmService instance = OrderAlarmService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alarmLoopTimer;
  Timer? _autoSilenceTimer;
  bool _isPlaying = false;
  bool _isChimeBusy = false;
  bool _isMuted = false;
  String? _activeOrderId;
  bool _isModalShowing = false;
  BuildContext? _modalContext;

  Future<void> _initAudioContext() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
    } catch (e, _) {
      LoggerService.error('OrderAlarmService: init audio context error', e);
    }
  }

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  String? get activeOrderId => _activeOrderId;
  bool get isModalShowing => _isModalShowing;

  /// Toggle mute state for store / kitchen environment
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stopAlarm();
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      stopAlarm();
    }
  }

  /// Play single loud order alert chime once (Notification Buzzer on Order Alert: 1 Time)
  /// Stops immediately after playing without looping so it doesn't ring endlessly.
  Future<void> startOrderBuzzer({
    String? orderId,
  }) async {
    if (_isMuted) return;
    _activeOrderId = orderId;
    _isPlaying = true;
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = null;
    _autoSilenceTimer?.cancel();
    _autoSilenceTimer = null;

    // Play 1 time loud chime & vibration
    await _playChime();

    // Mark done after chime finishes so it doesn't loop
    _isPlaying = false;
  }

  /// Start the continuous loud alarm loop for a new order
  Future<void> startAlarm({
    required Order order,
    BuildContext? context,
    VoidCallback? onAccept,
    VoidCallback? onDismiss,
  }) async {
    if (_isMuted) return;

    _activeOrderId = order.id;
    _isPlaying = true;

    // Play initial sound & vibration
    await _playChime();

    // Loop alarm every 3.5 seconds continuously until store admin accepts or dismisses
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (!_isPlaying || _isMuted) {
        _alarmLoopTimer?.cancel();
        return;
      }
      await _playChime();
    });

    // Auto-silence buzzer after 25 seconds if not explicitly acknowledged
    _autoSilenceTimer?.cancel();
    _autoSilenceTimer = Timer(const Duration(seconds: 25), () {
      if (_isPlaying) {
        stopAlarm(closeModal: false);
      }
    });

    // If context is available, show high-priority interactive popup dialog
    if (context != null && context.mounted) {
      _showNewOrderDispatchModal(
        context: context,
        order: order,
        onAccept: onAccept,
        onDismiss: onDismiss,
      );
    }
  }

  /// Stop active alarm ringing and vibration
  Future<void> stopAlarm({bool closeModal = true}) async {
    _isPlaying = false;
    _activeOrderId = null;
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = null;
    _autoSilenceTimer?.cancel();
    _autoSilenceTimer = null;
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
    } catch (e, _) {
      LoggerService.error('OrderAlarmService: stop audio error', e);
    }
    if (closeModal && _isModalShowing && _modalContext != null) {
      final ctx = _modalContext;
      _isModalShowing = false;
      _modalContext = null;
      if (ctx != null && ctx.mounted) {
        try {
          Navigator.of(ctx).pop();
        } catch (_) {}
      }
    }
  }

  /// Plays the audio chime and triggers heavy impact haptic vibration
  Future<void> playChime() => _playChime();

  Future<void> _playChime() async {
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150), () {
        HapticFeedback.heavyImpact();
      });

      if (_isChimeBusy) return;
      _isChimeBusy = true;
      try {
        if (_audioPlayer.state == PlayerState.playing) {
          await _audioPlayer.stop();
        }
        await _audioPlayer.play(
          AssetSource('sounds/order_chime.mp3'),
          volume: 1.0,
          mode: PlayerMode.lowLatency,
        );
      } catch (e) {
        // Fallback to native system alert sound if asset playback is unavailable
        await SystemSound.play(SystemSoundType.alert);
      } finally {
        _isChimeBusy = false;
      }
    } catch (e, _) {
      LoggerService.error('OrderAlarmService: audio chime error', e);
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Interactive Modal Dialog showing order details with 1-tap Accept
  void _showNewOrderDispatchModal({
    required BuildContext context,
    required Order order,
    VoidCallback? onAccept,
    VoidCallback? onDismiss,
  }) {
    if (_isModalShowing) return;
    _isModalShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _modalContext = ctx;
        final isCombo = order.isCombined || (order.subOrders != null && order.subOrders!.length > 1);
        final baseToken = (order.readableId ?? '').replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
        final orderToken = isCombo && baseToken.isNotEmpty
            ? baseToken
            : (order.readableId ?? (order.id.length > 6 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id));
        final itemsCount = isCombo && order.subOrders != null
            ? order.subOrders!.fold<int>(0, (sum, s) => sum + (s.items?.length ?? 0))
            : (order.items?.length ?? 0);
        final totalAmount = isCombo && order.subOrders != null
            ? order.subOrders!.fold<double>(0.0, (sum, s) => sum + s.total).toInt()
            : order.total.toInt();
        String shopOrKitchen = (order.shopName ?? 'FastMinute Store').replaceAll('FastKirana', 'FastMinute');
        if (isCombo && order.subOrders != null && order.subOrders!.length > 1) {
          final restSub = order.subOrders!.cast<Order?>().firstWhere((s) => s?.isRestaurantOrder == true, orElse: () => null);
          final restName = restSub?.shopName ?? 'Restaurant Kitchen';
          shopOrKitchen = '🛒 Grocery + 🍽️ $restName';
        }

        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppDesignSystem.primary.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                  color: AppDesignSystem.primary,
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Alert Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    decoration: const BoxDecoration(
                      color: AppDesignSystem.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(21),
                        topRight: Radius.circular(21),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '🚨 NEW ORDER ARRIVED!',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      children: [
                        // Order Token & Price Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER TOKEN',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '#$orderToken',
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppDesignSystem.green100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppDesignSystem.green600.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '₹$totalAmount',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignSystem.green800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Store / Outlet Info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDesignSystem.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 16, color: AppDesignSystem.slate700),
                                  const SizedBox(width: 6),
                                  Text(
                                    shopOrKitchen,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppDesignSystem.slate800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$itemsCount Items • ${order.paymentMethod.displayName} (${order.paymentStatus.toUpperCase()})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppDesignSystem.slate600,
                                ),
                              ),
                              if (order.notes?.trim().isNotEmpty == true) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Note: ${order.notes!.trim()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: AppDesignSystem.orange700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: Dismiss & Accept
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: () {
                                  _isModalShowing = false;
                                  _modalContext = null;
                                  stopAlarm(closeModal: false);
                                  onDismiss?.call();
                                  Navigator.pop(ctx);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppDesignSystem.slate300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'Dismiss Sound',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: () {
                                  _isModalShowing = false;
                                  _modalContext = null;
                                  stopAlarm(closeModal: false);
                                  Navigator.pop(ctx);
                                  onAccept?.call();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppDesignSystem.green600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ACCEPT ORDER',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
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
            ),
          ),
        );
      },
    );
  }

  /// Start continuous alarm loop and popup dialog specifically for darkstore pickers
  Future<void> startPickerAlarm({
    required Map<String, dynamic> orderMap,
    BuildContext? context,
    VoidCallback? onStartPicking,
    VoidCallback? onDismiss,
  }) async {
    if (_isMuted) return;

    final String orderId = (orderMap['id'] ?? '').toString();
    _activeOrderId = orderId;
    _isPlaying = true;

    // Play initial chime & vibration
    await _playChime();

    // Loop alarm every 3.5 seconds until picked, packed, or dismissed
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (!_isPlaying || _isMuted) {
        _alarmLoopTimer?.cancel();
        return;
      }
      await _playChime();
    });

    if (context != null && context.mounted) {
      _showPickerOrderModal(
        context: context,
        orderMap: orderMap,
        onStartPicking: onStartPicking,
        onDismiss: onDismiss,
      );
    }
  }

  void _showPickerOrderModal({
    required BuildContext context,
    required Map<String, dynamic> orderMap,
    VoidCallback? onStartPicking,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final orderToken = (orderMap['readableId'] ?? orderMap['id'] ?? '').toString();
        final displayToken = orderToken.length > 6 ? orderToken.substring(orderToken.length - 6).toUpperCase() : orderToken;
        final rawItems = orderMap['items'];
        final int itemsCount = (rawItems is List) ? rawItems.length : 0;
        final num total = (orderMap['total'] is num)
            ? (orderMap['total'] as num)
            : (num.tryParse(orderMap['total']?.toString() ?? '0') ?? 0);

        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFEA580C),
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Alert Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEA580C),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(21),
                        topRight: Radius.circular(21),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '🚨 NEW ORDER TO PICK!',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PICKING TOKEN',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '#$displayToken',
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFED7AA)),
                              ),
                              child: Text(
                                '₹${total.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFC2410C),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Store Info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDesignSystem.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shopping_basket_rounded, size: 16, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dark Store Grocery Order',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppDesignSystem.slate800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$itemsCount Items to gather from shelves & pack',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppDesignSystem.slate600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: Dismiss & Start Picking
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: () {
                                  stopAlarm();
                                  onDismiss?.call();
                                  Navigator.pop(ctx);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppDesignSystem.slate300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'Mute',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: () {
                                  stopAlarm();
                                  Navigator.pop(ctx);
                                  onStartPicking?.call();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEA580C),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Start Picking',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
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
            ),
          ),
        );
      },
    );
  }

  /// Start continuous alarm loop and interactive popup specifically for Riders on assignment
  Future<void> startRiderAlarm({
    required Map<String, dynamic> orderMap,
    BuildContext? context,
    VoidCallback? onAccept,
    VoidCallback? onDismiss,
  }) async {
    if (_isMuted) return;

    final String status = (orderMap['status'] ?? '').toString().toUpperCase().trim();
    if (status == 'SHIPPED' || status == 'OUT_FOR_DELIVERY' || status == 'ON_THE_WAY' || status == 'DELIVERED' || status == 'CANCELLED') {
      debugPrint('[OrderAlarmService] Suppressed rider alarm for active delivery / completed order (status: $status)');
      return;
    }

    final String orderId = (orderMap['id'] ?? orderMap['readableId'] ?? '').toString();
    if (_isPlaying && _activeOrderId == orderId) return;

    _activeOrderId = orderId;
    _isPlaying = true;

    // Play initial chime & vibration
    await _playChime();

    // Loop alarm every 3.5 seconds until accepted, muted, or dismissed
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (!_isPlaying || _isMuted) {
        _alarmLoopTimer?.cancel();
        return;
      }
      await _playChime();
    });

    if (context != null && context.mounted) {
      _showRiderOrderModal(
        context: context,
        orderMap: orderMap,
        onAccept: onAccept,
        onDismiss: onDismiss,
      );
    }
  }

  void _showRiderOrderModal({
    required BuildContext context,
    required Map<String, dynamic> orderMap,
    VoidCallback? onAccept,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isCombo = orderMap['isCombined'] == true ||
            (orderMap['subOrders'] is List && (orderMap['subOrders'] as List).length > 1);
        final baseToken = (orderMap['readableId'] ?? '').toString().replaceAll(RegExp(r'-[GR\d]+$', caseSensitive: false), '');
        final rawId = (orderMap['id'] ?? '').toString();
        final rawReadable = (orderMap['readableId'] ?? '').toString();
        final orderToken = isCombo && baseToken.isNotEmpty
            ? baseToken
            : (rawReadable.isNotEmpty
                ? rawReadable
                : (rawId.length > 6
                    ? rawId.substring(rawId.length - 6).toUpperCase()
                    : rawId));

        final num total = (orderMap['total'] is num)
            ? (orderMap['total'] as num)
            : (num.tryParse(orderMap['total']?.toString() ?? '0') ?? 0);

        final pm = (orderMap['paymentMethod'] ?? '').toString().toUpperCase().trim();
        final ps = (orderMap['paymentStatus'] ?? '').toString().toUpperCase().trim();
        final isPaid = ps == 'PAID' || pm == 'ONLINE' || pm == 'UPI';

        String shopName = (orderMap['shopName'] ?? 'FastMinute Dark Store').toString().replaceAll('FastKirana', 'FastMinute');
        final rawRest = orderMap['restaurant'];
        if (rawRest is Map && rawRest['name'] != null) {
          shopName = '🍽️ ${rawRest['name']}';
        }

        // Customer details
        final addressMap = orderMap['address'] is Map
            ? orderMap['address'] as Map
            : (orderMap['addresses'] is Map ? orderMap['addresses'] as Map : null);
        final customerName = addressMap?['name'] ?? addressMap?['userName'] ?? orderMap['customerName'] ?? 'Customer';
        final customerStreet = addressMap?['street'] ?? addressMap?['address'] ?? addressMap?['area'] ?? 'Kanpur Nagar';

        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF10B981),
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Alert Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(21),
                        topRight: Radius.circular(21),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '🚨 NEW DELIVERY ASSIGNED!',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER TOKEN',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '#$orderToken',
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppDesignSystem.slate900,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${total.toInt()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isPaid ? const Color(0xFF047857) : const Color(0xFFC2410C),
                                    ),
                                  ),
                                  Text(
                                    isPaid ? 'PAID ONLINE' : 'CASH ON DELIVERY',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: isPaid ? const Color(0xFF047857) : const Color(0xFFC2410C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Pickup Location Info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppDesignSystem.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppDesignSystem.slate200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      shopName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppDesignSystem.slate800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 16, color: AppDesignSystem.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$customerName • $customerStreet',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppDesignSystem.slate600,
                                        fontWeight: FontWeight.w600,
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
                        const SizedBox(height: 20),

                        // Action Buttons: Mute & Accept/View
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                onPressed: () {
                                  stopAlarm();
                                  onDismiss?.call();
                                  Navigator.pop(ctx);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppDesignSystem.slate300),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'Mute',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppDesignSystem.slate600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: ElevatedButton(
                                onPressed: () {
                                  stopAlarm();
                                  Navigator.pop(ctx);
                                  onAccept?.call();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'View Order',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
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
            ),
          ),
        );
      },
    );
  }

}
