import '../models/channel.dart';

/// IPTV providers commonly list the same channel several times (mirror
/// CDNs, `.ts` + `.m3u8` variants). When playback of one URL fails, the
/// player walks through the remaining candidates before surfacing an error.
abstract final class StreamFailover {
  static List<String> candidatesFor(Channel channel, List<Channel> all) {
    final nameKey = channel.name.toLowerCase();
    final urls = <String>[channel.streamUrl];
    for (final other in all) {
      if (other.id == channel.id || other.sourceId != channel.sourceId) {
        continue;
      }
      if (other.name.toLowerCase() != nameKey) continue;
      if (!urls.contains(other.streamUrl)) urls.add(other.streamUrl);
    }
    return urls;
  }
}
