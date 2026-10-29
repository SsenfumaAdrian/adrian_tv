import 'package:adrian_tv/data/models/channel.dart';
import 'package:adrian_tv/data/parsers/xmltv_parser.dart';
import 'package:adrian_tv/data/services/epg_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Channel ch(String name, {String? tvgId, String? logo, int? order}) => Channel(
    id: tvgId ?? name,
    name: name,
    streamUrl: 'http://e/$name.ts',
    sourceId: 's',
    tvgId: tvgId,
    logoUrl: logo,
    order: order,
  );

  group('EpgMatcher', () {
    test('exact tvg-id wins with confidence 1.0', () {
      final matcher = EpgMatcher(const [
        EpgChannelDefinition(id: 'cnn.us', displayName: 'CNN US'),
      ]);
      final result = matcher.bestMatch(ch('Whatever', tvgId: 'cnn.us'));
      expect(result.epgChannelId, 'cnn.us');
      expect(result.confidence, greaterThanOrEqualTo(1.0));
      expect(result.reasons, contains('exact_tvg_id'));
    });

    test('call sign in parentheses drives the match', () {
      final matcher = EpgMatcher(const [
        EpgChannelDefinition(id: 'wabc.us', displayName: 'WABC'),
        EpgChannelDefinition(id: 'cbs.us', displayName: 'CBS'),
      ]);
      final result = matcher.bestMatch(ch('ABC 7 (WABC) New York'));
      expect(result.epgChannelId, 'wabc.us');
      expect(result.isAutoMatch, isTrue);
    });

    test('pipe-separated names use the most specific segment', () {
      final matcher = EpgMatcher(const [
        EpgChannelDefinition(id: 'abc7', displayName: 'ABC 7 WABC'),
      ]);
      final result = matcher.bestMatch(ch('NY | New York | ABC 7 WABC'));
      expect(result.epgChannelId, 'abc7');
      expect(result.isAutoMatch, isTrue);
    });

    test('logo corroboration boosts a weak name match over threshold', () {
      final matcher = EpgMatcher(const [
        EpgChannelDefinition(
          id: 'discovery',
          displayName: 'Discovery Channel',
          iconUrl: 'https://logo/disc.png',
        ),
        EpgChannelDefinition(id: 'other', displayName: 'Other TV'),
      ]);
      // "Disc" alone is a contains-match (0.80) + logo (0.40) corroborated.
      final result = matcher.bestMatch(
        ch('Disc', logo: 'https://logo/disc.png'),
      );
      expect(result.epgChannelId, 'discovery');
      expect(result.reasons, containsAll(['fuzzy_name', 'logo_url']));
      expect(result.isAutoMatch, isTrue);
    });

    test('24/7 loop channels are never mapped', () {
      final matcher = EpgMatcher(const [
        EpgChannelDefinition(id: 'loop', displayName: 'Lofi Loop'),
      ]);
      final result = matcher.bestMatch(ch('24/7 Lofi Loop'));
      expect(result.confidence, 0);
    });

    test('channel number is a weak signal on its own', () {
      final matcher = EpgMatcher(const [
        EpgChannelDefinition(id: 'five', displayName: 'Channel Five', lcn: '5'),
      ]);
      final result = matcher.bestMatch(ch('Unrelated Name', order: 5));
      expect(result.epgChannelId, 'five');
      expect(result.isAutoMatch, isFalse);
      expect(result.confidence, closeTo(0.55, 0.01)); // 0.50 + 0.05 boost
    });

    test('quality suffixes do not block matching', () {
      final matcher = EpgMatcher(const [
        EpgChannelDefinition(id: 'espn', displayName: 'ESPN'),
      ]);
      final result = matcher.bestMatch(ch('ESPN HD'));
      expect(result.epgChannelId, 'espn');
      expect(result.isAutoMatch, isTrue);
    });
  });
}
