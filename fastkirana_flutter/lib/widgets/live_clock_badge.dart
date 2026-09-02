import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// An isolated, self-updating live clock badge that ticks every second
/// WITHOUT causing parent dashboard rebuilds.
class LiveDigitalClockBadge extends StatefulWidget {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final double fontSize;
  final bool showSeconds;

  const LiveDigitalClockBadge({
    super.key,
    this.backgroundColor = const Color(0x26FFFFFF),
    this.borderColor = const Color(0x40FFFFFF),
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
    this.fontSize = 10.5,
    this.showSeconds = true,
  });

  @override
  State<LiveDigitalClockBadge> createState() => _LiveDigitalClockBadgeState();
}

class _LiveDigitalClockBadgeState extends State<LiveDigitalClockBadge> {
  late String _timeStr;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timeStr = _formatTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timeStr = _formatTime();
        });
      }
    });
  }

  String _formatTime() {
    final format = widget.showSeconds ? 'hh:mm:ss a' : 'hh:mm a';
    return DateFormat(format).format(DateTime.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 11, color: widget.iconColor),
          const SizedBox(width: 4),
          Text(
            _timeStr,
            style: GoogleFonts.robotoMono(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w800,
              color: widget.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
