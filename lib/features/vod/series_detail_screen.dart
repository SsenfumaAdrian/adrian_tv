import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import '../providers/app_providers.dart';

/// Series detail: metadata plus season tabs and episode playback.
class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    super.key,
    required this.sourceId,
    required this.seriesId,
  });

  final String sourceId;
  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(seriesContentProvider((sourceId, seriesId)));

    return Scaffold(
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Text(
              'Could not load series: $e',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (content) {
          if (content == null || content.episodesBySeason.isEmpty) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Text(
                  'This series has no playable episodes.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return _SeriesBody(content: content);
        },
      ),
    );
  }
}

class _SeriesBody extends ConsumerStatefulWidget {
  const _SeriesBody({required this.content});

  final SeriesContent content;

  @override
  ConsumerState<_SeriesBody> createState() => _SeriesBodyState();
}

class _SeriesBodyState extends ConsumerState<_SeriesBody> {
  late int _season = widget.content.episodesBySeason.keys.reduce(
    (a, b) => a < b ? a : b,
  );

  @override
  Widget build(BuildContext context) {
    final item = widget.content.item;
    final episodes = widget.content.episodesBySeason[_season] ?? const [];
    final seasons = widget.content.episodesBySeason.keys.toList()..sort();

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          expandedHeight: 240,
          backgroundColor: AppColors.surface,
          title: Text(item.title, overflow: TextOverflow.ellipsis),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (item.coverUrl != null)
                  CachedNetworkImage(
                    imageUrl: item.coverUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, _, _) =>
                        const ColoredBox(color: AppColors.surfaceBright),
                  )
                else
                  const ColoredBox(color: AppColors.surfaceBright),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE60A0A12), Colors.transparent],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 10,
                        children: [
                          if (item.releaseDate != null &&
                              item.releaseDate!.isNotEmpty)
                            _chip(item.releaseDate!),
                          if (item.rating != null && item.rating! > 0)
                            _chip('★ ${item.rating!.toStringAsFixed(1)}'),
                          if (item.genre != null &&
                              item.genre!.isNotEmpty &&
                              item.genre != 'N/A')
                            _chip(item.genre!),
                          _chip(
                            '${widget.content.seasonCount} season'
                            '${widget.content.seasonCount > 1 ? 's' : ''} · '
                            '${widget.content.episodeCount} episodes',
                          ),
                        ],
                      ),
                      if (item.plot != null && item.plot!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.plot!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in seasons)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: ChoiceChip(
                      label: Text('Season $s'),
                      selected: _season == s,
                      onSelected: (_) => setState(() => _season = s),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: episodes.length,
        itemBuilder: (context, i) {
          final episode = episodes[i];
          return ListTile(
            onTap: () => context.go(AppRoute.player(episode.id)),
            leading: SizedBox(
              width: 74,
              height: 42,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceBright,
                  ),
                  child: episode.thumbUrl == null
                      ? const Center(
                          child: Icon(Icons.play_circle_outline, size: 20),
                        )
                      : CachedNetworkImage(
                          imageUrl: episode.thumbUrl!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            title: Text(
              '${episode.number.toString().padLeft(2, '0')}. ${episode.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: episode.plot == null
                ? null
                : Text(
                    episode.plot!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: const Icon(Icons.play_arrow_rounded),
          );
        },
      ),
    );
  }

  Widget _chip(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
      ),
    ),
  );
}
