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
  bool _isAudioBusy = false;

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

      // 2. Audio Chime Playback: Swiggy/Zomato Eb-Major signature sparkle chime (calm, subtle, non-intrusive)
      if (_isAudioBusy) return;
      _isAudioBusy = true;
      try {
        await _initPlayer();
        final player = _player;
        if (player != null) {
          if (player.state == PlayerState.playing) {
            await player.stop();
          }
          await player.play(
            AssetSource('sounds/order_placed_celebrate.wav'),
            volume: isOnline ? 0.60 : 0.55,
            mode: PlayerMode.lowLatency,
          );
        } else {
          await SystemSound.play(SystemSoundType.alert);
        }
      } finally {
        _isAudioBusy = false;
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
