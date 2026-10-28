import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_preferences.dart';
import '../../data/local/secure_store.dart';
import '../../data/models/channel.dart';
import '../../data/models/content_source.dart';
import '../../data/models/programme.dart';
import '../../data/models/watch_progress.dart';
import '../../data/repositories/channel_repository.dart';
import '../../data/services/epg_service.dart';
import '../../data/parsers/xmltv_parser.dart';

/// Overridden with the initialised instance in `main.dart`.
final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => throw UnimplementedError('appPreferencesProvider not overridden'),
);

final credentialsStoreProvider = Provider<CredentialsStore>(
  (ref) => SecureCredentialsStore(),
);

final channelRepositoryProvider = Provider<ChannelRepository>(
  (ref) => ChannelRepository(credentials: ref.watch(credentialsStoreProvider)),
);

final epgServiceProvider = Provider<EpgService>((ref) => EpgService());

// ---------------------------------------------------------------------------
// Sources
// ---------------------------------------------------------------------------

class SourcesNotifier extends Notifier<List<ContentSource>> {
  @override
  List<ContentSource> build() =>
      ref.watch(appPreferencesProvider).readSources();

  Future<void> add(ContentSource source) async {
    if (state.any((s) => s.id == source.id)) {
      await update(
        source.id,
        (s) => s.copyWith(
          name: source.name,
          url: source.url,
          epgUrl: source.epgUrl,
        ),
      );
      return;
    }
    await _save([...state, source]);
  }

  Future<void> remove(String id) async {
    if (id == ContentSource.demoId) return; // demo source is always available
    await ref.read(credentialsStoreProvider).delete(id);
    await _save(state.where((s) => s.id != id).toList());
  }

  Future<void> toggle(String id) async {
    await update(id, (s) => s.copyWith(enabled: !s.enabled));
  }

  Future<void> update(
    String id,
    ContentSource Function(ContentSource) change,
  ) async {
    await _save(state.map((s) => s.id == id ? change(s) : s).toList());
  }

  Future<void> _save(List<ContentSource> next) async {
    state = next;
    await ref.read(appPreferencesProvider).writeSources(next);
  }
}

final sourcesProvider = NotifierProvider<SourcesNotifier, List<ContentSource>>(
  SourcesNotifier.new,
);

// ---------------------------------------------------------------------------
// Channels
// ---------------------------------------------------------------------------

/// Result of loading every enabled source. A single failing source is
/// reported in [errors] instead of breaking the whole channel list.
class PlaylistLoad {
  const PlaylistLoad({required this.channels, required this.errors});

  final List<Channel> channels;

  /// Source name -> human-readable failure reason.
  final Map<String, String> errors;
}

final playlistLoadProvider = FutureProvider<PlaylistLoad>((ref) async {
  final sources = ref.watch(sourcesProvider).where((s) => s.enabled).toList();
  final repo = ref.watch(channelRepositoryProvider);
  final channels = <Channel>[];
  final errors = <String, String>{};
  await Future.wait(
    sources.map((s) async {
      try {
        channels.addAll(await repo.loadChannels(s));
      } on PlaylistException catch (e) {
        errors[s.name] = e.message;
      } on Exception catch (e) {
        errors[s.name] = '$e';
      }
    }),
  );
  channels.sort((a, b) {
    final oa = a.order ?? 1 << 30;
    final ob = b.order ?? 1 << 30;
    if (oa != ob) return oa.compareTo(ob);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return PlaylistLoad(channels: channels, errors: errors);
});

final channelsProvider = Provider<List<Channel>>(
  (ref) => ref.watch(playlistLoadProvider).valueOrNull?.channels ?? const [],
);

final channelGroupsProvider = Provider<Set<String>>((ref) {
  final channels = ref.watch(channelsProvider);
  return channels.map((c) => c.group ?? 'Uncategorised').toSet();
});

final favouriteChannelsProvider = Provider<List<Channel>>((ref) {
  final ids = ref.watch(favouritesProvider);
  final channels = ref.watch(channelsProvider);
  return channels.where((c) => ids.contains(c.id)).toList();
});

// ---------------------------------------------------------------------------
// Favourites
// ---------------------------------------------------------------------------

class FavouritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      Set.of(ref.watch(appPreferencesProvider).readFavourites());

  Future<void> toggle(String channelId) async {
    final next = {...state};
    if (!next.remove(channelId)) next.add(channelId);
    state = next;
    await ref.read(appPreferencesProvider).writeFavourites(next);
  }

  Future<void> clear() async {
    state = {};
    await ref.read(appPreferencesProvider).writeFavourites({});
  }
}

final favouritesProvider = NotifierProvider<FavouritesNotifier, Set<String>>(
  FavouritesNotifier.new,
);

// ---------------------------------------------------------------------------
// Watch history
// ---------------------------------------------------------------------------

class HistoryNotifier extends Notifier<List<WatchProgress>> {
  static const _maxEntries = 200;

  @override
  List<WatchProgress> build() =>
      ref.watch(appPreferencesProvider).readHistory();

  Future<void> record(WatchProgress entry) async {
    final next = [
      entry,
      ...state.where((e) => e.channelId != entry.channelId),
    ].take(_maxEntries).toList();
    state = next;
    await ref.read(appPreferencesProvider).writeHistory(next);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(appPreferencesProvider).writeHistory(const []);
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, List<WatchProgress>>(
  HistoryNotifier.new,
);

/// Recently watched, not yet finished — the "Continue watching" rail.
final continueWatchingProvider = Provider<List<WatchProgress>>((ref) {
  final history = ref.watch(historyProvider);
  return history.where((e) => !e.isFinished).take(20).toList();
});

// ---------------------------------------------------------------------------
// EPG
// ---------------------------------------------------------------------------

final epgIndexProvider = FutureProvider<EpgIndex>((ref) async {
  final sources = ref.watch(sourcesProvider).where((s) => s.enabled).toList();
  final epg = ref.watch(epgServiceProvider);
  return epg.buildIndex(sources);
});

final currentProgrammeProvider = Provider.family<Programme?, Channel?>((
  ref,
  channel,
) {
  if (channel == null) return null;
  final index = ref.watch(epgIndexProvider).valueOrNull;
  return index?.nowFor(channel);
});
