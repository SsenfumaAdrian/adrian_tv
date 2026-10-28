import '../models/channel.dart';

/// A channel entry captured while parsing, before a stable id is assigned.
class ParsedChannel {
  const ParsedChannel({
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.group,
    this.tvgId,
    this.tvgName,
    this.order,
  });

  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? group;
  final String? tvgId;
  final String? tvgName;
  final int? order;
}

/// Parser for M3U/M3U8 extended playlists (#EXTINF lines).
///
/// Tolerant of: missing attributes, `#EXTGRP:` group lines, comment noise,
/// CRLF input and data-URI/relative URLs (skipped when unusable).
class M3uParser {
  const M3uParser._();

  static final _extinfRegex = RegExp(
    r'^#EXTINF\s*:\s*(-?\d+(?:\.\d+)?)\s*(.*)$',
  );
  static final _attrRegex = RegExp(
    r'([a-zA-Z0-9_-]+)\s*=\s*"([^"]*)"|([a-zA-Z0-9_-]+)\s*=\s*([^\s,]+)',
  );

  /// Parses [playlist] into channels for [sourceId].
  ///
  /// Duplicate stream URLs are kept (IPTV providers rotate mirrors under the
  /// same name); duplicates of name+url pairs are collapsed.
  static List<Channel> parse(String playlist, {required String sourceId}) {
    final lines = playlist.split(RegExp(r'\r\n|\r|\n'));
    final result = <Channel>[];
    final seen = <String>{};

    ParsedChannel? pending;
    String? extGrp;
    var index = 0;

    void flush(String url) {
      final trimmed = url.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) return;
      final name = pending?.name.isNotEmpty == true
          ? pending!.name
          : _nameFromUrl(trimmed);
      final parsed = ParsedChannel(
        name: name,
        streamUrl: trimmed,
        logoUrl: pending?.logoUrl,
        group: pending?.group ?? extGrp,
        tvgId: pending?.tvgId,
        tvgName: pending?.tvgName,
        order: pending?.order,
      );
      final key = '${parsed.name}|${parsed.streamUrl}';
      if (seen.add(key)) {
        result.add(_toChannel(parsed, sourceId, index));
      }
      index++;
      pending = null;
      extGrp = null;
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        pending = _parseExtInf(line);
        continue;
      }
      if (line.startsWith('#EXTGRP')) {
        final value = line.split(':').last.trim();
        if (value.isNotEmpty) extGrp = value;
        continue;
      }
      if (line.startsWith('#')) continue; // other directives/comments
      flush(line);
    }

    return result;
  }

  static ParsedChannel? _parseExtInf(String line) {
    final match = _extinfRegex.firstMatch(line);
    if (match == null) return null;
    final attributePart = match.group(2) ?? '';

    String? logo, tvgId, tvgName, group;
    int? order;

    final attrs = <String, String>{};
    for (final m in _attrRegex.allMatches(attributePart)) {
      final key = (m.group(1) ?? m.group(3) ?? '').toLowerCase();
      final value = m.group(2) ?? m.group(4) ?? '';
      if (key.isNotEmpty) attrs[key] = value;
    }

    for (final entry in attrs.entries) {
      switch (entry.key) {
        case 'tvg-logo':
        case 'logo':
          logo = entry.value.isEmpty ? null : entry.value;
        case 'tvg-id':
          tvgId = entry.value.isEmpty ? null : entry.value;
        case 'tvg-name':
          tvgName = entry.value.isEmpty ? null : entry.value;
        case 'group-title':
          group = entry.value.isEmpty ? null : entry.value;
        case 'tvg-chno':
          order = int.tryParse(entry.value);
      }
    }

    // Display name is everything after the last comma outside quotes.
    final name = _displayName(attributePart, fallback: tvgName);
    if (name == null) return null;

    return ParsedChannel(
      name: name,
      streamUrl: '',
      logoUrl: logo,
      group: group,
      tvgId: tvgId,
      tvgName: tvgName,
      order: order,
    );
  }

  static String? _displayName(String attributePart, {String? fallback}) {
    var depth = 0;
    var lastTopLevelComma = -1;
    for (var i = 0; i < attributePart.length; i++) {
      final c = attributePart[i];
      if (c == '"') {
        depth = depth == 0 ? 1 : 0;
      } else if (c == ',' && depth == 0) {
        lastTopLevelComma = i;
      }
    }
    var name = lastTopLevelComma >= 0
        ? attributePart.substring(lastTopLevelComma + 1)
        : attributePart;
    name = name.trim();
    if (name.isEmpty) name = (fallback ?? '').trim();
    return name.isEmpty ? null : name;
  }

  static String _nameFromUrl(String url) {
    final cleaned = url.split(RegExp(r'[?#]')).first;
    final segments = cleaned.split('/')..removeWhere((s) => s.isEmpty);
    return segments.isEmpty ? url : segments.last;
  }

  static Channel _toChannel(ParsedChannel p, String sourceId, int index) {
    return Channel(
      id: Channel.buildId(
        sourceId: sourceId,
        name: p.name,
        tvgId: p.tvgId,
        index: index,
      ),
      name: p.name,
      streamUrl: p.streamUrl,
      sourceId: sourceId,
      logoUrl: p.logoUrl,
      group: p.group,
      tvgId: p.tvgId,
      tvgName: p.tvgName,
      order: p.order,
    );
  }
}
