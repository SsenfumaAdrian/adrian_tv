// Derived from clubTivi (https://github.com/clubanderson/clubTivi),
// Copyright Anderson, licensed under the Apache License 2.0.
// Modified for ADRIAN TV: adapted to its Channel/EpgChannelDefinition
// models, fuzzy matching pre-filtered through a token index instead of
// scanning every EPG channel, and reduced to a single best-match API.
// See third_party/clubtivi/LICENSE.

import 'package:string_similarity/string_similarity.dart';

import '../models/channel.dart';
import '../parsers/xmltv_parser.dart';

class EpgMatchResult {
  const EpgMatchResult({
    this.epgChannelId,
    required this.confidence,
    this.reasons = const [],
  });

  final String? epgChannelId;
  final double confidence;
  final List<String> reasons;

  bool get isAutoMatch => confidence >= EpgMatcher.autoApplyThreshold;
}

/// Scores playlist-channel → guide-channel candidates across five signals
/// and merges them with a corroboration boost.
class EpgMatcher {
  EpgMatcher(List<EpgChannelDefinition> definitions) {
    for (final def in definitions) {
      _byId[def.id] = def;
      final normalizedId = _normalizeId(def.id);
      if (normalizedId.isNotEmpty) {
        _byNormalizedId.putIfAbsent(normalizedId, () => def);
      }
      if (def.lcn != null) _byNumber[def.lcn!] = def;
      if (def.iconUrl != null && def.iconUrl!.isNotEmpty) {
        _byIconUrl[def.iconUrl!] = def;
      }
      for (final name in [def.displayName, ...def.displayNames]) {
        for (final token in _tokens(_cleanChannelName(name))) {
          _tokenIndex.putIfAbsent(token, () => {}).add(def.id);
          _prefixIndex.putIfAbsent(_prefix(token), () => {}).add(def.id);
        }
      }
    }
  }

  static const autoApplyThreshold = 0.70;
  static const suggestThreshold = 0.40;

  final _byId = <String, EpgChannelDefinition>{};
  final _byNormalizedId = <String, EpgChannelDefinition>{};
  final _byNumber = <String, EpgChannelDefinition>{};
  final _byIconUrl = <String, EpgChannelDefinition>{};
  final _tokenIndex = <String, Set<String>>{};
  final _prefixIndex = <String, Set<String>>{};

  EpgMatchResult bestMatch(Channel channel) {
    // 24/7 loop channels never carry scheduled programming.
    final haystack = '${channel.name} ${channel.group ?? ''}';
    if (haystack.contains('24/7') || haystack.contains('24-7')) {
      return const EpgMatchResult(confidence: 0);
    }

    final scores = <String, _CandidateScore>{};
    void add(EpgChannelDefinition def, double score, String reason) =>
        scores.update(def.id, (existing) {
          existing.scores.add(score);
          existing.reasons.add(reason);
          return existing;
        }, ifAbsent: () => _CandidateScore(def, [score], [reason]));

    final tvgId = channel.tvgId;
    if (tvgId != null && tvgId.isNotEmpty) {
      final exact = _byId[tvgId];
      if (exact != null) add(exact, 1.0, 'exact_tvg_id');
      final byNorm = _byNormalizedId[_normalizeId(tvgId)];
      if (byNorm != null && !scores.containsKey(byNorm.id)) {
        add(byNorm, 0.95, 'normalized_id');
      }
    }

    final cleaned = _cleanChannelName(channel.name);
    if (cleaned.isNotEmpty) {
      for (final def in _prefilter(cleaned)) {
        final score = _nameScore(cleaned, def);
        if (score >= 0.55) {
          add(def, score.clamp(0.0, 0.95), 'fuzzy_name');
        }
      }
    }

    final order = channel.order;
    if (order != null) {
      final def = _byNumber['$order'];
      if (def != null) add(def, 0.50, 'channel_number');
    }

    final logo = channel.logoUrl;
    if (logo != null && logo.isNotEmpty) {
      final def = _byIconUrl[logo];
      if (def != null) add(def, 0.40, 'logo_url');
    }

    if (scores.isEmpty) return const EpgMatchResult(confidence: 0);

    var bestId = '';
    var bestConfidence = 0.0;
    List<String> bestReasons = const [];
    for (final entry in scores.entries) {
      final value = entry.value;
      final base = value.scores.reduce((a, b) => a > b ? a : b);
      final corroboration = value.scores
          .where((s) => s > 0.3)
          .fold(0.0, (sum, s) => sum + s * 0.1);
      final confidence = (base + corroboration).clamp(0.0, 1.0);
      if (confidence > bestConfidence) {
        bestId = entry.key;
        bestConfidence = confidence;
        bestReasons = value.reasons;
      }
    }
    return EpgMatchResult(
      epgChannelId: bestId,
      confidence: bestConfidence,
      reasons: bestReasons,
    );
  }

  /// Candidate defs sharing a token or 4-char token prefix with [cleaned]
  /// ("disc" finds "discovery"), capped so fuzzy scoring never degrades to
  /// O(channels × guide).
  Iterable<EpgChannelDefinition> _prefilter(String cleaned) {
    final matched = <String>{};
    for (final token in _tokens(cleaned)) {
      matched.addAll(_tokenIndex[token] ?? const {});
      matched.addAll(_prefixIndex[_prefix(token)] ?? const {});
    }
    return matched
        .take(200)
        .map((id) => _byId[id])
        .whereType<EpgChannelDefinition>();
  }

  static String _prefix(String token) =>
      token.length <= 4 ? token : token.substring(0, 4);

  double _nameScore(String cleaned, EpgChannelDefinition def) {
    var best = 0.0;
    final input = cleaned.toLowerCase();
    final inputTokens = _tokens(cleaned);
    for (final epgName in [def.displayName, ...def.displayNames]) {
      final target = _cleanChannelName(epgName).toLowerCase();
      if (target.isEmpty) continue;
      if (input == target) return 0.95;
      if (input.contains(target) || target.contains(input)) {
        best = doubleGreater(best, 0.80);
      }
      final targetTokens = _tokens(_cleanChannelName(epgName));
      if (inputTokens.isNotEmpty && targetTokens.isNotEmpty) {
        final intersection = inputTokens.intersection(targetTokens).length;
        final union = inputTokens.union(targetTokens).length;
        best = doubleGreater(best, intersection / union);
      }
      best = doubleGreater(best, input.similarityTo(target));
    }
    return best;
  }

  static double doubleGreater(double a, double b) => a > b ? a : b;

  /// Pipe-separated names use the most specific (last) segment; parenthesized
  /// US call signs like "(WABC)" become the primary key.
  static String _cleanChannelName(String name) {
    final segments = name.split(RegExp(r'\s*\|\s*'));
    var cleaned = segments.last.trim();
    if (cleaned.isEmpty && segments.length > 1) {
      cleaned = segments[segments.length - 2].trim();
    }
    cleaned = cleaned.replaceAll(
      RegExp(r'^[A-Z]{2,3}\s*[:|/\-]\s*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'^24[/\-]7\s*', caseSensitive: false),
      '',
    );
    final callSign = RegExp(
      r'\(([A-Z]{3,5})\)',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (callSign != null) {
      return callSign.group(1)!.trim();
    }
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*(HD|FHD|UHD|4K|SD|HEVC|H\.?265|H\.?264)\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\([^)]*\)'), '');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeId(String id) {
    var normalized = id.toLowerCase();
    final parenMatch = RegExp(r'\((\w+)\)').firstMatch(normalized);
    if (parenMatch != null) {
      final callSign = parenMatch.group(1)!;
      final suffix =
          RegExp(
            r'\.(us|uk|ca|au|nz|de|fr|es|it|mx)$',
          ).firstMatch(normalized)?.group(0) ??
          '';
      return '$callSign$suffix'.replaceAll(RegExp(r'[._\-\s]'), '');
    }
    final stripped = normalized.replaceAll(RegExp(r'[._\-\s]'), '');
    final prefixMatch = RegExp(
      r'^(abc|cbs|nbc|fox|pbs|cw)(\w{3,})(.*)$',
    ).firstMatch(stripped);
    if (prefixMatch != null) {
      return prefixMatch.group(2)! + prefixMatch.group(3)!;
    }
    normalized = stripped.replaceAll(RegExp(r'[,_]'), '');
    normalized = normalized.replaceAll(
      RegExp(r'(hd|fhd|uhd|4k|sd|hevc|h265|h264)'),
      '',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'(newyork|losangeles|chicago|sanfrancisco|washington|detroit|denver|boston|houston|dallas|philadelphia|atlanta|miami|seattle|portland|phoenix|tampa)',
      ),
      '',
    );
    return normalized;
  }

  static Set<String> _tokens(String cleaned) => cleaned
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 1)
      .toSet();
}

class _CandidateScore {
  _CandidateScore(this.def, this.scores, this.reasons);

  final EpgChannelDefinition def;
  final List<double> scores;
  final List<String> reasons;
}
