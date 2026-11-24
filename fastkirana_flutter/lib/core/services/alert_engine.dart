// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FastMinute Client Alert Engine (Flutter)
// Single Source of Truth for Sound Alerts, Haptics, and Popups across Roles
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/order_event.dart';
import 'order_alarm_service.dart';

class AlertEngine {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isAudioBusy = false;

  /// Play one-shot low latency asset sound
  static Future<void> playAssetSound(String assetPath) async {
    if (_isAudioBusy) return;
    _isAudioBusy = true;
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      }
      await _audioPlayer.play(
        AssetSource(assetPath),
        volume: 0.9,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    } finally {
      _isAudioBusy = false;
    }
  }

  /// Handle incoming OrderEvent for the current authenticated user's role
  static Future<void> handle(
    OrderEvent event, {
    required String currentUserRole,
    BuildContext? context,
  }) async {
    final urgency = event.alert.urgency.toUpperCase();
    final role = currentUserRole.toUpperCase().trim();
    final isStaff = role == 'ADMIN' ||
        role == 'SUPER_ADMIN' ||
        role == 'STORE_MANAGER' ||
        role == 'STAFF';

    switch (urgency) {
      case 'CRITICAL':
        // Continuous siren buzzer loop until accepted/acknowledged
        if (isStaff) {
          await OrderAlarmService.instance.startOrderBuzzer(orderId: event.orderId);
        }
        break;

      case 'HIGH':
        // Single loud alert + role-specific chime
        if (role == 'CHEF' || role == 'RESTAURANT' || role == 'RESTAURANT_OWNER') {
          await playAssetSound('sounds/kitchen_order_bell.wav');
          HapticFeedback.heavyImpact();
        } else if (role == 'PICKER') {
          await OrderAlarmService.instance.playChime();
          HapticFeedback.heavyImpact();
        } else if (role == 'DELIVERY' || role == 'RIDER' || role == 'DRIVER') {
          await OrderAlarmService.instance.playChime();
          HapticFeedback.heavyImpact();
        } else if (isStaff) {
          await OrderAlarmService.instance.playChime();
          HapticFeedback.heavyImpact();
        }
        break;

      case 'NORMAL':
        // Customer soft pleasant tick / celebration
        if (role == 'CUSTOMER' || role == 'USER' || role.isEmpty) {
          if (event.status.toUpperCase() == 'DELIVERED') {
            await playAssetSound('sounds/order_placed_celebrate.wav');
            HapticFeedback.mediumImpact();
          } else if (event.tag == 'ORDER_CREATED') {
            await playAssetSound('sounds/order_placed_celebrate.wav');
            HapticFeedback.mediumImpact();
          } else {
            // Soft status step tick
            await playAssetSound('sounds/status_step_tick.wav');
            HapticFeedback.lightImpact();
          }
        }
        break;

      case 'LOW':
      case 'SILENT':
      default:
        // Data-only socket update — silent
        break;
    }
  }
}
