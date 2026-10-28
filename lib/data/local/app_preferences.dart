import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_source.dart';
import '../models/watch_progress.dart';

/// Plain-preferences persistence for non-sensitive app state.
///
/// Sensitive provider credentials must never be stored here — they belong in
/// flutter_secure_storage (see `lib/data/local/secure_store.dart`).
class AppPreferences {
  const AppPreferences(this._prefs);

  static const _sourcesKey = 'content_sources_v1';
  static const _favouritesKey = 'favourite_channel_ids_v1';
  static const _historyKey = 'watch_history_v1';
  static const _onboardedKey = 'onboarding_complete_v1';

  final SharedPreferences _prefs;

  List<ContentSource> readSources() {
    final raw = _prefs.getString(_sourcesKey);
    if (raw == null) return [ContentSource.demo];
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(ContentSource.fromJson)
          .toList();
      if (list.isEmpty) return [ContentSource.demo];
      return list;
    } on FormatException {
      return [ContentSource.demo];
    }
  }

  Future<void> writeSources(List<ContentSource> sources) =>
      _prefs.setString(_sourcesKey, jsonEncode(sources));

  Set<String> readFavourites() =>
      (_prefs.getStringList(_favouritesKey) ?? const []).toSet();

  Future<void> writeFavourites(Set<String> ids) =>
      _prefs.setStringList(_favouritesKey, ids.toList());

  List<WatchProgress> readHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(WatchProgress.fromJson)
          .toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> writeHistory(List<WatchProgress> entries) =>
      _prefs.setString(_historyKey, jsonEncode(entries));

  bool get onboardingComplete => _prefs.getBool(_onboardedKey) ?? false;

  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(_onboardedKey, value);
}
