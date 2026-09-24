import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/design_system.dart';

/// Custom high-performance disk cache manager for FastKirana.
/// Retains images for up to 30 days and caches up to 1,000 objects.
class FastKiranaImageCacheManager {
  static const String key = 'fastkirana_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// Unified, cached image widget for FastKirana e-commerce.
/// Features:
/// - 30-day disk caching via [FastKiranaImageCacheManager]
/// - Hardware-accelerated shimmer placeholder
/// - Smooth 200ms fade-in transition
/// - Graceful fallback icon for missing/broken URLs
/// - Memory downsampling to prevent heap fragmentation during rapid scroll
class AppCachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth = 400,
    this.memCacheHeight,
  });

  /// Pre-cache a critical remote image (e.g. top banner or hero deal)
  static Future<void> precache(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) return;
    try {
      await precacheImage(
        CachedNetworkImageProvider(
          url.trim(),
          cacheManager: FastKiranaImageCacheManager.instance,
        ),
        context,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim() ?? '';
    final hasValidUrl = cleanUrl.isNotEmpty &&
        (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://'));

    Widget content;
    if (!hasValidUrl) {
      content = _buildFallback();
    } else {
      content = CachedNetworkImage(
        imageUrl: cleanUrl,
        cacheManager: FastKiranaImageCacheManager.instance,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => placeholder ?? _buildShimmer(),
        errorWidget: (context, url, error) => errorWidget ?? _buildFallback(),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF1F5F9), // Slate 100
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFFF1F5F9),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF8FAFC), // Slate 50
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.35 : height! * 0.35).clamp(16.0, 36.0)
            : 24.0,
        color: const Color(0xFF94A3B8), // Slate 400
      ),
    );
  }
}
