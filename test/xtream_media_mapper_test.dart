import 'package:adrian_tv/data/local/secure_store.dart';
import 'package:adrian_tv/data/models/media_item.dart';
import 'package:adrian_tv/data/remote/xtream_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const credentials = ProviderCredentials(username: 'u', password: 'p');

  group('XtreamMediaMapper', () {
    test('movieFromJson builds item with playback URL', () {
      final item = XtreamMediaMapper.movieFromJson(
        const {
          'stream_id': 42,
          'name': 'Big Movie',
          'stream_icon': 'https://cover/42.jpg',
          'rating': '7.5',
          'container_extension': 'mkv',
        },
        baseUrl: 'http://prov:80',
        credentials: credentials,
        sourceId: 's',
      );

      expect(item, isNotNull);
      expect(item!.kind, MediaKind.movie);
      expect(item.id, 'vod:s:42');
      expect(item.playUrl, 'http://prov:80/movie/u/p/42.mkv');
      expect(item.rating, 7.5);
      expect(item.coverUrl, 'https://cover/42.jpg');
    });

    test('movieFromJson skips entries without id or name', () {
      expect(
        XtreamMediaMapper.movieFromJson(
          const {'stream_id': '', 'name': 'X'},
          baseUrl: 'http://p',
          credentials: credentials,
          sourceId: 's',
        ),
        isNull,
      );
    });

    test('seriesFromJson maps metadata without a play URL', () {
      final item = XtreamMediaMapper.seriesFromJson(const {
        'series_id': 7,
        'name': 'Show Time',
        'cover': 'https://cover/7.jpg',
        'plot': 'A show about time.',
        'genre': 'Drama',
        'releaseDate': '2024-01-01',
      }, sourceId: 's');

      expect(item!.id, 'ser:s:7');
      expect(item.kind, MediaKind.series);
      expect(item.playUrl, isNull);
      expect(item.plot, 'A show about time.');
    });

    test('seriesContent groups episodes by season with URLs', () {
      final item = MediaItem(
        id: 'ser:s:7',
        sourceId: 's',
        kind: MediaKind.series,
        title: 'Show Time',
        providerId: '7',
      );
      final content = XtreamMediaMapper.seriesContent(
        const {
          'episodes': {
            '1': [
              {
                'id': 101,
                'episode_num': 2,
                'title': 'Second',
                'container_extension': 'mp4',
              },
              {
                'id': 100,
                'episode_num': 1,
                'title': 'First',
                'container_extension': 'mp4',
                'info': {'plot': 'Pilot episode', 'duration': '00:44:00'},
              },
            ],
            '2': [
              {'id': 200, 'episode_num': 1, 'title': 'Season two'},
            ],
          },
        },
        item: item,
        baseUrl: 'http://prov',
        credentials: credentials,
      );

      expect(content.seasonCount, 2);
      expect(content.episodeCount, 3);
      final s1 = content.episodesBySeason[1]!;
      expect(s1.map((e) => e.title), ['First', 'Second']); // sorted by number
      expect(s1.first.playUrl, 'http://prov/series/u/p/100.mp4');
      expect(s1.first.plot, 'Pilot episode');
      expect(s1.first.id, 'ep:s:7:100');
      expect(content.allEpisodes.last.season, 2);
    });

    test('empty or malformed episodes payload yields no crash', () {
      final content = XtreamMediaMapper.seriesContent(
        const {},
        item: const MediaItem(
          id: 'ser:s:7',
          sourceId: 's',
          kind: MediaKind.series,
          title: 'X',
        ),
        baseUrl: 'http://prov',
        credentials: credentials,
      );
      expect(content.episodesBySeason, isEmpty);
    });
  });
}
