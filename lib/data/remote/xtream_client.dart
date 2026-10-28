import 'package:dio/dio.dart';

import '../local/secure_store.dart';
import '../models/channel.dart';

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
