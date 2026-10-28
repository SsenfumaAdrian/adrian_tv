import 'package:adrian_tv/data/models/channel.dart';
import 'package:adrian_tv/data/models/programme.dart';
import 'package:adrian_tv/data/models/watch_progress.dart';
import 'package:adrian_tv/data/parsers/xmltv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XmltvParser', () {
    test('parses channels and programmes with offsets', () {
      const xml = '''
<?xml version="1.0"?>
<tv>
  <channel id="one.example">
    <display-name>One TV</display-name>
  </channel>
  <programme start="20260101120000 +0100" stop="20260101130000 +0100" channel="one.example">
    <title>Morning Show</title>
    <desc>A show</desc>
    <category>Kids</category>
  </programme>
  <programme start="20260101130000 +0100" stop="20260101140000 +0100" channel="one.example">
    <title>News at One</title>
  </programme>
</tv>
''';
      final result = XmltvParser.parse(xml);
      expect(result.channelDefinitions.single.id, 'one.example');
      expect(result.programmes, hasLength(2));
      final first = result.programmes.first;
      expect(first.title, 'Morning Show');
      expect(first.description, 'A show');
      expect(first.category, 'Kids');
      expect(first.duration, const Duration(hours: 1));
      // 12:00 +0100 == 11:00 UTC
      expect(first.start.toUtc(), DateTime.utc(2026, 1, 1, 11));
    });

    test('skips programmes with bad timestamps instead of failing', () {
      const xml = '''
<tv>
  <programme start="garbage" stop="20260101140000" channel="a"><title>X</title></programme>
  <programme start="20260101140000" stop="20260101150000" channel="a"><title>Y</title></programme>
</tv>
''';
      final result = XmltvParser.parse(xml);
      expect(result.programmes, hasLength(1));
      expect(result.programmes.single.title, 'Y');
    });
  });

  group('EpgIndex', () {
    List<Programme> sample() => [
      Programme(
        channelRef: 'a',
        title: 'Early',
        start: DateTime(2026, 1, 1, 8),
        stop: DateTime(2026, 1, 1, 9),
      ),
      Programme(
        channelRef: 'a',
        title: 'Mid',
        start: DateTime(2026, 1, 1, 9),
        stop: DateTime(2026, 1, 1, 10),
      ),
      Programme(
        channelRef: 'b',
        title: 'Other',
        start: DateTime(2026, 1, 1, 9),
        stop: DateTime(2026, 1, 1, 10),
      ),
    ];

    test('now() finds the containing programme', () {
      final index = EpgIndex(sample());
      expect(index.now('a', DateTime(2026, 1, 1, 9, 30))?.title, 'Mid');
      expect(index.now('a', DateTime(2026, 1, 1, 11)), isNull);
      expect(index.now(null), isNull);
    });

    test('upcoming() returns programmes from the current one onward', () {
      final index = EpgIndex(sample());
      final list = index.upcoming('a', at: DateTime(2026, 1, 1, 9, 15));
      expect(list.map((p) => p.title), ['Mid']);
    });

    test('progressAt clamps to 0..1', () {
      final p = sample().first;
      expect(p.progressAt(DateTime(2026, 1, 1, 8, 30)), 0.5);
      expect(p.progressAt(DateTime(2026, 1, 1, 7)), 0);
      expect(p.progressAt(DateTime(2026, 1, 1, 12)), 1);
    });

    test('resolveRef matches by normalised name when tvg-id absent', () {
      final index = EpgIndex(
        sample(),
        channelDefinitions: const [
          EpgChannelDefinition(id: 'a', displayName: 'Early Channel'),
        ],
      );
      final channel = Channel(
        id: 'x',
        name: 'Early Channel HD', // quality suffix stripped
        streamUrl: 'http://e/x.ts',
        sourceId: 's',
      );
      expect(index.resolveRef(channel), 'a');
      expect(
        index.nowFor(channel, DateTime(2026, 1, 1, 8, 30))?.title,
        'Early',
      );
    });

    test('resolveRef prefers exact tvg-id over name match', () {
      final index = EpgIndex(
        sample(),
        channelDefinitions: const [
          EpgChannelDefinition(id: 'a', displayName: 'Early Channel'),
        ],
      );
      final channel = Channel(
        id: 'x',
        name: 'Early Channel',
        streamUrl: 'http://e/x.ts',
        sourceId: 's',
        tvgId: 'b', // 'b' exists in the index and wins
      );
      expect(index.resolveRef(channel), 'b');
    });
  });

  group('WatchProgress', () {
    test('fraction and isFinished', () {
      final p = WatchProgress(
        channelId: 'c',
        channelName: 'C',
        watchedAt: DateTime(2026),
        positionMs: 95000,
        durationMs: 100000,
      );
      expect(p.fraction, closeTo(0.95, 0.001));
      expect(p.isFinished, isTrue);
      final live = WatchProgress(
        channelId: 'c',
        channelName: 'C',
        watchedAt: DateTime(2026),
      );
      expect(live.fraction, isNull);
      expect(live.isFinished, isFalse);
    });
  });
}
