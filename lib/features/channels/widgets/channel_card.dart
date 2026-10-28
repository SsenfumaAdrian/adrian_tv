import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../data/models/channel.dart';
import '../../providers/app_providers.dart';

/// Poster-style card used by home rails and the channel grid.
class ChannelCard extends ConsumerWidget {
  const ChannelCard({
    super.key,
    required this.channel,
    this.width = 160,
    this.onTap,
  });

  final Channel channel;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritesProvider);
    final isFavourite = favourites.contains(channel.id);
    final programme = ref.watch(currentProgrammeProvider(channel));

    return TvFocusable(
      onTap: onTap ?? () => context.go('/player/${channel.id}'),
      semanticLabel: 'Play ${channel.name}',
      child: SizedBox(
        width: width,
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
                clipBehavior: Clip.antiAlias,
                child: _Logo(url: channel.logoUrl, name: channel.name),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    programme == null ? (channel.group ?? '') : programme.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (isFavourite)
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: AppColors.cyan,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final logoUrl = url;
    if (logoUrl == null || logoUrl.isEmpty) {
      return Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.violet,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: logoUrl,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, _) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, _, _) => Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.violet,
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name
        .split(RegExp(r'[\s\-|]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.characters.take(2).toString();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

/// Compact list row with now/next info and favourite toggle.
class ChannelListTile extends ConsumerWidget {
  const ChannelListTile({super.key, required this.channel});

  final Channel channel;

  static final _time = DateFormat.Hm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritesProvider);
    final isFavourite = favourites.contains(channel.id);
    final now = ref.watch(currentProgrammeProvider(channel));
    final next = now == null
        ? null
        : (ref
              .watch(epgIndexProvider)
              .valueOrNull
              ?.upcomingForChannel(channel, limit: 20)
              .firstWhere(
                (p) => p.start.isAfter(now.start),
                orElse: () => now,
              ));

    return ListTile(
      onTap: () => context.go('/player/${channel.id}'),
      leading: SizedBox(
        width: 56,
        height: 40,
        child: _Logo(url: channel.logoUrl, name: channel.name),
      ),
      title: Text(channel.name, overflow: TextOverflow.ellipsis),
      subtitle: now == null
          ? Text(channel.group ?? '—')
          : Text(
              '${now.title}  ·  ${_time.format(now.start)}–${_time.format(now.stop)}'
              '${next != null && next != now ? '\nNext: ${next.title}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: IconButton(
        icon: Icon(
          isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
          color: isFavourite ? AppColors.cyan : AppColors.textSecondary,
        ),
        tooltip: isFavourite ? 'Remove from favourites' : 'Add to favourites',
        onPressed: () =>
            ref.read(favouritesProvider.notifier).toggle(channel.id),
      ),
    );
  }
}
