import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/utils/app_connectivity.dart';

/// Blinkit / Apple Dynamic Island style floating capsule pill.
/// Floats gracefully at the top center with zero content overlap and auto-dismisses smoothly.
class ZeptoConnectivityPill extends ConsumerStatefulWidget {
  final VoidCallback? onRetry;
  const ZeptoConnectivityPill({super.key, this.onRetry});

  @override
  ConsumerState<ZeptoConnectivityPill> createState() =>
      _ZeptoConnectivityPillState();
}

class _ZeptoConnectivityPillState extends ConsumerState<ZeptoConnectivityPill>
    with SingleTickerProviderStateMixin {
  bool? _wasOnline;
  bool _showRecovery = false;
  bool _isChecking = false;
  Timer? _dismissTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    ref.listenManual(connectivityProvider, (_, connection) {
      final online = connection.isOnline;
      if (online == _wasOnline) return;
      final recovered = _wasOnline == false && online;
      _wasOnline = online;
      _dismissTimer?.cancel();
      
      if (mounted) {
        setState(() => _showRecovery = recovered);
      }
      
      if (recovered) {
        widget.onRetry?.call();
        _dismissTimer = Timer(const Duration(milliseconds: 2400), () {
          if (mounted) {
            setState(() => _showRecovery = false);
          }
        });
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_isChecking) return;
    HapticFeedback.lightImpact();
    setState(() => _isChecking = true);
    try {
      await ref.read(connectivityProvider).checkConnection();
    } catch (_) {
      // Keep retry accessible on failure
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = _wasOnline == false;
    final visible = isOffline || _showRecovery;

    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 240),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A), // Sleek deep slate/black
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.32),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Pulsing Status Dot
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) {
                        final dotColor = _showRecovery
                            ? const Color(0xFF10B981) // Emerald green
                            : const Color(0xFFEF4444); // Red
                        return Container(
                          width: 7.5,
                          height: 7.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                            boxShadow: [
                              BoxShadow(
                                color: dotColor.withValues(alpha: 0.6 * _pulseAnimation.value),
                                blurRadius: 6 * _pulseAnimation.value,
                                spreadRadius: 1.0 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),

                    // Status Message
                    Text(
                      _showRecovery ? 'Back online' : 'You’re offline',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),

                    // Inline Retry Button if Offline
                    if (!_showRecovery) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 12,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _isChecking ? null : _retry,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            _isChecking ? 'Checking…' : 'Retry',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF38BDF8), // Sky blue
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
