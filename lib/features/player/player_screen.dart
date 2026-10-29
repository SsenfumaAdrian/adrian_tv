import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/programme.dart';
import '../../data/models/watch_progress.dart';
import '../providers/app_providers.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.targetId});

  /// Channel id, `vod:<src>:<id>` movie id or `ep:<src>:<series>:<id>`.
  final String targetId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  PlaybackTarget? _target;
  String? _error;
  String? _failoverNotice;
  bool _controlsVisible = true;
  bool _opened = false;
  Timer? _hideTimer;
  List<String> _candidates = const [];
  int _candidateIndex = 0;
  DateTime? _openedAt;
  DateTime? _bufferingSince;
  bool _ttffRecorded = false;

  static final _time = DateFormat.Hm();

  String get _currentUrl =>
      _candidateIndex < _candidates.length ? _candidates[_candidateIndex] : '';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _player.stream.error.listen(_onPlayerError);
    _player.stream.playing.listen((playing) {
      if (playing && mounted) {
        setState(() {
          _error = null;
          _failoverNotice = null;
        });
        _recordTimeToFirstFrame();
      }
    });
    _player.stream.buffering.listen((buffering) {
      if (buffering) {
        _bufferingSince = DateTime.now();
      } else if (_bufferingSince != null) {
        final stalledFor = DateTime.now().difference(_bufferingSince!);
        _bufferingSince = null;
        if (stalledFor >= const Duration(milliseconds: 1500)) {
          ref.read(streamHealthProvider).recordStall(_currentUrl);
        }
      }
    });
  }

  void _recordTimeToFirstFrame() {
    if (_ttffRecorded || _openedAt == null) return;
    _ttffRecorded = true;
    ref
        .read(streamHealthProvider)
        .recordTimeToFirstFrame(
          _currentUrl,
          DateTime.now().difference(_openedAt!).inMilliseconds,
        );
  }

  /// Walk same-name mirror URLs before admitting defeat.
  void _onPlayerError(String message) {
    if (message.isEmpty || !mounted) return;
    if (_candidateIndex + 1 < _candidates.length) {
      ref.read(streamHealthProvider).recordStall(_currentUrl);
      _candidateIndex++;
      setState(() {
        _error = null;
        _failoverNotice =
            'Stream failed — switching to alternate '
            '${_candidateIndex + 1} of ${_candidates.length}…';
      });
      _player.open(Media(_candidates[_candidateIndex]), play: true);
      return;
    }
    setState(() => _error = message);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    WakelockPlus.disable();
    _player.dispose();
    super.dispose();
  }

  void _retry() {
    if (_target == null) return;
    _opened = false;
    setState(() {
      _error = null;
      _failoverNotice = null;
    });
    _open(_target!);
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
    final targetAsync = ref.watch(playbackTargetProvider(widget.targetId));

    return targetAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            'Playback is unavailable: $e',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (target) {
        if (target == null || target.candidates.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text(
                'This item is no longer available. Refresh your sources '
                'in Settings.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        _open(target);
        return _playerView(target);
      },
    );
  }

  void _open(PlaybackTarget target) {
    if (_opened) return;
    // Defer side effects out of the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _opened) return;
      _opened = true;
      _target = target;
      _candidates = target.candidates;
      _candidateIndex = 0;
      setState(() {
        _error = null;
        _failoverNotice = null;
      });
      _player.open(Media(_candidates.first), play: true);
      _openedAt = DateTime.now();
      _ttffRecorded = false;
      // Read the previous position before recording replaces the entry.
      final previous = target.channel == null
          ? ref
                .read(historyProvider)
                .where((e) => e.channelId == target.id)
                .firstOrNull
          : null;
      final resumeAt = previous?.positionMs;
      if (previous != null &&
          resumeAt != null &&
          resumeAt > 5000 &&
          !previous.isFinished) {
        late final StreamSubscription<Duration> durationSub;
        durationSub = _player.stream.duration.listen((d) {
          if (d > Duration.zero) {
            durationSub.cancel();
            _player.seek(Duration(milliseconds: resumeAt));
          }
        });
      }
      ref
          .read(historyProvider.notifier)
          .record(
            WatchProgress(
              channelId: target.id,
              channelName: target.title,
              watchedAt: DateTime.now(),
              logoUrl: target.logoUrl,
            ),
          );
      _scheduleHide();
    });
  }

  Widget _playerView(PlaybackTarget target) {
    final channel = target.channel;
    final programme = channel == null
        ? null
        : ref.watch(currentProgrammeProvider(channel));
    final upcoming = channel == null
        ? const <Programme>[]
        : ref
                  .watch(epgIndexProvider)
                  .valueOrNull
                  ?.upcomingForChannel(channel, limit: 5) ??
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
              _overlay(target, programme, upcoming),
          ],
        ),
      ),
    );
  }

  void _showAudioTrackSheet() {
    _showTrackSheet(
      heading: 'Audio track',
      tracks: [
        for (final t in _player.state.tracks.audio)
          (id: t.id, title: t.title, language: t.language),
      ],
      currentId: _player.state.track.audio.id,
      onSelect: (id) {
        final track = _player.state.tracks.audio
            .where((t) => t.id == id)
            .firstOrNull;
        if (track != null) {
          _player.setAudioTrack(track);
        }
      },
    );
  }

  void _showSubtitleTrackSheet() {
    _showTrackSheet(
      heading: 'Subtitles',
      tracks: [
        for (final t in _player.state.tracks.subtitle)
          (id: t.id, title: t.title, language: t.language),
      ],
      currentId: _player.state.track.subtitle.id,
      onSelect: (id) {
        final track = _player.state.tracks.subtitle
            .where((t) => t.id == id)
            .firstOrNull;
        if (track != null) {
          _player.setSubtitleTrack(track);
        }
      },
    );
  }

  void _showTrackSheet({
    required String heading,
    required List<({String id, String? title, String? language})> tracks,
    required String currentId,
    required void Function(String id) onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                heading,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: RadioGroup<String>(
                groupValue: currentId,
                onChanged: (value) {
                  Navigator.of(sheetContext).pop();
                  if (value != null) onSelect(value);
                },
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final track in tracks)
                      RadioListTile<String>(
                        value: track.id,
                        title: Text(_trackLabel(track)),
                      ),
                    if (tracks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'This stream has no selectable ${heading.toLowerCase()}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _trackLabel(
    ({String id, String? title, String? language}) track,
  ) => switch (track.id) {
    'auto' => 'Auto',
    'no' => 'Off',
    _ => [
      if (track.title != null && track.title!.isNotEmpty) track.title!,
      if (track.language != null && track.language!.isNotEmpty) track.language!,
      if ((track.title == null || track.title!.isEmpty) &&
          (track.language == null || track.language!.isEmpty))
        'Track ${track.id}',
    ].join(' · '),
  };

  void _saveProgress() {
    final target = _target;
    if (target == null) return;
    ref
        .read(historyProvider.notifier)
        .record(
          WatchProgress(
            channelId: target.id,
            channelName: target.title,
            watchedAt: DateTime.now(),
            positionMs: _player.state.position.inMilliseconds,
            durationMs: _player.state.duration.inMilliseconds,
            logoUrl: target.logoUrl,
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
    PlaybackTarget target,
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
                                    target.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_failoverNotice != null)
                                    Text(
                                      _failoverNotice!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.cyan,
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
                            if (target.channel?.isHls ?? false)
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
                                    const SizedBox(width: 16),
                                    IconButton(
                                      tooltip: 'Audio track',
                                      icon: const Icon(
                                        Icons.audiotrack_rounded,
                                      ),
                                      onPressed: _showAudioTrackSheet,
                                    ),
                                    const SizedBox(width: 16),
                                    IconButton(
                                      tooltip: 'Subtitles',
                                      icon: const Icon(
                                        Icons.closed_caption_rounded,
                                      ),
                                      onPressed: _showSubtitleTrackSheet,
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
