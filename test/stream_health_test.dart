import 'package:adrian_tv/data/local/app_preferences.dart';
import 'package:adrian_tv/data/models/channel.dart';
import 'package:adrian_tv/data/services/stream_failover.dart';
import 'package:adrian_tv/data/services/stream_health_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<StreamHealthTracker> freshTracker() async {
    SharedPreferences.setMockInitialValues({});
    return StreamHealthTracker(
      AppPreferences(await SharedPreferences.getInstance()),
    );
  }

  group('StreamHealthTracker', () {
    test('unknown streams are neutral 0.5', () async {
      final tracker = await freshTracker();
      expect(tracker.score('http://never/seen.ts'), 0.5);
    });

    test('stalls lower the score below a clean stream', () async {
      final tracker = await freshTracker();
      tracker.recordTimeToFirstFrame('http://a/1.ts', 500);
      tracker.recordTimeToFirstFrame('http://a/2.ts', 500);
      tracker.recordStall('http://a/2.ts');
      tracker.recordStall('http://a/2.ts');
      tracker.recordStall('http://a/2.ts');
      expect(
        tracker.score('http://a/1.ts'),
        greaterThan(tracker.score('http://a/2.ts')),
      );
    });

    test('scores survive a save/load round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPreferences(await SharedPreferences.getInstance());
      final first = StreamHealthTracker(prefs);
      first.recordStall('http://x/1.ts');
      first.recordTimeToFirstFrame('http://x/1.ts', 9000);
      await first.save();

      final reloaded = StreamHealthTracker(prefs);
      expect(
        reloaded.score('http://x/1.ts'),
        closeTo(first.score('http://x/1.ts'), 0.01),
      );
    });
  });

  group('StreamFailover ordering', () {
    const channels = [
      Channel(
        id: 'a',
        name: 'News 24',
        streamUrl: 'http://slow/news.ts',
        sourceId: 's',
      ),
      Channel(
        id: 'b',
        name: 'News 24',
        streamUrl: 'http://good/news.ts',
        sourceId: 's',
      ),
      Channel(
        id: 'c',
        name: 'News 24',
        streamUrl: 'http://mid/news.ts',
        sourceId: 's',
      ),
    ];

    test('healthiest mirror is tried first', () {
      final candidates = StreamFailover.candidatesFor(
        channels.first,
        channels,
        healthOf: (url) => switch (url) {
          'http://good/news.ts' => 0.9,
          'http://mid/news.ts' => 0.6,
          _ => 0.1,
        },
      );
      expect(candidates.first, 'http://good/news.ts');
      expect(candidates[1], 'http://mid/news.ts');
    });

    test('equal health keeps playlist order (stable tie-break)', () {
      final candidates = StreamFailover.candidatesFor(
        channels.first,
        channels,
        healthOf: (_) => 0.5,
      );
      expect(candidates, [
        'http://slow/news.ts',
        'http://good/news.ts',
        'http://mid/news.ts',
      ]);
    });

    test('without health data playlist order wins', () {
      expect(StreamFailover.candidatesFor(channels.first, channels), [
        'http://slow/news.ts',
        'http://good/news.ts',
        'http://mid/news.ts',
      ]);
    });
  });
}
