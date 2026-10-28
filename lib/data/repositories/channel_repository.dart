import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/channel.dart';
import '../models/content_source.dart';
import '../parsers/m3u_parser.dart';

/// Loads playlists for configured sources, parsing M3U and caching results
/// on disk so large lists do not re-download on every launch.
class ChannelRepository {
  ChannelRepository({Dio? dio, Duration cacheMaxAge = const Duration(hours: 6)})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      // Dart has no private named parameters, so `this._cacheMaxAge` is not
      // applicable for the public `cacheMaxAge` argument.
      // ignore: prefer_initializing_formals
      _cacheMaxAge = cacheMaxAge;

  final Dio _dio;
  final Duration _cacheMaxAge;

  Future<List<Channel>> loadChannels(ContentSource source) async {
    switch (source.type) {
      case SourceType.demo:
      case SourceType.localM3u:
        final raw = await _readLocal(source);
        return M3uParser.parse(raw, sourceId: source.id);
      case SourceType.remoteM3u:
        return _loadRemote(source);
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

  Future<List<Channel>> _loadRemote(ContentSource source) async {
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
