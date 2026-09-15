import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// High-Performance Offline & Disk-Cached Tile Provider for FlutterMap
///
/// Automatically caches all fetched OpenStreetMap / CartoDB Voyager tiles to local storage.
/// In low-connectivity dark zones or when offline, tiles are seamlessly loaded from disk cache.
class CachedMapTileProvider extends TileProvider {
  final Map<String, String>? customHeaders;

  CachedMapTileProvider({this.customHeaders});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final urlTemplate = options.urlTemplate ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    
    // Resolve subdomains if any (e.g. {s} -> a, b, c)
    String url = urlTemplate;
    if (options.subdomains.isNotEmpty) {
      final subdomain = options.subdomains[(coordinates.x + coordinates.y) % options.subdomains.length];
      url = url.replaceAll('{s}', subdomain);
    }

    // Replace tile coordinate placeholders
    url = url
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString())
        .replaceAll('{z}', coordinates.z.toString());

    final headers = {
      'User-Agent': 'FastKirana/2.0 (com.fastkirana.app)',
      if (customHeaders != null) ...customHeaders!,
    };

    return CachedNetworkImageProvider(
      url,
      headers: headers,
    );
  }
}
