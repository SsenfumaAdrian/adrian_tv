import 'package:dio/dio.dart';

import '../models/content_source.dart';
import '../models/programme.dart';
import '../parsers/xmltv_parser.dart';

/// Provides programme-guide data per channel.
///
/// Remote sources can point at an XMLTV URL; the bundled demo source gets a
/// synthetic 24h schedule generated at runtime so the guide UI always has
/// realistic, current data without shipping stale timestamps.
class EpgService {
  EpgService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 45),
            ),
          );

  final Dio _dio;

  Future<EpgIndex> buildIndex(List<ContentSource> sources) async {
    final all = <Programme>[];
    for (final source in sources.where((s) => s.enabled)) {
      all.addAll(await programmesFor(source));
    }
    return EpgIndex(all);
  }

  Future<List<Programme>> programmesFor(ContentSource source) async {
    if (source.isDemo) return _demoProgrammes();
    final url = source.epgUrl;
    if (url == null || url.isEmpty) return const [];
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final body = response.data;
      if (body == null) return const [];
      return XmltvParser.parse(body).programmes;
    } on Exception {
      // A broken guide must never break channel playback.
      return const [];
    }
  }

  /// One-hour blocks across today covering the demo channel ids.
  static List<Programme> _demoProgrammes() {
    const slots = <(String, String, String)>[
      (
        'Open Movie Hour',
        'Film',
        'Blender Foundation open movies, free to redistribute.',
      ),
      (
        'Test Stream Matinee',
        'Entertainment',
        'Curated CDN test feeds for player diagnostics.',
      ),
      (
        'Motion Graphics Lab',
        'Science',
        'Short-form renders from the open-movie archives.',
      ),
      (
        'Evening Showcase',
        'Entertainment',
        'A rotating showcase of the demo catalogue.',
      ),
      ('Night Loop', 'Music', 'Ambient loops from open soundtracks.'),
      ('Late Streams', 'General', 'Overnight demo rotation.'),
    ];
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final programmes = <Programme>[];
    for (var hour = 0; hour < 24; hour++) {
      final slot = slots[hour % slots.length];
      final start = midnight.add(Duration(hours: hour));
      final ref = switch (hour % 3) {
        0 => 'demo.bbb',
        1 => 'demo.tos',
        _ => 'demo.ed',
      };
      programmes.add(
        Programme(
          channelRef: ref,
          title: slot.$1,
          start: start,
          stop: start.add(const Duration(hours: 1)),
          description: slot.$3,
          category: slot.$2,
        ),
      );
    }
    // Give every demo channel a full-day schedule.
    for (final extraRef in const [
      'demo.blazes',
      'demo.escape',
      'demo.joyrides',
    ]) {
      for (final p
          in programmes
              .where((p) => p.channelRef == 'demo.bbb')
              .toList(growable: false)) {
        programmes.add(
          Programme(
            channelRef: extraRef,
            title: p.title,
            start: p.start,
            stop: p.stop,
            description: p.description,
            category: p.category,
          ),
        );
      }
    }
    return programmes;
  }
}
