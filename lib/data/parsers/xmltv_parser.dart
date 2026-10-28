import 'package:xml/xml.dart';

import '../models/channel.dart';
import '../models/programme.dart';

/// A single `<channel>` definition from an XMLTV document.
class EpgChannelDefinition {
  const EpgChannelDefinition({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

class EpgParseResult {
  const EpgParseResult({
    required this.programmes,
    required this.channelDefinitions,
  });

  final List<Programme> programmes;
  final List<EpgChannelDefinition> channelDefinitions;
}

/// Parser for XMLTV electronic programme guides.
///
/// Accepts both `YYYYMMDDHHmmss ±HHMM` timestamps and ISO-8601. Programmes
/// with unparseable times are skipped rather than failing the whole guide.
class XmltvParser {
  const XmltvParser._();

  static EpgParseResult parse(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final root = document.rootElement;

    final channelDefs = <EpgChannelDefinition>[];
    for (final node in root.findElements('channel')) {
      final id = node.getAttribute('id');
      if (id == null) continue;
      final display = _firstText(node, 'display-name') ?? id;
      channelDefs.add(EpgChannelDefinition(id: id, displayName: display));
    }

    final programmes = <Programme>[];
    for (final node in root.findElements('programme')) {
      final channelRef = node.getAttribute('channel');
      final start = _parseXmltvTime(node.getAttribute('start'));
      final stop = _parseXmltvTime(node.getAttribute('stop'));
      if (channelRef == null || start == null || stop == null) continue;

      final title = _firstText(node, 'title') ?? '';
      if (title.isEmpty) continue;

      programmes.add(
        Programme(
          channelRef: channelRef,
          title: title,
          start: start,
          stop: stop,
          description: _firstText(node, 'desc'),
          category: _firstText(node, 'category'),
        ),
      );
    }

    programmes.sort((a, b) => a.start.compareTo(b.start));
    return EpgParseResult(
      programmes: programmes,
      channelDefinitions: channelDefs,
    );
  }

  static String? _firstText(XmlElement parent, String name) {
    for (final element in parent.findElements(name)) {
      final text = element.innerText.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// `20260101120000 +0100`, `20260101T120000Z` or bare `20260101120000`.
  static DateTime? _parseXmltvTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?$',
    ).firstMatch(value);
    if (match == null) return DateTime.tryParse(value);

    final wallClock = DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6) ?? '0'),
    );
    final offset = match.group(7);
    if (offset == null) return wallClock; // local time when unspecified
    final sign = offset[0] == '-' ? -1 : 1;
    final minutes =
        int.parse(offset.substring(1, 3)) * 60 + int.parse(offset.substring(3));
    // Wall clock minus declared offset = the UTC instant.
    return DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
    ).subtract(Duration(minutes: sign * minutes));
  }
}

/// In-memory index over a programme list for the guide UI.
///
/// Lookup is tiered like clubTivi's mapper (studied as reference, re-
/// implemented): explicit `tvg-id` first, then normalised display-name
/// matching so playlists without tvg-id still get guide data.
class EpgIndex {
  EpgIndex(
    Iterable<Programme> programmes, {
    Iterable<EpgChannelDefinition> channelDefinitions = const [],
  }) : _byChannelRef = _groupByRef(programmes),
       _refByNormalisedName = {
         for (final def in channelDefinitions)
           _normalise(def.displayName): def.id,
       };

  final Map<String, List<Programme>> _byChannelRef;
  final Map<String, String> _refByNormalisedName;

  static final _qualitySuffix = RegExp(
    r'(hd|fhd|uhd|sd|4k|8k|plus|hevc|x26[45]|720p|1080p|2160p)+$',
  );

  static String _normalise(String name) {
    var n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    String previous;
    do {
      previous = n;
      n = n.replaceAll(_qualitySuffix, '');
    } while (n != previous);
    return n;
  }

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

  /// Resolve the guide channel id for [channel]: exact tvg-id, then
  /// normalised name fallbacks (channel name, then tvg-name).
  String? resolveRef(Channel channel) {
    final tvgId = channel.tvgId;
    if (tvgId != null && _byChannelRef.containsKey(tvgId)) return tvgId;
    for (final name in [
      channel.name,
      if (channel.tvgName != null) channel.tvgName!,
    ]) {
      final ref = _refByNormalisedName[_normalise(name)];
      if (ref != null && _byChannelRef.containsKey(ref)) return ref;
    }
    return tvgId;
  }

  List<Programme> programmesForChannel(Channel channel) =>
      programmesFor(resolveRef(channel));

  Programme? nowFor(Channel channel, [DateTime? at]) =>
      now(resolveRef(channel), at);

  List<Programme> upcomingForChannel(
    Channel channel, {
    DateTime? at,
    int limit = 10,
  }) => upcoming(resolveRef(channel), at: at, limit: limit);

  List<Programme> programmesFor(String? tvgId) {
    if (tvgId == null) return const [];
    return _byChannelRef[tvgId] ?? const [];
  }

  Programme? now(String? tvgId, [DateTime? at]) {
    final moment = at ?? DateTime.now();
    for (final p in programmesFor(tvgId)) {
      if (p.contains(moment)) return p;
      if (p.start.isAfter(moment)) break;
    }
    return null;
  }

  /// Programs starting after [at] (or after the current one), capped at [limit].
  List<Programme> upcoming(String? tvgId, {DateTime? at, int limit = 10}) {
    final moment = at ?? DateTime.now();
    final current = now(tvgId, moment);
    final startFrom = current == null ? moment : current.stop;
    return programmesFor(
      tvgId,
    ).where((p) => !p.stop.isBefore(startFrom)).take(limit).toList();
  }
}
