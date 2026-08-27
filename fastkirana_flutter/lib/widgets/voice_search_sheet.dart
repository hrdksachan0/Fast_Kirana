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
  String _liveTranscript = 'Listening... Speak in Hindi or English';
  bool _isListening = false;
  Timer? _silenceTimer;

  final List<String> _quickSuggestions = [
    'Amul Milk',
    'Fortune Oil',
    'Maggi',
    'Atta 5kg',
    'A.S. Restaurant Thali',
    'Wedson Burger',
    'Lays Chips',
    'Eggs',
  ];

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
              _liveTranscript = 'Tap mic to speak or choose a popular search below:';
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
            _liveTranscript = 'Microphone permission needed. Tap a suggestion below:';
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
            _liveTranscript = 'Tap mic or choose a popular search below:';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _liveTranscript = 'Tap mic or choose a popular search below:';
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
    _silenceTimer?.cancel();
    _stopListening();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
          // Drag Handle Bar
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎙️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Voice Search',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Say any product or dish name (e.g. "Milk", "Maggi", "Burger")',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 28),

          // Animated Concentric Pulsing Audio Wave Circles
          GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopListening();
              } else {
                _startListening();
              }
            },
            child: SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isListening)
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return Container(
                          width: 80 + (_waveController.value * 46),
                          height: 80 + (_waveController.value * 46),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE20A22).withValues(
                              alpha: (1.0 - _waveController.value) * 0.25,
                            ),
                          ),
                        );
                      },
                    ),

                  // Center Mic Action Button
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE20A22), Color(0xFFFF2D4B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
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

          const SizedBox(height: 20),

          // Real-time speech transcript box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isListening ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              _liveTranscript,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: _isListening ? const Color(0xFFBE123C) : const Color(0xFF0F172A),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Suggestion Chips
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'POPULAR SEARCHES',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickSuggestions.map((query) {
              return GestureDetector(
                onTap: () => _finishWithResult(query),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    query,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
