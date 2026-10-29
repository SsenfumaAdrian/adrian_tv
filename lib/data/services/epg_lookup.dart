import '../models/channel.dart';
import '../models/programme.dart';
import '../parsers/xmltv_parser.dart' show EpgChannelDefinition;
import 'epg_matcher.dart';

/// In-memory index over a programme list for the guide UI.
///
/// Channel→guide resolution is tiered: exact `tvg-id` first, then the
/// scored [EpgMatcher] (call signs, normalized ids, fuzzy names, numbers,
/// logos with corroboration) so playlists without `tvg-id` still get guide
/// data. Results are cached per channel id.
class EpgIndex {
  EpgIndex(
    Iterable<Programme> programmes, {
    Iterable<EpgChannelDefinition> channelDefinitions = const [],
  }) : _byChannelRef = _groupByRef(programmes),
       _matcher = EpgMatcher(channelDefinitions.toList(growable: false));

  final Map<String, List<Programme>> _byChannelRef;
  final EpgMatcher _matcher;
  final _refCache = <String, String?>{};

  static Map<String, List<Programme>> _groupByRef(
    Iterable<Programme> programmes,
  ) {
    final map = <String, List<Programme>>{};
    for (final p in programmes) {
      map.putIfAbsent(p.channelRef, () => []).add(p);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
    return map;
  }

  bool get isEmpty => _byChannelRef.isEmpty;

  /// The guide channel id backing [channel], or its raw tvg-id when no
  /// match clears the auto-apply threshold.
  String? resolveRef(Channel channel) {
    final tvgId = channel.tvgId;
    if (tvgId != null && _byChannelRef.containsKey(tvgId)) return tvgId;
    return _refCache.putIfAbsent(channel.id, () {
      final match = _matcher.bestMatch(channel);
      return match.isAutoMatch ? match.epgChannelId : tvgId;
    });
  }

  List<Programme> programmesFor(String? tvgId) {
    if (tvgId == null) return const [];
    return _byChannelRef[tvgId] ?? const [];
  }

  List<Programme> programmesForChannel(Channel channel) =>
      programmesFor(resolveRef(channel));

  Programme? now(String? tvgId, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    for (final p in programmesFor(tvgId)) {
      if (p.contains(moment)) return p;
      if (p.start.isAfter(moment)) break;
    }
    return null;
  }

  Programme? nowFor(Channel channel, [DateTime? at]) =>
      now(resolveRef(channel), at);

  /// Programs starting after [at] (or after the current one), capped at [limit].
  List<Programme> upcoming(String? tvgId, {DateTime? at, int limit = 10}) {
    final moment = at ?? DateTime.now();
    final current = now(tvgId, moment);
    final startFrom = current == null ? moment : current.stop;
    return programmesFor(
      tvgId,
    ).where((p) => !p.stop.isBefore(startFrom)).take(limit).toList();
  }

  List<Programme> upcomingForChannel(
    Channel channel, {
    DateTime? at,
    int limit = 10,
  }) => upcoming(resolveRef(channel), at: at, limit: limit);
}
