import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../local/secure_store.dart';
import '../models/channel.dart';
import '../models/content_source.dart';
import '../parsers/m3u_parser.dart';
import '../remote/xtream_client.dart';

/// Loads playlists for configured sources, parsing M3U and caching results
/// on disk so large lists do not re-download on every launch.
///
/// Sensitive sources (Xtream) are never written to the disk cache because
/// their stream URLs embed provider credentials.
class ChannelRepository {
  ChannelRepository({
    Dio? dio,
    Duration cacheMaxAge = const Duration(hours: 6),
    XtreamClient? xtreamClient,
    CredentialsStore? credentials,
  }) : _dio = dio ?? _defaultDio(),
       // Dart has no private named parameters, so `this._cacheMaxAge` is not
       // applicable for the public `cacheMaxAge` argument.
       // ignore: prefer_initializing_formals
       _cacheMaxAge = cacheMaxAge,
       _xtream = xtreamClient ?? XtreamClient(dio: dio ?? _defaultDio()),
       // ignore: prefer_initializing_formals
       _credentials = credentials;

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  final Dio _dio;
  final Duration _cacheMaxAge;
  final XtreamClient _xtream;
  final CredentialsStore? _credentials;

  Future<List<Channel>> loadChannels(ContentSource source) async {
    switch (source.type) {
      case SourceType.demo:
      case SourceType.localM3u:
        final raw = await _readLocal(source);
        return M3uParser.parse(raw, sourceId: source.id);
      case SourceType.remoteM3u:
        return _loadRemotePlaylist(source);
      case SourceType.xtream:
        return _loadXtream(source);
    }
  }

  Future<String> _readLocal(ContentSource source) async {
    final url = source.url;
    if (url == null) return '';
    if (source.isDemo) {
      return rootBundle.loadString(url);
    }
    final file = File(url);
    if (!await file.exists()) {
      throw PlaylistException('Playlist file not found: $url');
    }
    return file.readAsString();
  }

  Future<List<Channel>> _loadRemotePlaylist(ContentSource source) async {
    final url = source.url;
    if (url == null || Uri.tryParse(url) == null || !url.startsWith('http')) {
      throw PlaylistException('Invalid playlist URL for ${source.name}');
    }
    final cacheFile = await _cacheFile(source.id);
    if (await _isFresh(cacheFile)) {
      try {
        return _decodeCache(await cacheFile.readAsString());
      } on Object {
        // Corrupt cache: fall through to re-download.
      }
    }
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    final channels = M3uParser.parse(body, sourceId: source.id);
    unawaited(_writeCache(cacheFile, channels));
    return channels;
  }

  Future<List<Channel>> _loadXtream(ContentSource source) async {
    final baseUrl = source.url;
    final store = _credentials;
    if (baseUrl == null || !baseUrl.startsWith('http')) {
      throw PlaylistException('Invalid Xtream server URL for ${source.name}');
    }
    if (store == null) {
      throw PlaylistException('No credential storage configured');
    }
    final credentials = await store.read(source.id);
    if (credentials == null) {
      throw PlaylistException(
        'Missing Xtream credentials for ${source.name}. '
        'Re-add the provider in Settings.',
      );
    }
    final categories = await _xtream.getLiveCategories(baseUrl, credentials);
    final streams = await _xtream.getLiveStreams(baseUrl, credentials);
    return XtreamMapper.mapLiveStreams(
      streams: streams,
      categories: categories,
      baseUrl: baseUrl,
      credentials: credentials,
      sourceId: source.id,
    );
  }

  Future<File> _cacheFile(String sourceId) async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory(p.join(dir.path, 'playlist_cache'));
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    final safeId = sourceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File(p.join(cacheDir.path, '$safeId.json'));
  }

  Future<bool> _isFresh(File file) async {
    if (!await file.exists()) return false;
    final modified = await file.lastModified();
    return DateTime.now().difference(modified) < _cacheMaxAge;
  }

  Future<void> _writeCache(File file, List<Channel> channels) async {
    try {
      await file.writeAsString(
        const JsonEncoder().convert(channels.map((c) => c.toJson()).toList()),
      );
    } on IOException catch (e) {
      debugPrint('Playlist cache write failed: $e');
    }
  }

  List<Channel> _decodeCache(String raw) {
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Channel.fromJson).toList();
  }

  /// Clears cached playlists so sources re-download (used by "refresh").
  Future<void> clearCache() async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory(p.join(dir.path, 'playlist_cache'));
    if (await cacheDir.exists()) await cacheDir.delete(recursive: true);
  }
}

class PlaylistException implements Exception {
  const PlaylistException(this.message);

  final String message;

  @override
  String toString() => message;
}
