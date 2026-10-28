import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../data/models/channel.dart';
import '../../data/models/watch_progress.dart';
import '../channels/widgets/channel_card.dart';
import '../providers/app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(channelsProvider);

    return Scaffold(
      body: SafeArea(
        child: channelsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load content\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(channelsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (channels) => channels.isEmpty
              ? const _EmptyHome()
              : _HomeBody(channels: channels),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 72),
            const SizedBox(height: 20),
            Text(
              'Welcome to ADRIAN TV',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'ADRIAN TV is a player: it shows live TV from playlists you '
              'configure. Add a source in Settings, or enable the bundled '
              'demo playlist to explore the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go(AppRoute.settings),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Manage sources'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.channels});

  final List<Channel> channels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouriteChannelsProvider);
    final continueWatching = ref.watch(continueWatchingProvider);
    final byId = {for (final c in channels) c.id: c};

    final groups = <String, List<Channel>>{};
    for (final c in channels) {
      groups.putIfAbsent(c.group ?? 'Uncategorised', () => []).add(c);
    }

    Channel? featured;
    for (final e in continueWatching) {
      final c = byId[e.channelId];
      if (c != null) {
        featured = c;
        break;
      }
    }
    featured ??= favourites.isNotEmpty ? favourites.first : channels.first;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(channel: featured),
        if (continueWatching.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Rail(
            title: 'Continue watching',
            children: [
              for (final entry in continueWatching)
                if (byId[entry.channelId] != null)
                  _HistoryCard(entry: entry, channel: byId[entry.channelId]!),
            ],
          ),
        ],
        if (favourites.isNotEmpty)
          _Rail(
            title: 'My favourites',
            children: [for (final c in favourites) ChannelCard(channel: c)],
          ),
        for (final entry in groups.entries)
          _Rail(
            title: entry.key,
            seeAllRoute: AppRoute.live,
            children: [
              for (final c in entry.value.take(18)) ChannelCard(channel: c),
            ],
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programme = ref.watch(currentProgrammeProvider(channel));
    final isFavourite = ref.watch(favouritesProvider).contains(channel.id);

    return SizedBox(
      height: MediaQuery.sizeOf(context).width > 900 ? 380 : 300,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.violet.withValues(alpha: 0.45),
                  AppColors.background,
                  AppColors.cyan.withValues(alpha: 0.22),
                ],
                stops: const [0.1, 0.65, 1.0],
              ),
            ),
            child: const Center(
              child: Opacity(
                opacity: 0.14,
                child: Icon(Icons.live_tv, size: 260, color: Colors.white),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC0A0A12)],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandWordmark(fontSize: 16),
                const SizedBox(height: 14),
                Text(
                  channel.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    shadows: [Shadow(blurRadius: 18, color: Colors.black87)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (programme != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Now: ${programme.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () => context.go('/player/${channel.id}'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Watch live'),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      tooltip: isFavourite
                          ? 'Unfavourite'
                          : 'Add to favourites',
                      onPressed: () => ref
                          .read(favouritesProvider.notifier)
                          .toggle(channel.id),
                      icon: Icon(
                        isFavourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.title, required this.children, this.seeAllRoute});

  final String title;
  final List<Widget> children;
  final String? seeAllRoute;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (seeAllRoute != null)
                  TextButton(
                    onPressed: () => context.go(seeAllRoute!),
                    child: const Text('See all'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => children[i],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.channel});

  final WatchProgress entry;
  final Channel channel;

  static final _ago = DateFormat.yMEd();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TvFocusable(
        onTap: () => context.go('/player/${channel.id}'),
        semanticLabel: 'Resume ${channel.name}',
        borderRadius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceBright,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Icon(Icons.history, color: AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              'Watched ${_ago.format(entry.watchedAt)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
