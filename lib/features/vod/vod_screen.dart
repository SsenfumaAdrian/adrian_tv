import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/media_item.dart';
import '../providers/app_providers.dart';
import 'widgets/media_poster.dart';

/// On-demand catalogue from authorised Xtream providers: movies and series.
class VodScreen extends ConsumerStatefulWidget {
  const VodScreen({super.key});

  @override
  ConsumerState<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends ConsumerState<VodScreen> {
  MediaKind _kind = MediaKind.movie;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(mediaCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('On Demand'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                SegmentedButton<MediaKind>(
                  segments: const [
                    ButtonSegment(
                      value: MediaKind.movie,
                      icon: Icon(Icons.movie_outlined),
                      label: Text('Movies'),
                    ),
                    ButtonSegment(
                      value: MediaKind.series,
                      icon: Icon(Icons.tv_outlined),
                      label: Text('Series'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.violet
                          : AppColors.surfaceBright,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter titles…',
                    prefixIcon: Icon(Icons.filter_alt),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
        ),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Notice(
          icon: Icons.error_outline,
          title: 'Catalogue unavailable',
          message: '$e',
        ),
        data: (load) {
          final q = _query.trim().toLowerCase();
          final items = load
              .ofKind(_kind)
              .where((i) => q.isEmpty || i.title.toLowerCase().contains(q))
              .toList();
          if (items.isEmpty) {
            return load.items.isEmpty
                ? const _Notice(
                    icon: Icons.movie_filter_outlined,
                    title: 'No movies or series yet',
                    message:
                        'On-demand content appears when you add an Xtream '
                        'provider that includes a VOD catalogue. ADRIAN TV '
                        'only shows content your providers make available.',
                  )
                : const _Notice(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'Try a different filter.',
                  );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              childAspectRatio: 0.62,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) =>
                MediaPoster(item: items[i], width: double.infinity),
          );
        },
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
