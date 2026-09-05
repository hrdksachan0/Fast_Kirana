import 'package:fastkirana_flutter/core/services/logger_service.dart';
class DishTimingStatus {
  final bool isAvailableNow;
  final String? formattedTimeSlot;
  final String? nextAvailableTimeStr;

  const DishTimingStatus({
    required this.isAvailableNow,
    this.formattedTimeSlot,
    this.nextAvailableTimeStr,
  });
}

/// Format "HH:mm" (24-hour) string to "hh:mm a" (12-hour)
String formatTime12h(String timeStr) {
  try {
    final parts = timeStr.trim().split(':');
    final hours = int.parse(parts[0]);
    final minutes = parts.length > 1 ? int.parse(parts[1]) : 0;

    final period = hours >= 12 ? 'PM' : 'AM';
    final h12 = hours % 12 == 0 ? 12 : hours % 12;
    final mStr = minutes.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  } catch (e) { LoggerService.error('DishTiming: silent catch', e);
    return timeStr;
  }
}

/// Checks dish time availability matching Web App logic 1:1
DishTimingStatus checkDishTimeAvailability(String? startTime, String? endTime) {
  // If no start/end time specified, item is available 24/7 (All Day)
  if (startTime == null ||
      endTime == null ||
      startTime.trim().isEmpty ||
      endTime.trim().isEmpty) {
    return const DishTimingStatus(
      isAvailableNow: true,
      formattedTimeSlot: null,
      nextAvailableTimeStr: null,
    );
  }

  try {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startParts = startTime.trim().split(':');
    final endParts = endTime.trim().split(':');

    final startH = int.parse(startParts[0]);
    final startM = startParts.length > 1 ? int.parse(startParts[1]) : 0;
    final endH = int.parse(endParts[0]);
    final endM = endParts.length > 1 ? int.parse(endParts[1]) : 0;

    final startMinutes = startH * 60 + startM;
    final endMinutes = endH * 60 + endM;

    bool isAvailableNow = false;
    if (startMinutes <= endMinutes) {
      // Normal daytime range e.g. 07:00 to 11:30
      isAvailableNow = currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight range e.g. 20:00 to 02:00
      isAvailableNow = currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }

    final formattedStart = formatTime12h(startTime);
    final formattedEnd = formatTime12h(endTime);

    return DishTimingStatus(
      isAvailableNow: isAvailableNow,
      formattedTimeSlot: '$formattedStart - $formattedEnd',
      nextAvailableTimeStr: formattedStart,
    );
  } catch (e) { LoggerService.error('DishTiming: silent catch', e);
    return const DishTimingStatus(
      isAvailableNow: true,
      formattedTimeSlot: null,
      nextAvailableTimeStr: null,
    );
  }
}
