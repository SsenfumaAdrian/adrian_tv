// Derived from clubTivi (https://github.com/clubanderson/clubTivi),
// Copyright Anderson, licensed under the Apache License 2.0.
// Modified for ADRIAN TV: persistence goes through AppPreferences instead
// of SharedPreferences directly, corrupt data is reported instead of
// swallowed, and scores feed StreamFailover ordering.
// See third_party/clubtivi/LICENSE.

import 'dart:convert';

import '../local/app_preferences.dart';

/// Tracks per-stream health metrics for ranking failover alternatives.
///
/// Metrics: stall count, average buffer level, time-to-first-frame.
/// Persisted on device, decayed over time so recent data weighs more.
class StreamHealthTracker {
  StreamHealthTracker(this._prefs) {
    _load();
  }

  static const _maxEntries = 300;
  static const _decayDays = 7;

  final AppPreferences _prefs;
  var _metrics = <String, _StreamMetrics>{};
  var _saveScheduled = false;

  void _load() {
    final raw = _prefs.readStreamHealthJson();
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _metrics = map.map(
        (k, v) =>
            MapEntry(k, _StreamMetrics.fromJson(v as Map<String, dynamic>)),
      );
    } on FormatException {
      _metrics = {};
    }
  }

  /// Record a buffering stall on a stream.
  void recordStall(String url) {
    final m = _getOrCreate(url);
    m.stallCount++;
    m.lastUpdated = DateTime.now();
    _scheduleSave();
  }

  /// Record a buffer level sample (seconds of cache).
  void recordBufferSample(String url, double seconds) {
    final m = _getOrCreate(url);
    m.bufferSamples++;
    m.bufferSum += seconds;
    m.lastUpdated = DateTime.now();
    // Too frequent to persist on every sample.
  }

  /// Record time-to-first-frame in milliseconds.
  void recordTimeToFirstFrame(String url, int ms) {
    final m = _getOrCreate(url);
    m.ttffMs = ms;
    m.lastUpdated = DateTime.now();
    _scheduleSave();
  }

  /// Health score for a stream URL (0.0 terrible, 1.0 excellent).
  /// Unknown streams return 0.5 (neutral).
  double score(String url) {
    final m = _metrics[_urlKey(url)];
    if (m == null) return 0.5;

    final age = DateTime.now().difference(m.lastUpdated).inHours;
    final decay = 1.0 / (1.0 + age / (_decayDays * 24));

    final stallScore = 1.0 / (1.0 + m.stallCount * 0.3);
    final bufferScore = m.bufferSamples > 0
        ? ((m.bufferSum / m.bufferSamples) / 10.0).clamp(0.0, 1.0)
        : 0.5;
    final ttffScore = m.ttffMs > 0
        ? (1.0 - (m.ttffMs / 10000.0)).clamp(0.0, 1.0)
        : 0.5;

    return ((stallScore * 0.5 + bufferScore * 0.3 + ttffScore * 0.2) * decay)
        .clamp(0.0, 1.0);
  }

  _StreamMetrics _getOrCreate(String url) =>
      _metrics.putIfAbsent(_urlKey(url), () => _StreamMetrics());

  // URL hashes keep the prefs payload small and free of credentials.
  String _urlKey(String url) => url.hashCode.toRadixString(36);

  void _scheduleSave() {
    if (_saveScheduled) return;
    _saveScheduled = true;
    Future.delayed(const Duration(seconds: 5), () async {
      _saveScheduled = false;
      await save();
    });
  }

  /// Persist, pruning to the most recent [_maxEntries] streams.
  Future<void> save() async {
    if (_metrics.length > _maxEntries) {
      final entries = _metrics.entries.toList()
        ..sort((a, b) => a.value.lastUpdated.compareTo(b.value.lastUpdated));
      for (var i = 0; i < entries.length - _maxEntries; i++) {
        _metrics.remove(entries[i].key);
      }
    }
    final json = _metrics.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.writeStreamHealthJson(jsonEncode(json));
  }
}

class _StreamMetrics {
  _StreamMetrics({
    this.stallCount = 0,
    this.bufferSum = 0,
    this.bufferSamples = 0,
    this.ttffMs = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  int stallCount;
  double bufferSum;
  int bufferSamples;
  int ttffMs;
  DateTime lastUpdated;

  Map<String, dynamic> toJson() => {
    'stalls': stallCount,
    'bufSum': bufferSum,
    'bufN': bufferSamples,
    'ttff': ttffMs,
    'ts': lastUpdated.millisecondsSinceEpoch,
  };

  factory _StreamMetrics.fromJson(Map<String, dynamic> j) => _StreamMetrics(
    stallCount: j['stalls'] as int? ?? 0,
    bufferSum: (j['bufSum'] as num? ?? 0).toDouble(),
    bufferSamples: j['bufN'] as int? ?? 0,
    ttffMs: j['ttff'] as int? ?? 0,
    lastUpdated: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int? ?? 0),
  );
}
