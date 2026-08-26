import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
  late AnimationController _waveController;
  String _liveTranscript = 'Listening... Speak in Hindi or English';
  bool _isRecognized = false;
  Timer? _simulationTimer;
  Timer? _completionTimer;

  final List<String> _sampleQueries = [
    'Doodh aur bread',
    'Amul Butter 500g',
    'Maggi 2-Minute Noodles',
    'Aashirvaad Shudh Chakki Atta',
    'Bikaji Bhujia',
    'Bal Udyan Special Thali',
    'Coca-Cola 750ml',
    'Tata Tea Gold',
  ];

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Voice recognition listener
    _startVoiceListening();
  }

  void _startVoiceListening() {
    // 1. Initial listening state prompt
    _simulationTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final randomQuery = _sampleQueries[math.Random().nextInt(_sampleQueries.length)];
      setState(() {
        _liveTranscript = '“$randomQuery”';
        _isRecognized = true;
      });
      HapticFeedback.lightImpact();

      // 2. Auto-complete and trigger search after 1.6s
      _completionTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onVoiceResult(randomQuery);
      });
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _simulationTimer?.cancel();
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
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
          const SizedBox(height: 24),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎙️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'FastKirana Voice Search',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Speak product or dish name in Hindi / English',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 32),

          // Animated Concentric Pulsing Audio Wave Circles
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    final scale1 = 1.0 + _waveController.value * 0.45;
                    final opacity1 = (1.0 - _waveController.value).clamp(0.0, 1.0);

                    final scale2 = 1.0 + ((_waveController.value + 0.5) % 1.0) * 0.45;
                    final opacity2 = (1.0 - ((_waveController.value + 0.5) % 1.0)).clamp(0.0, 1.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Wave 1
                        Transform.scale(
                          scale: scale1,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE20A22).withOpacity(0.18 * opacity1),
                            ),
                          ),
                        ),
                        // Wave 2
                        Transform.scale(
                          scale: scale2,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE20A22).withOpacity(0.12 * opacity2),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Center Vibrant Mic Button
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
                        color: const Color(0xFFE20A22).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.mic_rounded, size: 36, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Live Transcript Bubble
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: _isRecognized ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isRecognized ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isRecognized) ...[
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    _liveTranscript,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: _isRecognized ? FontWeight.w800 : FontWeight.w600,
                      color: _isRecognized ? const Color(0xFF065F46) : const Color(0xFF475569),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Suggestion Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('🥛 “Doodh aur bread”'),
              _buildSuggestionChip('🧈 “Amul Butter”'),
              _buildSuggestionChip('🍜 “Maggi”'),
              _buildSuggestionChip('🍕 “Cheese Pizza”'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final cleanText = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
        Navigator.pop(context);
        widget.onVoiceResult(cleanText);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
