import 'package:flutter/material.dart';

/// Compact icon-only Blinkit-style stock battery meter.
/// Placed on the product photo bottom-left.
/// - stock == 1 -> Red (1 bar)
/// - stock == 2 -> Yellow / Amber (2 bars)
/// - stock == 3 -> Green (3 bars)
/// Returns SizedBox.shrink() when stock <= 0 or stock > 3.
class BlinkitBatteryMeter extends StatelessWidget {
  final int stock;
  final double uiScale;

  const BlinkitBatteryMeter({
    super.key,
    required this.stock,
    this.uiScale = 1.0,
  });

  double s(double v) => v * uiScale;

  @override
  Widget build(BuildContext context) {
    if (stock <= 0 || stock > 3) return const SizedBox.shrink();

    final int filledBars;
    final Color primaryColor;
    final Color bgColor;
    final Color borderColor;

    if (stock == 1) {
      filledBars = 1;
      primaryColor = const Color(0xFFEF4444); // Red — 1 bar
      bgColor = const Color(0xF2FEF2F2);
      borderColor = const Color(0xFFFECACA);
    } else if (stock == 2) {
      filledBars = 2;
      primaryColor = const Color(0xFFF59E0B); // Yellow/Amber — 2 bars
      bgColor = const Color(0xF2FFFBEB);
      borderColor = const Color(0xFFFDE68A);
    } else {
      filledBars = 3;
      primaryColor = const Color(0xFF318616); // Green — 3 bars
      bgColor = const Color(0xF2F0FDF4);
      borderColor = const Color(0xFFBBF7D0);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s(4.5), vertical: s(3)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(s(5.5)),
        border: Border.all(
          color: borderColor,
          width: s(0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.14),
            blurRadius: s(4),
            offset: Offset(0, s(1.2)),
          ),
        ],
      ),
      child: _BatteryIcon(
        filledBars: filledBars,
        color: primaryColor,
        uiScale: uiScale,
      ),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  final int filledBars;
  final Color color;
  final double uiScale;

  const _BatteryIcon({
    required this.filledBars,
    required this.color,
    required this.uiScale,
  });

  double s(double v) => v * uiScale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Battery shell with 3 discrete bars (1=Red, 2=Yellow, 3=Green)
        Container(
          width: s(16),
          height: s(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(s(2.2)),
            border: Border.all(
              color: color,
              width: s(1.0),
            ),
          ),
          padding: EdgeInsets.all(s(1.1)),
          child: Row(
            children: List.generate(3, (index) {
              final isLit = index < filledBars;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? s(0.9) : 0),
                  decoration: BoxDecoration(
                    color: isLit ? color : color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(s(0.8)),
                  ),
                ),
              );
            }),
          ),
        ),
        // Battery positive tip
        Container(
          width: s(1.5),
          height: s(4),
          margin: EdgeInsets.only(left: s(0.5)),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(s(0.9)),
            ),
          ),
        ),
      ],
    );
  }
}
