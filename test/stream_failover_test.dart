import 'package:adrian_tv/data/models/channel.dart';
import 'package:adrian_tv/data/services/stream_failover.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = Channel(
    id: 'a',
    name: 'News 24',
    streamUrl: 'http://mirror1/news.m3u8',
    sourceId: 's',
  );
  const aMirror = Channel(
    id: 'a2',
    name: 'NEWS 24', // case-insensitive mirror
    streamUrl: 'http://mirror2/news.ts',
    sourceId: 's',
  );
  const aSameUrl = Channel(
    id: 'a3',
    name: 'News 24',
    streamUrl: 'http://mirror1/news.m3u8', // duplicate URL
    sourceId: 's',
  );
  const differentName = Channel(
    id: 'b',
    name: 'News 24 HD',
    streamUrl: 'http://mirror1/other.m3u8',
    sourceId: 's',
  );
  const otherSource = Channel(
    id: 'c',
    name: 'News 24',
    streamUrl: 'http://other/news.m3u8',
    sourceId: 's2',
  );

  test('collects same-name mirrors from the same source, deduped', () {
    final candidates = StreamFailover.candidatesFor(a, const [
      a,
      aMirror,
      aSameUrl,
      differentName,
      otherSource,
    ]);
    expect(candidates, ['http://mirror1/news.m3u8', 'http://mirror2/news.ts']);
  });

  test('single channel yields exactly its own URL', () {
    expect(StreamFailover.candidatesFor(differentName, const [differentName]), [
      'http://mirror1/other.m3u8',
    ]);
  });
}
