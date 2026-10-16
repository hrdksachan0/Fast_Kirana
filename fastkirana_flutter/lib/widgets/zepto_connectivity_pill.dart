import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_connectivity.dart';

/// Compact connection notice, with wrapping text and accessible retry targets.
class ZeptoConnectivityPill extends ConsumerStatefulWidget {
  final VoidCallback? onRetry;
  const ZeptoConnectivityPill({super.key, this.onRetry});

  @override
  ConsumerState<ZeptoConnectivityPill> createState() =>
      _ZeptoConnectivityPillState();
}

class _ZeptoConnectivityPillState extends ConsumerState<ZeptoConnectivityPill> {
  bool? _wasOnline;
  bool _showRecovery = false;
  bool _isChecking = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(connectivityProvider, (_, connection) {
      final online = connection.isOnline;
      if (online == _wasOnline) return;
      final recovered = _wasOnline == false && online;
      _wasOnline = online;
      _dismissTimer?.cancel();
      setState(() => _showRecovery = recovered);
      if (recovered) {
        // Catalog recovery belongs to the app provider, independently of this UI.
        widget.onRetry?.call();
        _dismissTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showRecovery = false);
        });
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_isChecking) return;
    HapticFeedback.lightImpact();
    setState(() => _isChecking = true);
    try {
      await ref.read(connectivityProvider).checkConnection();
    } catch (_) {
      // Leave retry available when the platform connection check fails.
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _wasOnline == false || _showRecovery;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 12,
      right: 12,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedSwitcher(
            duration: Duration(
                milliseconds:
                    MediaQuery.disableAnimationsOf(context) ? 0 : 180),
            child: !visible
                ? const SizedBox.shrink()
                : Material(
                    key: ValueKey(_showRecovery),
                    color: _showRecovery
                        ? const Color(0xFF145A42)
                        : const Color(0xFF24262B),
                    elevation: 3,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final stackAction = constraints.maxWidth < 330 &&
                            MediaQuery.textScalerOf(context).scale(14) > 18;
                        final message = Row(children: [
                          Icon(
                              _showRecovery
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.wifi_off_rounded,
                              size: 20,
                              color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _showRecovery ? 'Back online' : 'You’re offline',
                              softWrap: true,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600),
                            ),
                          )),
                        ]);
                        final retry = TextButton(
                          onPressed: _isChecking ? null : _retry,
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white70,
                              minimumSize: const Size(48, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12)),
                          child: Text(_isChecking ? 'Checking…' : 'Retry'),
                        );
                        if (stackAction && !_showRecovery) {
                          return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 8),
                                message,
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: retry),
                              ]);
                        }
                        return Row(children: [
                          Expanded(child: message),
                          if (!_showRecovery)
                            retry
                          else
                            const SizedBox(height: 44)
                        ]);
                      }),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
