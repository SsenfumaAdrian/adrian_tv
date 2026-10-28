import 'package:adrian_tv/data/local/secure_store.dart';
import 'package:adrian_tv/data/remote/xtream_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const credentials = ProviderCredentials(
    username: 'user one',
    password: 'p@ss/w',
  );

  group('XtreamMapper', () {
    test('builds HLS live stream URLs with encoded credentials', () {
      final url = XtreamMapper.liveStreamUrl(
        'http://prov.example:8080/',
        credentials,
        '1234',
      );
      expect(
        url,
        'http://prov.example:8080/live/user%20one/p%40ss%2Fw/1234.m3u8',
      );
    });

    test('maps streams to channels with category names', () {
      final channels = XtreamMapper.mapLiveStreams(
        streams: [
          const XtreamStream(
            streamId: '10',
            name: 'News 24',
            categoryId: 'c1',
            epgChannelId: 'news24.us',
            number: 5,
          ),
          const XtreamStream(streamId: '11', name: 'Sports', categoryId: 'c2'),
          const XtreamStream(streamId: '', name: 'Broken'),
        ],
        categories: const [
          XtreamCategory(id: 'c1', name: 'News'),
          XtreamCategory(id: 'c2', name: 'Sports'),
        ],
        baseUrl: 'https://prov.example',
        credentials: credentials,
        sourceId: 'src',
      );
      expect(channels, hasLength(2)); // empty streamId skipped
      expect(channels.first.name, 'News 24');
      expect(channels.first.group, 'News');
      expect(channels.first.tvgId, 'news24.us');
      expect(channels.first.order, 5);
      expect(channels.last.group, 'Sports');
      expect(
        channels.first.streamUrl,
        startsWith('https://prov.example/live/'),
      );
    });

    test('unknown category falls back to Uncategorised', () {
      final channels = XtreamMapper.mapLiveStreams(
        streams: const [
          XtreamStream(streamId: '1', name: 'X', categoryId: 'missing'),
        ],
        categories: const [],
        baseUrl: 'https://prov.example',
        credentials: credentials,
        sourceId: 'src',
      );
      expect(channels.single.group, 'Uncategorised');
    });
  });

  group('XtreamStream JSON', () {
    test('parses provider payload shape', () {
      final s = XtreamStream.fromJson(const {
        'num': 3,
        'name': 'Demo',
        'stream_id': 42,
        'stream_icon': 'https://i/42.png',
        'category_id': 7,
        'epg_channel_id': '',
      });
      expect(s.streamId, '42');
      expect(s.categoryId, '7');
      expect(s.epgChannelId, isNull); // empty string normalised to null
      expect(s.logo, 'https://i/42.png');
    });
  });
}
