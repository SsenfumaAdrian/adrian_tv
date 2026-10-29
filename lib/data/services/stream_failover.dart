import '../models/channel.dart';

/// IPTV providers commonly list the same channel several times (mirror
/// CDNs, `.ts` + `.m3u8` variants). When playback of one URL fails, the
/// player walks through the remaining candidates before surfacing an error.
abstract final class StreamFailover {
  /// Candidate URLs in preference order. When [healthOf] is given, mirrors
  /// are ordered best-health-first (stable); otherwise playlist order wins.
  static List<String> candidatesFor(
    Channel channel,
    List<Channel> all, {
    double Function(String url)? healthOf,
  }) {
    final nameKey = channel.name.toLowerCase();
    final urls = <String>[channel.streamUrl];
    for (final other in all) {
      if (other.id == channel.id || other.sourceId != channel.sourceId) {
        continue;
      }
      if (other.name.toLowerCase() != nameKey) continue;
      if (!urls.contains(other.streamUrl)) urls.add(other.streamUrl);
    }
    final health = healthOf;
    if (health != null && urls.length > 1) {
      final indexed = List.generate(urls.length, (i) => i);
      // Dart's sort is not stable: tie-break on original playlist order.
      indexed.sort((a, b) {
        final byHealth = health(urls[b]).compareTo(health(urls[a]));
        return byHealth != 0 ? byHealth : a.compareTo(b);
      });
      return [for (final i in indexed) urls[i]];
    }
    return urls;
  }
}
