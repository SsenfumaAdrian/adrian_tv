import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/channel.dart';
import '../../data/models/programme.dart';
import '../../data/models/watch_progress.dart';
import '../providers/app_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  Channel? _channel;
  String? _error;
  bool _controlsVisible = true;
  bool _opened = false;
  Timer? _hideTimer;

  static final _time = DateFormat.Hm();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _player.stream.error.listen((message) {
      if (message.isNotEmpty && mounted) {
        setState(() => _error = message);
      }
    });
    _player.stream.playing.listen((playing) {
      if (playing && mounted) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WakelockPlus.disable();
    _player.dispose();
    super.dispose();
  }

  void _retry() {
    final channel = _channel;
    if (channel == null) return;
    _opened = false;
    setState(() => _error = null);
    _open(channel);
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);

    return channelsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'Channel list unavailable: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (channels) {
        final channel = channels
            .where((c) => c.id == widget.channelId)
            .firstOrNull;
        if (channel == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text(
                'This channel is no longer available. Refresh your sources '
                'in Settings.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        _open(channel);
        return _playerView(channel);
      },
    );
  }

  void _open(Channel channel) {
    if (_opened) return;
    // Defer side effects out of the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _opened) return;
      _opened = true;
      _channel = channel;
      setState(() => _error = null);
      _player.open(Media(channel.streamUrl), play: true);
      ref
          .read(historyProvider.notifier)
          .record(
            WatchProgress(
              channelId: channel.id,
              channelName: channel.name,
              watchedAt: DateTime.now(),
              logoUrl: channel.logoUrl,
            ),
          );
      _scheduleHide();
    });
  }

  Widget _playerView(Channel channel) {
    final programme = ref.watch(currentProgrammeProvider(channel));
    final upcoming =
        ref
            .watch(epgIndexProvider)
            .valueOrNull
            ?.upcoming(channel.tvgId, limit: 5) ??
        const [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        onPopInvokedWithResult: (_, _) => _saveProgress(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: (_) => _toggleControls(),
              child: Video(controller: _controller, controls: NoVideoControls),
            ),
            if (_error != null) _errorOverlay(),
            if (_controlsVisible && _error == null)
              _overlay(channel, programme, upcoming),
          ],
        ),
      ),
    );
  }

  void _saveProgress() {
    final channel = _channel;
    if (channel == null) return;
    ref
        .read(historyProvider.notifier)
        .record(
          WatchProgress(
            channelId: channel.id,
            channelName: channel.name,
            watchedAt: DateTime.now(),
            positionMs: _player.state.position.inMilliseconds,
            durationMs: _player.state.duration.inMilliseconds,
            logoUrl: channel.logoUrl,
          ),
        );
  }

  Widget _errorOverlay() {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_disabled, size: 52, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              'Playback failed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry stream'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlay(
    Channel channel,
    Programme? programme,
    List<Programme> upcoming,
  ) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _controlsVisible ? 1 : 0,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                _saveProgress();
                                context.pop();
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    channel.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (programme != null)
                                    Text(
                                      '${programme.title} · '
                                      '${_time.format(programme.start)}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (channel.isHls)
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: _LiveBadge(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                      child: StreamBuilder(
                        stream: _player.stream.playing,
                        builder: (context, playingSnap) => StreamBuilder(
                          stream: _player.stream.position,
                          builder: (context, posSnap) {
                            final duration = _player.state.duration;
                            final position = posSnap.data ?? Duration.zero;
                            final finite =
                                duration > Duration.zero &&
                                duration < const Duration(days: 365);
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (finite)
                                  _ProgressBar(
                                    position: position,
                                    duration: duration,
                                    onSeek: (target) => _player.seek(target),
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      iconSize: 40,
                                      icon: Icon(
                                        playingSnap.data ?? true
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                      onPressed: () => _player.playOrPause(),
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      tooltip: 'Reload stream',
                                      icon: const Icon(Icons.refresh_rounded),
                                      onPressed: _retry,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (upcoming.isNotEmpty && _controlsVisible)
            Positioned(
              right: 16,
              top: 80,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UP NEXT',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final p in upcoming.take(4))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${_time.format(p.start)}  ${p.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final fraction = duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTapDown: (d) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final dx = d.localPosition.dx / box.size.width;
          onSeek(duration * dx.clamp(0.0, 1.0));
        },
        child: SliderTheme(
          data: const SliderThemeData(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: fraction,
            onChanged: (v) => onSeek(duration * v),
          ),
        ),
      ),
    );
  }
}
