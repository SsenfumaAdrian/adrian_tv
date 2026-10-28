import '../local/secure_store.dart';
import 'channel_repository.dart' show PlaylistException;
import '../models/content_source.dart';
import '../models/media_item.dart';
import '../remote/xtream_client.dart';

/// Loads movies and series from Xtream-compatible providers.
///
/// Like live playlists, VOD data is never cached to disk because stream
/// URLs embed provider credentials.
class MediaRepository {
  MediaRepository({XtreamClient? client, CredentialsStore? credentials})
    : _client = client ?? XtreamClient(),
      // ignore: prefer_initializing_formals
      _credentials = credentials;

  final XtreamClient _client;
  final CredentialsStore? _credentials;

  Future<CatalogLoad> loadCatalog(List<ContentSource> sources) async {
    final items = <MediaItem>[];
    final errors = <String, String>{};
    for (final source in sources.where(
      (s) => s.enabled && s.type == SourceType.xtream,
    )) {
      try {
        items.addAll(await _loadFor(source));
      } on PlaylistException catch (e) {
        errors[source.name] = e.message;
      } on Exception catch (e) {
        errors[source.name] = '$e';
      }
    }
    return CatalogLoad(items: items, errors: errors);
  }

  Future<List<MediaItem>> _loadFor(ContentSource source) async {
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
      throw PlaylistException('Missing Xtream credentials for ${source.name}.');
    }
    final movies = (await _client.getVodStreams(baseUrl, credentials))
        .map(
          (json) => XtreamMediaMapper.movieFromJson(
            json,
            baseUrl: baseUrl,
            credentials: credentials,
            sourceId: source.id,
          ),
        )
        .whereType<MediaItem>();
    final series = (await _client.getSeries(baseUrl, credentials))
        .map(
          (json) => XtreamMediaMapper.seriesFromJson(json, sourceId: source.id),
        )
        .whereType<MediaItem>();
    return [...movies, ...series];
  }

  Future<SeriesContent> loadSeries(ContentSource source, MediaItem item) async {
    final baseUrl = source.url;
    final store = _credentials;
    final seriesId = item.providerId;
    if (baseUrl == null || seriesId == null || store == null) {
      throw PlaylistException('Series is no longer available.');
    }
    final credentials = await store.read(source.id);
    if (credentials == null) {
      throw PlaylistException('Missing Xtream credentials for ${source.name}.');
    }
    final payload = await _client.getSeriesInfo(baseUrl, credentials, seriesId);
    return XtreamMediaMapper.seriesContent(
      payload,
      item: item,
      baseUrl: baseUrl,
      credentials: credentials,
    );
  }
}

class CatalogLoad {
  const CatalogLoad({required this.items, required this.errors});

  final List<MediaItem> items;
  final Map<String, String> errors;

  List<MediaItem> ofKind(MediaKind kind) =>
      items.where((i) => i.kind == kind).toList();
}
