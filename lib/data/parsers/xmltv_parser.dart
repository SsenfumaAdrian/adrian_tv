import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import '../models/programme.dart';

/// A single `<channel>` definition from an XMLTV document.
class EpgChannelDefinition {
  const EpgChannelDefinition({
    required this.id,
    required this.displayName,
    this.displayNames = const [],
    this.iconUrl,
    this.lcn,
  });

  final String id;
  final String displayName;

  /// Every `<display-name>` value; used by the scored matcher.
  final List<String> displayNames;
  final String? iconUrl;

  /// Logical channel number from `<lcn>`, if the guide provides one.
  final String? lcn;
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
      final names = node
          .findElements('display-name')
          .map((e) => e.innerText.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final icon = node.findElements('icon').firstOrNull;
      channelDefs.add(
        EpgChannelDefinition(
          id: id,
          displayName: names.isEmpty ? id : names.first,
          displayNames: names,
          iconUrl: icon?.getAttribute('src'),
          lcn: _firstText(node, 'lcn'),
        ),
      );
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
