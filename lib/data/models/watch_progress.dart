import 'package:equatable/equatable.dart';

/// A watch-history entry for a channel/VOD item.
class WatchProgress extends Equatable {
  const WatchProgress({
    required this.channelId,
    required this.channelName,
    required this.watchedAt,
    this.positionMs,
    this.durationMs,
    this.logoUrl,
  });

  final String channelId;
  final String channelName;
  final DateTime watchedAt;
  final int? positionMs;
  final int? durationMs;
  final String? logoUrl;

  /// Fraction watched; null when it cannot be computed (live streams).
  double? get fraction {
    final pos = positionMs;
    final dur = durationMs;
    if (pos == null || dur == null || dur <= 0) return null;
    return (pos / dur).clamp(0.0, 1.0);
  }

  bool get isFinished {
    final f = fraction;
    return f != null && f > 0.92;
  }

  WatchProgress copyWith({
    DateTime? watchedAt,
    int? positionMs,
    int? durationMs,
  }) => WatchProgress(
    channelId: channelId,
    channelName: channelName,
    watchedAt: watchedAt ?? this.watchedAt,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    logoUrl: logoUrl,
  );

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'channelName': channelName,
    'watchedAt': watchedAt.toIso8601String(),
    'positionMs': positionMs,
    'durationMs': durationMs,
    'logoUrl': logoUrl,
  };

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
    channelId: json['channelId'] as String,
    channelName: json['channelName'] as String,
    watchedAt: DateTime.parse(json['watchedAt'] as String),
    positionMs: (json['positionMs'] as num?)?.toInt(),
    durationMs: (json['durationMs'] as num?)?.toInt(),
    logoUrl: json['logoUrl'] as String?,
  );

  @override
  List<Object?> get props => [
    channelId,
    channelName,
    watchedAt,
    positionMs,
    durationMs,
    logoUrl,
  ];
}
