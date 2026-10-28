import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/content_source.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    final channelsCount = ref.watch(channelsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Content sources',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'ADRIAN TV only plays playlists and guides you configure yourself. '
            'Only add sources you are authorised to use.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final source in sources)
                  ListTile(
                    leading: Icon(
                      source.isDemo
                          ? Icons.science_outlined
                          : Icons.storage_outlined,
                      color: source.enabled
                          ? AppColors.cyan
                          : AppColors.textSecondary,
                    ),
                    title: Text(source.name),
                    subtitle: Text(
                      source.isDemo
                          ? 'Bundled demo streams (not real channels)'
                          : source.url ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: source.enabled,
                          onChanged: (_) => ref
                              .read(sourcesProvider.notifier)
                              .toggle(source.id),
                        ),
                        if (!source.isDemo)
                          IconButton(
                            tooltip: 'Remove source',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.danger,
                            ),
                            onPressed: () => ref
                                .read(sourcesProvider.notifier)
                                .remove(source.id),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _showSourceEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add M3U playlist source'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reload all playlists'),
                  subtitle: Text('$channelsCount channels currently loaded'),
                  onTap: () => ref.invalidate(channelsProvider),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Clear watch history'),
                  onTap: () async {
                    await ref.read(historyProvider.notifier).clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('History cleared')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_border),
                  title: const Text('Clear favourites'),
                  onTap: () async {
                    await ref.read(favouritesProvider.notifier).clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Favourites cleared')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'ADRIAN TV is a media player and content-discovery '
                'application. It does not host, bundle or provide any '
                'television channels, movies or series itself, and does '
                'not guarantee access to any content. Playback depends on '
                'the sources you configure and their availability.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showSourceEditor(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final epgController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add content source'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Give the source a name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Playlist URL (http/https M3U)',
                  ),
                  validator: (v) {
                    final uri = Uri.tryParse(v ?? '');
                    return (uri == null ||
                            !uri.hasScheme ||
                            !['http', 'https'].contains(uri.scheme))
                        ? 'Enter a valid http(s) playlist URL'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: epgController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'EPG URL (XMLTV, optional)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final uri = Uri.tryParse(v);
                    return (uri == null ||
                            !uri.hasScheme ||
                            !['http', 'https'].contains(uri.scheme))
                        ? 'Enter a valid http(s) URL or leave empty'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final source = ContentSource(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                type: SourceType.remoteM3u,
                url: urlController.text.trim(),
                epgUrl: epgController.text.trim().isEmpty
                    ? null
                    : epgController.text.trim(),
              );
              await ref.read(sourcesProvider.notifier).add(source);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Add source'),
          ),
        ],
      ),
    );
  }
}
