import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../core/config/app_config.dart';

/// Ultra-Aesthetic Hybrid Media Widget for Category & Spotlight Offer Cards
/// Supports:
/// 1. Instant Static Poster (0ms lag, zero black screen)
/// 2. Seamless Muted Micro-Video Loop (.mp4/.mov/.webm)
/// 3. Battery & Memory-Safe lifecycle with automatic disposal
/// 4. Hardware-accelerated 18px squircle clipping & subtle micro-pill badge
class CardMediaWidget extends StatefulWidget {
  final String? imageUrl;
  final String? videoUrl;
  final String? imageAsset;
  final double borderRadius;
  final BoxFit fit;
  final bool showLiveBadge;
  final bool showPauseButton;
  final Widget? fallback;

  const CardMediaWidget({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.imageAsset,
    this.borderRadius = 18.0,
    this.fit = BoxFit.cover,
    this.showLiveBadge = true,
    this.showPauseButton = true,
    this.fallback,
  });

  @override
  State<CardMediaWidget> createState() => _CardMediaWidgetState();
}

class _CardMediaWidgetState extends State<CardMediaWidget> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = true;

  String? get _resolvedVideoUrl {
    if (widget.videoUrl != null && widget.videoUrl!.trim().isNotEmpty) {
      return _resolveUrl(widget.videoUrl!);
    }
    // Auto-detect if imageUrl is actually a video file
    if (widget.imageUrl != null) {
      final lower = widget.imageUrl!.toLowerCase().split('?').first;
      if (lower.endsWith('.mp4') || lower.endsWith('.webm') || lower.endsWith('.mov')) {
        return _resolveUrl(widget.imageUrl!);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant CardMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl || oldWidget.imageUrl != widget.imageUrl) {
      _disposeVideo();
      _initializeVideo();
    }
  }

  void _onVideoControllerUpdate() {
    if (!mounted || _videoController == null) return;
    final playing = _videoController!.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() {
        _isPlaying = playing;
      });
    }
  }

  void _initializeVideo() {
    final vUrl = _resolvedVideoUrl;
    if (vUrl == null) return;

    final uri = Uri.tryParse(vUrl);
    if (uri == null) return;

    _videoController = VideoPlayerController.networkUrl(uri)
      ..setLooping(true)
      ..setVolume(0.0) // Silent/Muted for frictionless browsing
      ..initialize().then((_) {
        if (!mounted) return;
        _videoController?.addListener(_onVideoControllerUpdate);
        _videoController?.play();
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _isPlaying = true;
        });
      }).catchError((err) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      });
  }

  void _disposeVideo() {
    _videoController?.removeListener(_onVideoControllerUpdate);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isInitialized = false;
    _hasError = false;
    _isPlaying = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ─── 1. Instant Poster / Static Visual Layer ───
          _buildPosterLayer(),

          // ─── 2. Smooth Looping Video Layer ───
          if (_isInitialized && _videoController != null && !_hasError)
            AnimatedOpacity(
              opacity: _isInitialized ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: SizedBox.expand(
                child: FittedBox(
                  fit: widget.fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _videoController!.value.size.width > 0
                        ? _videoController!.value.size.width
                        : 16,
                    height: _videoController!.value.size.height > 0
                        ? _videoController!.value.size.height
                        : 9,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            ),

          // ─── 3. Subtle Inner Glass Rim (Removes Photographic Harsh Edges) ───
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: Colors.black.withOpacity(0.06),
                  width: 1.0,
                ),
              ),
            ),
          ),

          // ─── 4. Live Motion Luxury Micro-Badge (When Video is Active) ───
          if (_isInitialized && widget.showLiveBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.52),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF22C55E),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF22C55E),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'MOTION',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── 5. Pause / Play Interactive Floating Controls ───
          if (_isInitialized && _videoController != null && !_hasError && widget.showPauseButton) ...[
            // Center Play button indicator when paused
            if (!_isPlaying)
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _videoController?.play();
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.65),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),

            // Floating Pill in Bottom-Right Corner (always visible & easily clickable)
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_videoController == null) return;
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlaying ? 'PAUSE' : 'PLAY',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _resolveUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$path';
  }

  Widget _buildPosterLayer() {
    if (widget.imageUrl != null &&
        widget.imageUrl!.trim().isNotEmpty &&
        !_isDirectVideoFile(widget.imageUrl!)) {
      final resolvedUrl = _resolveUrl(widget.imageUrl!);
      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        fit: widget.fit,
        alignment: Alignment.center,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => _buildFallbackVisual(),
      );
    }

    if (widget.imageAsset != null && widget.imageAsset!.trim().isNotEmpty) {
      return Image.asset(
        widget.imageAsset!.trim(),
        fit: widget.fit,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => _buildFallbackVisual(),
      );
    }

    return _buildFallbackVisual();
  }

  bool _isDirectVideoFile(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.mp4') || lower.endsWith('.webm') || lower.endsWith('.mov');
  }

  Widget _buildFallbackVisual() {
    if (widget.fallback != null) return widget.fallback!;
    return const SizedBox.shrink();
  }
}
