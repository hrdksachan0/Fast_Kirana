import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'logger_service.dart';

/// Premium Customer Audio & Haptic Feedback Engine
/// Delivers Swiggy/Zomato style subtle pleasant chime and coin confirmation sounds.
class CustomerSoundService {
  CustomerSoundService._();
  static final CustomerSoundService instance = CustomerSoundService._();

  AudioPlayer? _player;
  bool _isInitialized = false;

  Future<void> _initPlayer() async {
    if (_isInitialized && _player != null) return;
    try {
      _player = AudioPlayer();
      await _player!.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationEvent,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      _isInitialized = true;
    } catch (e) {
      LoggerService.error('CustomerSoundService: failed to init audio context', e);
    }
  }

  /// Plays the pleasant order confirmation chime and rhythmic haptic pulses tailored for Online vs COD
  Future<void> playOrderSuccessSound({bool isOnline = false}) async {
    try {
      // 1. Tactile haptic sensation
      if (isOnline) {
        // Triple celebratory ripple for digital payment confirmation
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.selectionClick();
        });
        Future.delayed(const Duration(milliseconds: 220), () {
          HapticFeedback.lightImpact();
        });
      } else {
        // Firm confirmation pulse for COD order creation
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () {
          HapticFeedback.mediumImpact();
        });
      }

      // 2. Audio Chime Playback with dedicated soundscapes (Online vs COD)
      await _initPlayer();
      if (_player != null) {
        await _player!.stop();
        final soundAsset = isOnline
            ? 'sounds/order_success_online.wav'
            : 'sounds/order_success_cod.wav';
        await _player!.play(
          AssetSource(soundAsset),
          volume: isOnline ? 0.95 : 0.90,
          mode: PlayerMode.lowLatency,
        );
      } else {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (e, st) {
      LoggerService.error('CustomerSoundService: audio playback error', e, st);
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  void dispose() {
    try {
      _player?.dispose();
      _player = null;
      _isInitialized = false;
    } catch (_) {}
  }
}
