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
  OrderAlarmService._();
  static final OrderAlarmService instance = OrderAlarmService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _alarmLoopTimer;
  bool _isPlaying = false;
  bool _isMuted = false;
  String? _activeOrderId;

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  String? get activeOrderId => _activeOrderId;

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

  /// Start the continuous loud alarm loop for a new order
  Future<void> startAlarm({
    required Order order,
    BuildContext? context,
    VoidCallback? onAccept,
  }) async {
    if (_isMuted) return;

    _activeOrderId = order.id;
    _isPlaying = true;

    // Play initial sound & vibration
    await _playChime();

    // Loop alarm every 3.5 seconds until accepted or dismissed
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (!_isPlaying || _isMuted) {
        _alarmLoopTimer?.cancel();
        return;
      }
      await _playChime();
    });

    // If context is available, show high-priority interactive popup dialog
    if (context != null && context.mounted) {
      _showNewOrderDispatchModal(
        context: context,
        order: order,
        onAccept: onAccept,
      );
    }
  }

  /// Stop active alarm ringing and vibration
  Future<void> stopAlarm() async {
    _isPlaying = false;
    _activeOrderId = null;
    _alarmLoopTimer?.cancel();
    _alarmLoopTimer = null;
    try {
      await _audioPlayer.stop();
    } catch (e, _) {
      LoggerService.error('OrderAlarmService: stop audio error', e);
    }
  }

  /// Plays the audio chime and triggers heavy impact haptic vibration
  Future<void> _playChime() async {
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 150), () {
        HapticFeedback.heavyImpact();
      });

      try {
        await _audioPlayer.stop();
        await _audioPlayer.play(
          AssetSource('sounds/order_chime.mp3'),
          volume: 1.0,
          mode: PlayerMode.lowLatency,
        );
      } catch (e) {
        // Fallback to native system alert sound if asset playback is unavailable
        await SystemSound.play(SystemSoundType.alert);
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
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final orderToken = order.readableId ?? (order.id.length > 6 ? order.id.substring(order.id.length - 6).toUpperCase() : order.id);
        final itemsCount = order.items?.length ?? 0;
        final totalAmount = order.total.toInt();
        final shopOrKitchen = order.shopName ?? 'FastKirana Store';

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
                                  stopAlarm();
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
                                  stopAlarm();
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
}
