import 'package:fastkirana_flutter/core/theme/design_system.dart';
import '../../../core/theme/responsive.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Red banner shown above the partner header when the device is offline.
/// Actions taken while offline are queued and replayed when connectivity
/// returns.
class ConnectivityBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  const ConnectivityBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: const BoxDecoration(color: AppDesignSystem.red600),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            'No Internet • Offline Mode (Actions will auto-sync)',
            style: GoogleFonts.inter(fontSize: Responsive.scaledFontSize(context, 11), fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
