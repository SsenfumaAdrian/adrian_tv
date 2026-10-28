import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/channel.dart';
import '../providers/app_providers.dart';
import 'widgets/channel_card.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  const ChannelsScreen({super.key});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  String? _group;
  bool _favouritesOnly = false;
  String _query = '';
  bool _grid = true;

  List<Channel> _filter(List<Channel> channels, Set<String> favourites) {
    final q = _query.trim().toLowerCase();
    return channels.where((c) {
      if (_favouritesOnly && !favourites.contains(c.id)) return false;
      if (_group != null && (c.group ?? 'Uncategorised') != _group) {
        return false;
      }
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.group?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(channelsProvider);
    final groups = ref.watch(channelGroupsProvider);
    final favourites = ref.watch(favouritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          IconButton(
            tooltip: _favouritesOnly
                ? 'Show all channels'
                : 'Show favourites only',
            icon: Icon(
              _favouritesOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _favouritesOnly ? AppColors.cyan : null,
            ),
            onPressed: () => setState(() => _favouritesOnly = !_favouritesOnly),
          ),
          IconButton(
            tooltip: _grid ? 'Switch to list' : 'Switch to grid',
            icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _MessageState(
          icon: Icons.cloud_off,
          title: 'Could not load channels',
          message: '$e',
          action: TextButton(
            onPressed: () => ref.invalidate(channelsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return _MessageState(
              icon: Icons.live_tv,
              title: 'No channels yet',
              message:
                  'Add a playlist in Settings to start watching, '
                  'or enable the bundled demo source.',
              action: null,
            );
          }
          final channels = _filter(all, favourites);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter channels…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _group == null,
                        onSelected: (_) => setState(() => _group = null),
                      ),
                    ),
                    for (final g in groups)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(g),
                          selected: _group == g,
                          onSelected: (sel) =>
                              setState(() => _group = sel ? g : null),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: channels.isEmpty
                    ? const _MessageState(
                        icon: Icons.search_off,
                        title: 'No matches',
                        message: 'Try a different filter or group.',
                      )
                    : _grid
                    ? _ChannelGrid(channels: channels)
                    : ListView.builder(
                        itemCount: channels.length,
                        itemBuilder: (context, i) =>
                            ChannelListTile(channel: channels[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({required this.channels});

  final List<Channel> channels;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = switch (width) {
      >= 1600 => 6,
      >= 1200 => 5,
      >= 900 => 4,
      >= 600 => 3,
      _ => 2,
    };
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.86,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: channels.length,
      itemBuilder: (context, i) =>
          ChannelCard(channel: channels[i], width: double.infinity),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

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
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
