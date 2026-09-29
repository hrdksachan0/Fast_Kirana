import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

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
/// - 30-day persistent disk caching via [FastKiranaImageCacheManager]
/// - Hardware-accelerated shimmer placeholder (LQIP skeleton)
/// - Smooth 180ms fade-in transition
/// - Graceful fallback icon for missing/broken URLs
/// - Memory downsampling to prevent heap fragmentation during rapid scroll
/// - Auto-resolves relative URLs to https://www.fastkirana.in
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
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

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
    this.maxWidthDiskCache = 800,
    this.maxHeightDiskCache = 800,
  });

  /// Normalize raw image URL to a fully-qualified https URL
  static String? normalizeUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return 'https://www.fastkirana.in$trimmed';
    }
    return 'https://www.fastkirana.in/$trimmed';
  }

  /// Create a high-performance CachedNetworkImageProvider hooked to FastKiranaImageCacheManager
  static ImageProvider? provider(String? url, {int? maxWidth, int? maxHeight}) {
    final normalized = normalizeUrl(url);
    if (normalized == null) return null;
    return CachedNetworkImageProvider(
      normalized,
      cacheManager: FastKiranaImageCacheManager.instance,
      maxWidth: maxWidth ?? 600,
      maxHeight: maxHeight ?? 600,
    );
  }

  /// Standard Shimmer placeholder widget matching app design tokens
  static Widget buildShimmerPlaceholder({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    final shimmer = Shimmer.fromColors(
      baseColor: const Color(0xFFF1F5F9), // Slate 100
      highlightColor: const Color(0xFFFAFAFA),
      period: const Duration(milliseconds: 1400),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: borderRadius,
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: shimmer,
      );
    }
    return shimmer;
  }

  /// Pre-cache a critical remote image (e.g. top banner or hero deal)
  static Future<void> precache(BuildContext context, String? url) async {
    final normalized = normalizeUrl(url);
    if (normalized == null) return;
    try {
      await precacheImage(
        CachedNetworkImageProvider(
          normalized,
          cacheManager: FastKiranaImageCacheManager.instance,
        ),
        context,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = normalizeUrl(imageUrl);
    final hasValidUrl = cleanUrl != null &&
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
        maxWidthDiskCache: maxWidthDiskCache,
        maxHeightDiskCache: maxHeightDiskCache,
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (context, url) =>
            placeholder ?? buildShimmerPlaceholder(width: width, height: height, borderRadius: borderRadius),
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
