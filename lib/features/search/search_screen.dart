import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../channels/widgets/channel_card.dart';
import '../providers/app_providers.dart';

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
    final q = _query.trim().toLowerCase();

    final results = q.isEmpty
        ? const []
        : channels
              .where(
                (c) =>
                    c.name.toLowerCase().contains(q) ||
                    (c.group?.toLowerCase().contains(q) ?? false) ||
                    (c.tvgName?.toLowerCase().contains(q) ?? false),
              )
              .toList();

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
                    'Search across all your enabled sources.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : results.isEmpty
          ? Center(
              child: Text(
                'No channels match "$_query".',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.86,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: results.length,
              itemBuilder: (context, i) =>
                  ChannelCard(channel: results[i], width: double.infinity),
            ),
    );
  }
}
