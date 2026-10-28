import 'package:dio/dio.dart';

import '../local/secure_store.dart';
import '../models/channel.dart';
import '../models/media_item.dart';

/// Xtream Codes API client (player_api.php).
///
/// Only the standard, well-documented read-only endpoints are used:
/// live categories, live streams and the stream URL convention. VOD and
/// series endpoints can be layered on the same shape later.
class XtreamClient {
  XtreamClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  Future<List<XtreamCategory>> getLiveCategories(
    String baseUrl,
    ProviderCredentials credentials,
  ) async {
    final data = await _get(
      baseUrl,
      credentials,
      action: 'get_live_categories',
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(XtreamCategory.fromJson)
        .toList();
  }

  Future<List<XtreamStream>> getLiveStreams(
    String baseUrl,
    ProviderCredentials credentials,
  ) async {
    final data = await _get(baseUrl, credentials, action: 'get_live_streams');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(XtreamStream.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getVodStreams(
    String baseUrl,
    ProviderCredentials credentials,
  ) async {
    final data = await _get(baseUrl, credentials, action: 'get_vod_streams');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getSeries(
    String baseUrl,
    ProviderCredentials credentials,
  ) async {
    final data = await _get(baseUrl, credentials, action: 'get_series');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getSeriesInfo(
    String baseUrl,
    ProviderCredentials credentials,
    String seriesId,
  ) async {
    final response = await _dio.get<dynamic>(
      XtreamClient._apiUrl(baseUrl),
      queryParameters: {
        ...XtreamClient._authParams(credentials),
        'action': 'get_series_info',
        'series_id': seriesId,
      },
    );
    final data = response.data;
    return data is Map ? data.cast<String, dynamic>() : const {};
  }

  /// Returns true when the provider accepts these credentials.
  Future<bool> authenticate(
    String baseUrl,
    ProviderCredentials credentials,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        _apiUrl(baseUrl),
        queryParameters: _authParams(credentials),
      );
      final userInfo = (response.data as Map?)?['user_info'];
      return (userInfo?['auth'] ?? 0) == 1;
    } on Exception {
      return false;
    }
  }

  Future<dynamic> _get(
    String baseUrl,
    ProviderCredentials credentials, {
    required String action,
  }) async {
    final response = await _dio.get<dynamic>(
      _apiUrl(baseUrl),
      queryParameters: {..._authParams(credentials), 'action': action},
    );
    final data = response.data;
    if (data is List) return data;
    return const <dynamic>[];
  }

  static String _apiUrl(String baseUrl) =>
      '${trimSlash(baseUrl)}/player_api.php';

  static String trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  static Map<String, String> _authParams(ProviderCredentials c) => {
    'username': c.username,
    'password': c.password,
  };
}

class XtreamCategory {
  const XtreamCategory({required this.id, required this.name});

  factory XtreamCategory.fromJson(Map<String, dynamic> json) => XtreamCategory(
    id: '${json['category_id'] ?? ''}',
    name: '${json['category_name'] ?? 'Uncategorised'}',
  );

  final String id;
  final String name;
}

class XtreamStream {
  const XtreamStream({
    required this.streamId,
    required this.name,
    this.categoryId,
    this.logo,
    this.epgChannelId,
    this.number,
  });

  factory XtreamStream.fromJson(Map<String, dynamic> json) => XtreamStream(
    streamId: '${json['stream_id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    categoryId: json['category_id'] == null ? null : '${json['category_id']}',
    logo: _nullIfEmpty(json['stream_icon']),
    epgChannelId: _nullIfEmpty(json['epg_channel_id']),
    number: (json['num'] as num?)?.toInt(),
  );

  final String streamId;
  final String name;
  final String? categoryId;
  final String? logo;
  final String? epgChannelId;
  final int? number;
}

String? _nullIfEmpty(Object? value) {
  final s = value?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

/// Pure mapping from Xtream payloads to ADRIAN TV [Channel]s.
abstract final class XtreamMapper {
  static String liveStreamUrl(
    String baseUrl,
    ProviderCredentials credentials,
    String streamId,
  ) =>
      '${XtreamClient.trimSlash(baseUrl)}/live/'
      '${Uri.encodeComponent(credentials.username)}/'
      '${Uri.encodeComponent(credentials.password)}/'
      '$streamId.m3u8';

  static List<Channel> mapLiveStreams({
    required List<XtreamStream> streams,
    required List<XtreamCategory> categories,
    required String baseUrl,
    required ProviderCredentials credentials,
    required String sourceId,
  }) {
    final categoryNames = {for (final c in categories) c.id: c.name};
    final channels = <Channel>[];
    for (var i = 0; i < streams.length; i++) {
      final s = streams[i];
      if (s.streamId.isEmpty || s.name.isEmpty) continue;
      channels.add(
        Channel(
          id: Channel.buildId(
            sourceId: sourceId,
            name: s.name,
            tvgId: s.epgChannelId,
            index: i,
          ),
          name: s.name,
          streamUrl: liveStreamUrl(baseUrl, credentials, s.streamId),
          sourceId: sourceId,
          logoUrl: s.logo,
          group: categoryNames[s.categoryId] ?? 'Uncategorised',
          tvgId: s.epgChannelId,
          order: s.number,
        ),
      );
    }
    return channels;
  }
}

/// Pure mapping from Xtream VOD payloads to [MediaItem]/[Episode] models.
abstract final class XtreamMediaMapper {
  static String movieUrl(
    String baseUrl,
    ProviderCredentials credentials,
    String streamId,
    String extension,
  ) => _streamUrl(baseUrl, credentials, 'movie', streamId, extension);

  static String episodeUrl(
    String baseUrl,
    ProviderCredentials credentials,
    String streamId,
    String extension,
  ) => _streamUrl(baseUrl, credentials, 'series', streamId, extension);

  static String _streamUrl(
    String baseUrl,
    ProviderCredentials credentials,
    String verb,
    String streamId,
    String extension,
  ) =>
      '${XtreamClient.trimSlash(baseUrl)}/$verb/'
      '${Uri.encodeComponent(credentials.username)}/'
      '${Uri.encodeComponent(credentials.password)}/'
      '$streamId.${Uri.encodeComponent(extension)}';

  static MediaItem? movieFromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
    required ProviderCredentials credentials,
    required String sourceId,
  }) {
    final streamId = '${json['stream_id'] ?? ''}';
    final name = '${json['name'] ?? ''}';
    if (streamId.isEmpty || name.isEmpty) return null;
    final rating = double.tryParse('${json['rating'] ?? ''}');
    return MediaItem(
      id: MediaItem.movieId(sourceId, streamId),
      sourceId: sourceId,
      kind: MediaKind.movie,
      title: name,
      providerId: streamId,
      playUrl: movieUrl(
        baseUrl,
        credentials,
        streamId,
        '${json['container_extension'] ?? 'mp4'}',
      ),
      coverUrl: _nullIfEmpty(json['stream_icon']),
      genre: _nullIfEmpty(json['category_id']),
      rating: rating,
    );
  }

  static MediaItem? seriesFromJson(
    Map<String, dynamic> json, {
    required String sourceId,
  }) {
    final id = '${json['series_id'] ?? ''}';
    final name = '${json['name'] ?? ''}';
    if (id.isEmpty || name.isEmpty) return null;
    final rating = double.tryParse('${json['rating'] ?? ''}');
    return MediaItem(
      id: MediaItem.seriesId(sourceId, id),
      sourceId: sourceId,
      kind: MediaKind.series,
      title: name,
      providerId: id,
      coverUrl: _nullIfEmpty(json['cover']),
      plot: _nullIfEmpty(json['plot']),
      genre: _nullIfEmpty(json['genre']),
      releaseDate: _nullIfEmpty(json['releaseDate']),
      rating: rating,
      categoryId: json['category_id'] == null ? null : '${json['category_id']}',
    );
  }

  /// `get_series_info` payload: `{info: {...}, episodes: {"1": [...]}}`.
  static SeriesContent seriesContent(
    Map<String, dynamic> payload, {
    required MediaItem item,
    required String baseUrl,
    required ProviderCredentials credentials,
  }) {
    final bySeason = <int, List<Episode>>{};
    final raw = payload['episodes'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final season = int.tryParse('${entry.key}') ?? 1;
        final list = (entry.value as List?) ?? const [];
        for (final e in list.cast<Map<String, dynamic>>()) {
          final streamId = '${e['id'] ?? e['stream_id'] ?? ''}';
          if (streamId.isEmpty) continue;
          final episodeNumber = int.tryParse('${e['episode_num'] ?? ''}') ?? 0;
          final title = '${e['title'] ?? 'Episode $episodeNumber'}';
          bySeason
              .putIfAbsent(season, () => [])
              .add(
                Episode(
                  id: 'ep:${item.sourceId}:${item.providerId}:$streamId',
                  seriesRef: item.id,
                  season: season,
                  number: episodeNumber,
                  title: title,
                  playUrl: episodeUrl(
                    baseUrl,
                    credentials,
                    streamId,
                    '${e['container_extension'] ?? 'mp4'}',
                  ),
                  thumbUrl: _nullIfEmpty((e['info'] as Map?)?['movie_image']),
                  plot: _nullIfEmpty((e['info'] as Map?)?['plot']),
                  duration: _nullIfEmpty((e['info'] as Map?)?['duration']),
                ),
              );
        }
      }
    }
    for (final list in bySeason.values) {
      list.sort((a, b) => a.number.compareTo(b.number));
    }
    return SeriesContent(item: item, episodesBySeason: bySeason);
  }
}
