import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class StockNoticeHelper {
  StockNoticeHelper._();

  /// Shows an ultra-sleek, Swiggy/Zepto-style floating pill notification for stock limits.
  /// Automatically floats cleanly above the FloatingCartBar and BottomNavBar without overlapping.
  static void showStockLimit({
    required BuildContext context,
    required int stock,
    bool hasFloatingCart = true,
    String? customMessage,
  }) {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Bottom navigation bar height is ~56-62px.
    // FloatingCartBar is positioned ~10px above bottom nav bar (height ~54px).
    // Total bottom obstruction when cart is present is ~126px + bottomPadding.
    // Setting bottom margin to bottomPadding + 148px floats with 22px breathing room cleanly ABOVE the cart bar!
    final bottomMargin = hasFloatingCart ? (bottomPadding + 148.0) : (bottomPadding + 78.0);

    final String message = customMessage ??
        (stock <= 0
            ? 'Item is currently out of stock'
            : (stock == 1
                ? 'Only 1 unit available in stock'
                : 'Only $stock units available in stock'));

    messenger.showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98), // Clean White Glass surface
            borderRadius: BorderRadius.circular(100), // Full organic pill
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: const Color(0xFFE20A22).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Jewel Warning Accent Badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2), // Soft Rose Petal
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFECDD3),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFE11D48), // Rose 600
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Message Text
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A), // Crisp slate 900
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: bottomMargin,
        ),
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }
}
