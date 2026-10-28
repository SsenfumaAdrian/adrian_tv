import 'package:equatable/equatable.dart';

enum MediaKind { movie, series }

/// A VOD item (movie or series) supplied by an authorised provider.
///
/// [id] is globally unique across sources and kinds:
/// `vod:<sourceId>:<streamId>` or `ser:<sourceId>:<seriesId>`.
/// Movies carry a ready [playUrl]; series are containers and resolve
/// episode URLs through the series-info endpoint.
class MediaItem extends Equatable {
  const MediaItem({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.title,
    this.providerId,
    this.playUrl,
    this.coverUrl,
    this.plot,
    this.genre,
    this.releaseDate,
    this.rating,
    this.categoryId,
  });

  static String movieId(String sourceId, String streamId) =>
      'vod:$sourceId:$streamId';

  static String seriesId(String sourceId, String id) => 'ser:$sourceId:$id';

  final String id;
  final String sourceId;
  final MediaKind kind;
  final String title;

  /// Provider-side numeric id (stream_id for movies, series_id for series).
  final String? providerId;
  final String? playUrl;
  final String? coverUrl;
  final String? plot;
  final String? genre;
  final String? releaseDate;

  /// Provider rating, expected 0–10 scale.
  final double? rating;
  final String? categoryId;

  @override
  List<Object?> get props => [
    id,
    sourceId,
    kind,
    title,
    providerId,
    playUrl,
    coverUrl,
  ];
}

/// One episode of a series, with a resolved playback URL.
class Episode extends Equatable {
  const Episode({
    required this.id,
    required this.seriesRef,
    required this.season,
    required this.number,
    required this.title,
    required this.playUrl,
    this.thumbUrl,
    this.plot,
    this.duration,
  });

  final String id;
  final String seriesRef;
  final int season;
  final int number;
  final String title;
  final String playUrl;
  final String? thumbUrl;
  final String? plot;
  final String? duration;

  @override
  List<Object?> get props => [id, season, number, title, playUrl];
}

/// Series detail: metadata plus episodes grouped by season.
class SeriesContent extends Equatable {
  const SeriesContent({required this.item, required this.episodesBySeason});

  final MediaItem item;
  final Map<int, List<Episode>> episodesBySeason;

  int get seasonCount => episodesBySeason.length;

  int get episodeCount =>
      episodesBySeason.values.fold(0, (sum, list) => sum + list.length);

  List<Episode> get allEpisodes => [
    for (final list in episodesBySeason.values) ...list,
  ];

  @override
  List<Object?> get props => [item, episodesBySeason];
}
