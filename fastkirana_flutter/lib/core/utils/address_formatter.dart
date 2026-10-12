class AddressFormatter {
  AddressFormatter._();

  /// Checks if a string looks like a Google Plus Code (e.g. "555C+6PH", "6F8Q+3J")
  static bool isPlusCode(String text) {
    final clean = text.trim();
    if (!clean.contains('+')) return false;
    return RegExp(r'\b[A-Z0-9]{2,8}\+[A-Z0-9]{2,8}\b', caseSensitive: false).hasMatch(clean);
  }

  /// Cleans a raw address string to a concise, human-readable single line without plus codes,
  /// redundant country/state, or ellipses.
  static String formatCleanSingleLine(String? rawAddress, {String? areaFallback}) {
    if (rawAddress == null || rawAddress.trim().isEmpty) {
      return areaFallback?.trim() ?? 'Select Location';
    }

    String text = rawAddress.trim();

    // 1. Remove plus codes (e.g., 555C+6PH, )
    text = text.replaceAll(RegExp(r'\b[A-Z0-9]{2,8}\+[A-Z0-9]{2,8}\b,?\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^[A-Z0-9+]{4,10},?\s*', caseSensitive: false), '');

    // 2. Remove "Unnamed Road", "Unnamed", null
    text = text.replaceAll(RegExp(r'\b(unnamed road|unnamed|null)\b,?\s*', caseSensitive: false), '');

    // 3. Remove country suffix ", India"
    text = text.replaceAll(RegExp(r',?\s*India\s*$', caseSensitive: false), '');

    // 4. Split into clean tokens
    final rawTokens = text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && t != '.' && t.toLowerCase() != 'n/a')
        .toList();

    // 5. Deduplicate tokens while preserving order and removing residuals
    final seen = <String>{};
    final cleanTokens = <String>[];
    for (final token in rawTokens) {
      final lower = token.toLowerCase();
      // Skip plus code residual
      if (lower.contains('+')) continue;
      // Skip "India"
      if (lower == 'india') continue;
      if (!seen.contains(lower)) {
        seen.add(lower);
        cleanTokens.add(token);
      }
    }

    if (cleanTokens.isEmpty) {
      return areaFallback?.trim().isNotEmpty == true ? areaFallback!.trim() : 'Delivery Location';
    }

    // 6. If we have 3+ tokens ending with or containing "Uttar Pradesh", "UP", drop the state
    // so the address fits concisely in a single line without truncation
    if (cleanTokens.length >= 3) {
      final last = cleanTokens.last.toLowerCase();
      final secondLast = cleanTokens[cleanTokens.length - 2].toLowerCase();
      if (last == 'uttar pradesh' || last == 'up') {
        cleanTokens.removeLast();
      } else if (secondLast == 'uttar pradesh' || secondLast == 'up') {
        cleanTokens.removeAt(cleanTokens.length - 2);
      }
    }

    return cleanTokens.join(', ');
  }

  /// Extracts the primary locality/area name (e.g. "Sihari") without plus codes
  static String extractAreaName(String? rawAddress, {String? fallback}) {
    if (fallback != null && fallback.trim().isNotEmpty && !fallback.contains('+')) {
      return fallback.trim();
    }
    final singleLine = formatCleanSingleLine(rawAddress, areaFallback: fallback);
    final parts = singleLine.split(',');
    if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
      return parts.first.trim();
    }
    return fallback?.trim().isNotEmpty == true ? fallback!.trim() : 'Delivery Location';
  }
}
