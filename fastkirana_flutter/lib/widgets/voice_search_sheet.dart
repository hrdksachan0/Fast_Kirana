import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceSearchSheet extends StatefulWidget {
  final Function(String query) onVoiceResult;

  const VoiceSearchSheet({
    super.key,
    required this.onVoiceResult,
  });

  static Future<void> show(BuildContext context, {required Function(String query) onResult}) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceSearchSheet(onVoiceResult: onResult),
    );
  }

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet> with SingleTickerProviderStateMixin {
  static const MethodChannel _voiceChannel = MethodChannel('com.fastkirana.app/voice_search');
  late AnimationController _waveController;
  String _liveTranscript = 'Listening... Speak now in Hindi or English';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _setupMethodChannel();
    _initAndStartSpeech();
  }

  void _setupMethodChannel() {
    _voiceChannel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'onPartialResult':
          final text = call.arguments?.toString() ?? '';
          if (text.isNotEmpty) {
            setState(() => _liveTranscript = text);
          }
          break;
        case 'onFinalResult':
          final text = call.arguments?.toString() ?? '';
          if (text.trim().isNotEmpty) {
            setState(() => _liveTranscript = text);
            _finishWithResult(text.trim());
          }
          break;
        case 'onStatus':
          final status = call.arguments?.toString();
          if (status == 'listening' || status == 'speaking') {
            setState(() => _isListening = true);
          } else {
            setState(() => _isListening = false);
          }
          break;
        case 'onError':
          setState(() {
            _isListening = false;
            if (_liveTranscript.startsWith('Listening')) {
              _liveTranscript = 'Tap mic to speak';
            }
          });
          break;
      }
    });
  }

  Future<void> _initAndStartSpeech() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _liveTranscript = 'Microphone permission needed to use voice search';
          });
        }
        return;
      }

      final isAvail = await _voiceChannel.invokeMethod<bool>('isAvailable') ?? false;
      if (isAvail) {
        _startListening();
      } else {
        if (mounted) {
          setState(() {
            _liveTranscript = 'Tap mic to speak';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveTranscript = 'Tap mic to speak';
        });
      }
    }
  }

  void _startListening() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isListening = true;
      _liveTranscript = 'Listening... Speak now';
    });

    try {
      await _voiceChannel.invokeMethod('startListening');
    } catch (_) {
      setState(() => _isListening = false);
    }
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    try {
      await _voiceChannel.invokeMethod('stopListening');
    } catch (_) {}
  }

  void _finishWithResult(String query) {
    _stopListening();
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    widget.onVoiceResult(query);
  }

  @override
  void dispose() {
    _stopListening();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎙️', style: TextStyle(fontSize: Responsive.scaledFontSize(context, 22))),
              const SizedBox(width: 8),
              Text(
                'Voice Search',
                style: GoogleFonts.inter(
                  fontSize: Responsive.scaledFontSize(context, 18),
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Speak product or grocery name in Hindi or English',
            style: GoogleFonts.inter(
              fontSize: Responsive.scaledFontSize(context, 12.5),
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),

          // Pulsing Soundwave & Big Mic Button
          GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopListening();
              } else {
                _initAndStartSpeech();
              }
            },
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (_, __) {
                        return Container(
                          width: 80 + (_waveController.value * 50),
                          height: 80 + (_waveController.value * 50),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE20A22).withValues(
                              alpha: (1.0 - _waveController.value).clamp(0.0, 0.4),
                            ),
                          ),
                        );
                      },
                    ),

                  // Center Mic Action Button
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE20A22), Color(0xFFFF2D4B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE20A22).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Real-time speech transcript box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isListening ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Text(
              _liveTranscript,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: Responsive.scaledFontSize(context, 14.5),
                fontWeight: FontWeight.w700,
                color: _isListening ? const Color(0xFFBE123C) : const Color(0xFF0F172A),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
