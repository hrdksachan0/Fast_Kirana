import 'dart:math';

/// High-performance Damerau-Levenshtein distance & fuzzy string matching utility.
/// Optimized for quick-commerce catalog search on mobile devices with early-exit pruning.
class FuzzyMatcher {
  /// Computes the true Damerau-Levenshtein distance between [source] and [target].
  /// Supports:
  /// - Insertions
  /// - Deletions
  /// - Substitutions
  /// - Adjacent Transpositions (e.g. "amlu" <-> "amul")
  ///
  /// If [maxDistance] is provided and the minimum potential distance exceeds it,
  /// the function aborts early returning [maxDistance] + 1 to avoid unnecessary CPU cycles.
  static int damerauLevenshtein(
    String source,
    String target, {
    int maxDistance = 2,
  }) {
    final s1 = source.toLowerCase().trim();
    final s2 = target.toLowerCase().trim();

    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    // Fast length difference pruning
    if ((len1 - len2).abs() > maxDistance) {
      return maxDistance + 1;
    }

    // Allocate distance matrix (len1 + 2) x (len2 + 2)
    final maxDist = len1 + len2;
    final h = List.generate(len1 + 2, (_) => List<int>.filled(len2 + 2, 0));

    h[0][0] = maxDist;
    for (int i = 0; i <= len1; i++) {
      h[i + 1][0] = maxDist;
      h[i + 1][1] = i;
    }
    for (int j = 0; j <= len2; j++) {
      h[0][j + 1] = maxDist;
      h[1][j + 1] = j;
    }

    final da = <int, int>{};

    for (int i = 1; i <= len1; i++) {
      int db = 0;
      for (int j = 1; j <= len2; j++) {
        final i1 = da[s2.codeUnitAt(j - 1)] ?? 0;
        final j1 = db;
        int cost = 0;
        if (s1.codeUnitAt(i - 1) == s2.codeUnitAt(j - 1)) {
          db = j;
        } else {
          cost = 1;
        }

        h[i + 1][j + 1] = [
          h[i][j + 1] + 1, // deletion
          h[i + 1][j] + 1, // insertion
          h[i][j] + cost, // substitution
          h[i1][j1] + (i - i1 - 1) + 1 + (j - j1 - 1), // transposition
        ].reduce(min);
      }
      da[s1.codeUnitAt(i - 1)] = i;

      // Early row exit if every cell in the row exceeds maxDistance
      bool canBeWithinMax = false;
      for (int j = 1; j <= len2; j++) {
        if (h[i + 1][j + 1] <= maxDistance) {
          canBeWithinMax = true;
          break;
        }
      }
      if (!canBeWithinMax && i >= maxDistance) {
        return maxDistance + 1;
      }
    }

    return h[len1 + 1][len2 + 1];
  }

  /// Returns true if [queryWord] is within [maxDistance] edits of [targetWord].
  /// Typical maxDistance for short grocery words is 1 (length <= 4) or 2 (length > 4).
  static bool isFuzzyMatch(
    String queryWord,
    String targetWord, {
    int? maxDistance,
  }) {
    final q = queryWord.toLowerCase().trim();
    final t = targetWord.toLowerCase().trim();

    if (q == t) return true;
    if (q.length <= 2 || t.length <= 2) return false;

    // Adaptive distance based on word length
    final effectiveMax = maxDistance ?? (q.length <= 4 ? 1 : 2);
    final dist = damerauLevenshtein(q, t, maxDistance: effectiveMax);
    return dist <= effectiveMax;
  }

  /// Calculates a normalized similarity score between 0 and 100.
  /// 100 means exact match, 0 means completely different.
  static int similarityScore(String s1, String s2) {
    final str1 = s1.toLowerCase().trim();
    final str2 = s2.toLowerCase().trim();

    if (str1 == str2) return 100;
    if (str1.isEmpty || str2.isEmpty) return 0;

    final maxLen = max(str1.length, str2.length);
    final dist = damerauLevenshtein(str1, str2, maxDistance: maxLen);
    if (dist > maxLen) return 0;

    final score = ((1.0 - (dist / maxLen)) * 100).round();
    return score.clamp(0, 100);
  }

  /// Checks if any word in [targetText] matches [queryWord] fuzzily.
  /// Returns the minimum distance found, or null if no word matched within [maxDistance].
  static int? bestTokenFuzzyDistance(
    String queryWord,
    String targetText, {
    int maxDistance = 2,
  }) {
    final q = queryWord.toLowerCase().trim();
    if (q.length <= 2) return null;

    final targetTokens = targetText
        .toLowerCase()
        .split(RegExp(r'[\s,\-_/]+'))
        .where((w) => w.length >= 2);

    int? bestDist;
    final effectiveMax = q.length <= 4 ? 1 : maxDistance;

    for (final token in targetTokens) {
      if (token == q) return 0;
      final dist = damerauLevenshtein(q, token, maxDistance: effectiveMax);
      if (dist <= effectiveMax) {
        if (bestDist == null || dist < bestDist) {
          bestDist = dist;
          if (bestDist == 0) return 0;
        }
      }
    }

    return bestDist;
  }
}
