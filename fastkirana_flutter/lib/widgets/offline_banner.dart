import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/design_system.dart';
import '../core/utils/app_connectivity.dart';

class OfflineBanner extends ConsumerStatefulWidget {
  final VoidCallback? onRetry;
  final String? offlineText;
  final bool showBackOnlineNotification;

  const OfflineBanner({
    super.key,
    this.onRetry,
    this.offlineText,
    this.showBackOnlineNotification = true,
  });

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> with SingleTickerProviderStateMixin {
  bool _showOnlineNotice = false;
  Timer? _onlineNoticeTimer;
  bool _previousOnlineState = true;

  @override
  void dispose() {
    _onlineNoticeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity.isOnline;

    if (!_previousOnlineState && isOnline && widget.showBackOnlineNotification) {
      _previousOnlineState = true;
      _showOnlineNotice = true;
      _onlineNoticeTimer?.cancel();
      _onlineNoticeTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showOnlineNotice = false;
          });
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRetry?.call();
      });
    } else if (_previousOnlineState != isOnline) {
      _previousOnlineState = isOnline;
      if (!isOnline) {
        _showOnlineNotice = false;
      }
    }

    if (isOnline && !_showOnlineNotice) {
      return const SizedBox.shrink();
    }

    final isOffline = !isOnline;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        child: child,
      ),
      child: Container(
        key: ValueKey(isOffline ? 'offline_bar' : 'online_bar'),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isOffline ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOffline ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOffline ? AppDesignSystem.red600 : AppDesignSystem.green700).withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOffline ? AppDesignSystem.red600 : AppDesignSystem.green700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              size: 15,
              color: isOffline ? AppDesignSystem.red600 : AppDesignSystem.green700,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isOffline
                    ? (widget.offlineText ?? 'Offline • Reconnecting network...')
                    : 'Back online • Live synced',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 11),
                  fontWeight: FontWeight.w700,
                  color: isOffline ? const Color(0xFF991B1B) : const Color(0xFF166534),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isOffline && widget.onRetry != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onRetry?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh_rounded, size: 12, color: AppDesignSystem.red600),
                      const SizedBox(width: 3),
                      Text(
                        'Retry',
                        style: GoogleFonts.inter(
                          fontSize: Responsive.scaledFontSize(context, 10.5),
                          fontWeight: FontWeight.w800,
                          color: AppDesignSystem.red600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
