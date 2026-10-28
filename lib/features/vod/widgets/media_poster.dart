import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tv_focusable.dart';
import '../../../data/models/media_item.dart';

/// Poster card (2:3) for movies and series.
class MediaPoster extends StatelessWidget {
  const MediaPoster({super.key, required this.item, this.width = 120});

  final MediaItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onTap: () => _open(context),
      semanticLabel: item.kind == MediaKind.movie
          ? 'Play ${item.title}'
          : 'Open ${item.title}',
      borderRadius: 12,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceBright,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                clipBehavior: Clip.antiAlias,
                child: _Cover(url: item.coverUrl, title: item.title),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (item.kind == MediaKind.series) {
      context.go(AppRoute.series(item.sourceId, item.providerId!));
    } else {
      context.go(AppRoute.player(item.id));
    }
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final coverUrl = url;
    if (coverUrl == null || coverUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.movie_outlined,
          size: 36,
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: coverUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, _) => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, _, _) => const Center(
        child: Icon(
          Icons.movie_outlined,
          size: 36,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
