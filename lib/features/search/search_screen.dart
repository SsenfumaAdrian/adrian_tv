import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../channels/widgets/channel_card.dart';
import '../providers/app_providers.dart';
import '../vod/widgets/media_poster.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(playlistLoadProvider);
    final channels = channelsAsync.valueOrNull?.channels ?? const [];
    final catalog = ref.watch(mediaCatalogProvider).valueOrNull;
    final media = catalog?.items ?? const [];
    final q = _query.trim().toLowerCase();

    final channelResults = q.isEmpty
        ? const []
        : channels
              .where(
                (c) =>
                    c.name.toLowerCase().contains(q) ||
                    (c.group?.toLowerCase().contains(q) ?? false) ||
                    (c.tvgName?.toLowerCase().contains(q) ?? false),
              )
              .toList();
    final mediaResults = q.isEmpty
        ? const []
        : media.where((m) => m.title.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 44,
          child: TextField(
            controller: _textController,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search channels and categories…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _textController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: channelsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : q.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search,
                    size: 56,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Search channels, movies and series across all your '
                    'enabled sources.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : channelResults.isEmpty && mediaResults.isEmpty
          ? Center(
              child: Text(
                'Nothing matches "$_query".',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          : CustomScrollView(
              slivers: [
                if (channelResults.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _SectionHeader('Live channels')),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.86,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => ChannelCard(
                          channel: channelResults[i],
                          width: double.infinity,
                        ),
                        childCount: channelResults.length,
                      ),
                    ),
                  ),
                ],
                if (mediaResults.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _SectionHeader('Movies & series')),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => MediaPoster(
                          item: mediaResults[i],
                          width: double.infinity,
                        ),
                        childCount: mediaResults.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
