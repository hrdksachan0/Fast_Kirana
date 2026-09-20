import 'package:fastkirana_flutter/core/theme/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Red or amber banner shown above partner header for offline status or pending offline actions.
class ConnectivityBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  final int pendingCount;
  final bool isOffline;

  const ConnectivityBanner({
    super.key,
    this.onRetry,
    this.pendingCount = 0,
    this.isOffline = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isOffline ? AppDesignSystem.red600 : const Color(0xFFD97706);
    final text = isOffline
        ? (pendingCount > 0
            ? 'No Internet • $pendingCount action(s) saved offline'
            : 'No Internet • Offline Mode (Actions will auto-sync)')
        : '$pendingCount offline action(s) pending sync • Tap to sync now';
    final icon = isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded;

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: onRetry,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: Responsive.scaledFontSize(context, 11),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
