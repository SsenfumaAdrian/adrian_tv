import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../data/models/channel.dart';
import '../../data/models/programme.dart';
import '../../data/parsers/xmltv_parser.dart';
import '../providers/app_providers.dart';

/// Electronic programme guide: one row per channel with a live progress bar
/// for the current programme and the next few entries.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  static final _time = DateFormat.Hm();
  static final _day = DateFormat('EEEE d MMM');

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final epgAsync = ref.watch(epgIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TV Guide'),
            Text(
              '${_day.format(_now)} · ${_time.format(_now)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Could not load channels: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (channels) {
          final index = epgAsync.valueOrNull;
          if (channels.isEmpty) {
            return const Center(
              child: Text(
                'No channels to guide.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: channels.length,
            itemBuilder: (context, i) =>
                _GuideRow(channel: channels[i], index: index, now: _now),
          );
        },
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.index,
    required this.now,
  });

  final Channel channel;
  final EpgIndex? index;
  final DateTime now;

  static final _time = DateFormat.Hm();

  @override
  Widget build(BuildContext context) {
    final programmes = index?.programmesForChannel(channel) ?? const [];
    final current = index?.nowFor(channel, now);
    final upcoming = programmes
        .where((p) => !p.stop.isBefore(now) && p != current)
        .take(3)
        .toList();

    return TvFocusable(
      onTap: () => context.go('/player/${channel.id}'),
      semanticLabel: 'Play ${channel.name}',
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    channel.group ?? '',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: current == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        upcoming.isEmpty
                            ? 'No programme data'
                            : 'Next: ${upcoming.first.title}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _NowBar(programme: current, now: now),
                        const SizedBox(height: 6),
                        for (final p in upcoming)
                          Text(
                            '${_time.format(p.start)}  ${p.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
            ),
            const Icon(
              Icons.play_circle_outline,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NowBar extends StatelessWidget {
  const _NowBar({required this.programme, required this.now});

  final Programme programme;
  final DateTime now;

  static final _time = DateFormat.Hm();

  @override
  Widget build(BuildContext context) {
    final progress = programme.progressAt(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_time.format(programme.start)}–'
          '${_time.format(programme.stop)}  ${programme.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.surfaceBright,
            color: AppColors.cyan,
          ),
        ),
      ],
    );
  }
}
