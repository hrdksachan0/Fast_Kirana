import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Defensive JSON decoding helpers to prevent FormatException crashes
/// when APIs return HTML error pages (502/503) or local cache is corrupted.
class SafeJson {
  SafeJson._();

  /// Decodes [raw] safely, returning `null` instead of throwing [FormatException].
  static dynamic tryDecode(dynamic raw) {
    if (raw == null) return null;
    if (raw is! String) return raw;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // Fast-fail on HTML responses (e.g., Cloudflare/Vercel 502/503 pages)
    if (trimmed.startsWith('<')) return null;
    try {
      return jsonDecode(trimmed);
    } catch (e) {
      debugPrint('[SafeJson] Failed to decode JSON: $e');
      return null;
    }
  }

  /// Decodes [raw] as a [Map<String, dynamic>], or returns `null` if invalid.
  static Map<String, dynamic>? tryDecodeMap(dynamic raw) {
    final decoded = tryDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      try {
        return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Decodes [raw] as a [List<dynamic>], or returns an empty list if invalid.
  static List<dynamic> tryDecodeList(dynamic raw) {
    final decoded = tryDecode(raw);
    if (decoded is List) return decoded;
    return const [];
  }
}
