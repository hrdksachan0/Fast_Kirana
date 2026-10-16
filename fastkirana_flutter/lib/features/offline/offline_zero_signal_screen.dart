import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/app_connectivity.dart';
import '../../providers/cart_provider.dart';

/// Only promise persistence after checking the current cart against disk.
final savedOfflineCartCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final current = ref.watch(cartProvider).valueOrNull;
  if (current == null || current.items.isEmpty) return 0;
  final stored = await ref.watch(cartRepoProvider).getLocalCart();
  final expected =
      current.items.map((item) => jsonEncode(item.toJson())).toList()..sort();
  final actual = stored.map((item) => jsonEncode(item.toJson())).toList()
    ..sort();
  return listEquals(expected, actual) ? current.totalItems : 0;
});

class OfflineZeroSignalScreen extends ConsumerStatefulWidget {
  final VoidCallback? onRetry;
  final String? customTitle;
  final String? customMessage;
  const OfflineZeroSignalScreen(
      {super.key, this.onRetry, this.customTitle, this.customMessage});

  @override
  ConsumerState<OfflineZeroSignalScreen> createState() =>
      _OfflineZeroSignalScreenState();
}

class _OfflineZeroSignalScreenState
    extends ConsumerState<OfflineZeroSignalScreen> {
  bool _isRetrying = false;
  bool _recoveryScheduled = false;
  bool _didRecover = false;
  String? _retryMessage;

  void _returnToShopping() {
    if (!mounted || _didRecover || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _didRecover = true;
    widget.onRetry?.call();
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isRetrying = true;
      _retryMessage = null;
    });
    try {
      final online = await ref.read(connectivityProvider).checkConnection();
      if (!mounted) return;
      if (online) {
        _returnToShopping();
      } else {
        setState(
            () => _retryMessage = 'Still offline. Check Wi-Fi or mobile data.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _retryMessage = 'Unable to check. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).isOnline;
    if (online && !_recoveryScheduled && !_didRecover) {
      _recoveryScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recoveryScheduled = false;
        _returnToShopping();
      });
    }
    final savedCart = ref.watch(savedOfflineCartCountProvider);
    final savedCount = savedCart.isLoading || savedCart.hasError
        ? 0
        : savedCart.valueOrNull ?? 0;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: Navigator.canPop(context) ? const BackButton() : null),
      body: SafeArea(child: LayoutBuilder(builder: (context, viewport) {
        return SingleChildScrollView(
            child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ExcludeSemantics(
                    child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? colors.surfaceContainerHighest
                          : AppDesignSystem.primaryBg,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.wifi_off_rounded,
                      size: 52, color: AppDesignSystem.primary),
                )),
                const SizedBox(height: 28),
                Text(widget.customTitle ?? 'You’re offline',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Text(
                    widget.customMessage ??
                        (savedCount > 0
                            ? 'Your cart is saved on this device.\nReconnect to continue shopping.'
                            : 'Turn on Wi-Fi or mobile data\nto continue shopping.'),
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        height: 1.5,
                        color: colors.onSurfaceVariant)),
                const SizedBox(height: 32),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isRetrying ? null : _handleRetry,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppDesignSystem.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 52),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      child: Text(
                          _isRetrying ? 'Checking connection…' : 'Try again',
                          textAlign: TextAlign.center),
                    )),
                if (savedCount > 0) ...[
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                      style: TextButton.styleFrom(
                          foregroundColor: colors.onSurface,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12)),
                      child: Text(
                          'View saved cart · $savedCount ${savedCount == 1 ? 'item' : 'items'}',
                          textAlign: TextAlign.center)),
                ],
                const SizedBox(height: 16),
                Semantics(
                    liveRegion: true,
                    child: Text(
                        _retryMessage ?? 'We’ll reconnect automatically.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.5, color: colors.onSurfaceVariant))),
              ]),
            )),
          ),
        ));
      })),
    );
  }
}
