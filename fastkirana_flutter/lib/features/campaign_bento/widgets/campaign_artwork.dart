import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../widgets/card_media_widget.dart';

class CampaignArtwork extends StatelessWidget {
  final String image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? tint;
  final IconData fallbackIcon;

  const CampaignArtwork({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.tint,
    this.fallbackIcon = Icons.shopping_basket_rounded,
  });

  bool get _isSvg => image.toLowerCase().split('?').first.endsWith('.svg');

  bool get _isLocalAsset {
    final trimmed = image.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return false;
    }
    if (trimmed.startsWith('assets/') || trimmed.startsWith('/navratri/')) {
      return true;
    }
    // Relative server/CDN paths like /uploads/..., /images/..., /api/...
    if (trimmed.startsWith('/')) {
      return false;
    }
    return true;
  }

  bool get _isNetwork => !_isLocalAsset;

  String get _resolvedPath {
    final trimmed = image.trim();
    if (_isNetwork) return CardMediaWidget.resolveUrl(trimmed);
    if (trimmed.startsWith('assets/')) return trimmed;
    if (trimmed.startsWith('/navratri/')) return 'assets$trimmed';
    if (trimmed.startsWith('/')) return trimmed.substring(1);
    return 'assets/navratri/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(fallbackIcon, size: (width != null ? width! * 0.45 : 24), color: Colors.grey.shade400),
        );

    try {
      if (_isSvg) {
        if (_isNetwork) {
          return SvgPicture.network(
            _resolvedPath,
            width: width,
            height: height,
            fit: fit,
            colorFilter: tint != null ? ColorFilter.mode(tint!, BlendMode.srcIn) : null,
            placeholderBuilder: (_) => fallback(),
          );
        } else {
          return SvgPicture.asset(
            _resolvedPath,
            width: width,
            height: height,
            fit: fit,
            colorFilter: tint != null ? ColorFilter.mode(tint!, BlendMode.srcIn) : null,
            placeholderBuilder: (_) => fallback(),
          );
        }
      }

      if (_isNetwork) {
        return CachedNetworkImage(
          imageUrl: _resolvedPath,
          width: width,
          height: height,
          fit: fit,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, __) => fallback(),
          errorWidget: (_, __, ___) => fallback(),
        );
      }

      return Image.asset(
        _resolvedPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } catch (_) {
      return fallback();
    }
  }
}
