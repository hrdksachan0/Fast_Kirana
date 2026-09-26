import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/dish_timing.dart';

/// Shows dish timing availability status badge (e.g. Next slot 1:00 PM, Breakfast Only)
class ProductDishTimingBadge extends StatelessWidget {
  final DishTimingStatus timingStatus;
  final double s;

  const ProductDishTimingBadge({
    super.key,
    required this.timingStatus,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    if (timingStatus.isAvailableNow) {
      return const SizedBox.shrink();
    }

    final slotText = timingStatus.nextAvailableTimeStr != null
        ? 'Opens at ${timingStatus.nextAvailableTimeStr}'
        : 'Currently Unavailable';

    return Container(
      margin: EdgeInsets.only(bottom: s * 3),
      padding: EdgeInsets.symmetric(horizontal: s * 5, vertical: s * 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(s * 4),
        border: Border.all(color: const Color(0xFFFDE68A), width: s * 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: s * 9, color: const Color(0xFFB45309)),
          SizedBox(width: s * 3),
          Flexible(
            child: Text(
              slotText,
              style: GoogleFonts.inter(
                fontSize: s * 8,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
