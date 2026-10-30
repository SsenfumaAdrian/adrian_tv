import 'dart:io';

import 'package:adrian_tv/data/models/channel.dart';
import 'package:adrian_tv/data/parsers/m3u_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M3uParser', () {
    test('parses EXTINF attributes and display name', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="cnn.us" tvg-name="CNN US" tvg-logo="https://logo/cnn.png" group-title="News",CNN US HD
https://example.com/cnn.m3u8
''';
      final channels = M3uParser.parse(playlist, sourceId: 's1');
      expect(channels, hasLength(1));
      final c = channels.single;
      expect(c.name, 'CNN US HD');
      expect(c.streamUrl, 'https://example.com/cnn.m3u8');
      expect(c.tvgId, 'cnn.us');
      expect(c.group, 'News');
      expect(c.logoUrl, 'https://logo/cnn.png');
      expect(c.isHls, isTrue);
      expect(c.sourceId, 's1');
    });

    test('handles #EXTGRP fallback and unquoted attributes', () {
      const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id=sport1,Sport 1
#EXTGRP:Premium
http://example.com/sport1.ts
''';
      final channels = M3uParser.parse(playlist, sourceId: 's2');
      // EXTGRP appears after EXTINF but before the URL line.
      expect(channels.single.group, 'Premium');
      expect(channels.single.tvgId, 'sport1');
      expect(channels.single.isHls, isFalse);
    });

    test('skips comments and blank lines, derives name from URL', () {
      const playlist = '''
#EXTM3U
# a comment
https://example.com/stream/last.m3u8
''';
      final channels = M3uParser.parse(playlist, sourceId: 's3');
      expect(channels, hasLength(1));
      expect(channels.single.name, 'last.m3u8');
    });

    test('falls back to tvg-name when display name is empty', () {
      const playlist = '#EXTINF:-1 tvg-name="Backup Name",\nhttp://e/x.ts';
      final channels = M3uParser.parse(playlist, sourceId: 's4');
      expect(channels.single.name, 'Backup Name');
    });

    test('collapses duplicate name+url pairs', () {
      const playlist = '''
#EXTINF:-1,One
http://e/1.ts
#EXTINF:-1,One
http://e/1.ts
''';
      final channels = M3uParser.parse(playlist, sourceId: 's5');
      expect(channels, hasLength(1));
    });

    test('keeps same-name channels with different urls distinct ids', () {
      const playlist = '''
#EXTINF:-1,Two
http://e/a.ts
#EXTINF:-1,Two
http://e/b.ts
''';
      final channels = M3uParser.parse(playlist, sourceId: 's6');
      expect(channels, hasLength(2));
      expect(channels[0].id, isNot(channels[1].id));
    });

    test('parses the bundled demo playlist', () async {
      const assetPath = 'assets/demo/demo_channels.m3u';
      final content = await File(assetPath).readAsString();
      final channels = M3uParser.parse(content, sourceId: 'demo');
      expect(channels.length, greaterThanOrEqualTo(5));
      expect(channels.every((c) => c.name.startsWith('ADRIAN Demo')), isTrue);
      expect(channels.every((c) => c.group == 'Demo'), isTrue);
      // At least one plain-mp4 stream so web builds have a playable demo.
      expect(channels.any((c) => c.streamUrl.endsWith('.mp4')), isTrue);
    });

    test('parses a 5,000-channel playlist quickly', () {
      final buffer = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 5000; i++) {
        buffer
          ..writeln(
            '#EXTINF:-1 tvg-id="ch$i" group-title="Group ${i % 50}",Channel $i',
          )
          ..writeln('http://example.com/ch/$i.m3u8');
      }
      final sw = Stopwatch()..start();
      final channels = M3uParser.parse(buffer.toString(), sourceId: 'big');
      sw.stop();
      expect(channels, hasLength(5000));
      expect(channels.first.group, 'Group 0');
      expect(channels.last.name, 'Channel 4999');
      // Generous ceiling: guards against accidental O(n^2) regressions.
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('parses the bundled public free-to-air playlist', () async {
      const assetPath = 'assets/sources/public_free_to_air.m3u';
      final content = await File(assetPath).readAsString();
      final channels = M3uParser.parse(content, sourceId: 'public');
      expect(channels.length, greaterThanOrEqualTo(7));
      // Every shipped public feed must be https and a real broadcaster.
      expect(channels.every((c) => c.streamUrl.startsWith('https://')), isTrue);
      expect(
        channels.map((c) => c.name),
        containsAll(['DW English', 'France 24 English', 'NASA TV Public']),
      );
    });

    test('Channel JSON round-trip', () {
      const c = Channel(
        id: 'x',
        name: 'X',
        streamUrl: 'http://e/x.ts',
        sourceId: 's',
        group: 'G',
      );
      expect(Channel.fromJson(c.toJson()), c);
    });
  });
}
