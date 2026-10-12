import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class StockNoticeHelper {
  StockNoticeHelper._();

  /// Shows a non-overlapping floating stock warning toast.
  /// When [hasFloatingCart] is true, adds bottom margin so it floats above the FloatingCartBar.
  static void showStockLimit({
    required BuildContext context,
    required int stock,
    bool hasFloatingCart = true,
  }) {
    HapticFeedback.heavyImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // FloatingCartBar is positioned at bottomPadding + 16, height ~54px.
    // Setting bottom margin to bottomPadding + 80px hovers cleanly above the cart bar.
    final bottomMargin = hasFloatingCart ? (bottomPadding + 80.0) : (bottomPadding + 16.0);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Only $stock units available in stock!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin,
        ),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
