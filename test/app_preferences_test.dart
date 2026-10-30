import 'dart:convert';

import 'package:adrian_tv/data/local/app_preferences.dart';
import 'package:adrian_tv/data/models/content_source.dart';
import 'package:adrian_tv/data/models/watch_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppPreferences> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return AppPreferences(await SharedPreferences.getInstance());
  }

  test('sources default to the bundled sources when unset', () async {
    final p = await prefs();
    expect(p.readSources(), [ContentSource.demo, ContentSource.publicFta]);
  });

  test('sources survive a write/read round-trip', () async {
    final p = await prefs();
    final sources = [
      ContentSource.demo,
      const ContentSource(
        id: 'x',
        name: 'My provider',
        type: SourceType.remoteM3u,
        url: 'https://example.com/pl.m3u',
        enabled: false,
      ),
    ];
    await p.writeSources(sources);
    expect(p.readSources(), sources);
  });

  test('corrupt source JSON falls back to the bundled sources', () async {
    SharedPreferences.setMockInitialValues({'content_sources_v1': '{not json'});
    final p = AppPreferences(await SharedPreferences.getInstance());
    expect(p.readSources(), [ContentSource.demo, ContentSource.publicFta]);
  });

  test('favourites persist as a set of ids', () async {
    final p = await prefs();
    await p.writeFavourites({'a', 'b'});
    expect(p.readFavourites(), {'a', 'b'});
  });

  test('history round-trips through JSON', () async {
    final p = await prefs();
    final entries = [
      WatchProgress(
        channelId: 'c1',
        channelName: 'Channel 1',
        watchedAt: DateTime(2026, 10, 28, 20),
        positionMs: 1000,
        durationMs: 5000,
      ),
    ];
    await p.writeHistory(entries);
    final read = p.readHistory();
    expect(read, entries);
    expect(jsonEncode(read.first.toJson()), contains('c1'));
  });
}
