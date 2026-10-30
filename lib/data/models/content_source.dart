import 'package:equatable/equatable.dart';

/// Where a channel list comes from.
enum SourceType {
  /// Bundled, clearly-labelled demo playlist for first-run experience.
  demo,

  /// Bundled, always-shipped playlist of legally-public free-to-air channels.
  bundled,

  /// Remote M3U/M3U8 playlist fetched over HTTP(S).
  remoteM3u,

  /// Local file path chosen by the user.
  localM3u,

  /// Xtream Codes API provider (username/password in secure storage).
  xtream,
}

/// A user-configured content source.
///
/// Only non-secret metadata is persisted in plain preferences; any future
/// credential-bearing source types (e.g. Xtream) must store secrets in
/// flutter_secure_storage instead.
class ContentSource extends Equatable {
  const ContentSource({
    required this.id,
    required this.name,
    required this.type,
    this.url,
    this.enabled = true,
    this.epgUrl,
  });

  static const demoId = 'demo-bundled';
  static const publicFtaId = 'public-free-to-air';

  static ContentSource get demo => const ContentSource(
    id: demoId,
    name: 'ADRIAN TV Demo Streams',
    type: SourceType.demo,
    url: 'assets/demo/demo_channels.m3u',
    epgUrl: 'assets/demo/demo_epg.xml',
  );

  /// Live channels the rights-holders publish for free public viewing
  /// (DW, France 24, NASA TV). Ships enabled so the app has real content.
  static ContentSource get publicFta => const ContentSource(
    id: publicFtaId,
    name: 'Public Free-to-Air',
    type: SourceType.bundled,
    url: 'assets/sources/public_free_to_air.m3u',
  );

  /// Sources shipped with the app: always available, can be toggled but not
  /// permanently removed.
  static const builtInIds = {demoId, publicFtaId};

  final String id;
  final String name;
  final SourceType type;

  /// Playlist URL for remote sources, asset path for demo/bundled, file path
  /// for local.
  final String? url;
  final bool enabled;

  /// Optional XMLTV guide URL belonging to this source.
  final String? epgUrl;

  bool get isDemo => type == SourceType.demo;

  /// Loads its playlist from a bundled Flutter asset rather than the network.
  bool get usesAssetPath =>
      type == SourceType.demo || type == SourceType.bundled;

  bool get isBuiltIn => builtInIds.contains(id);

  /// Source types whose data must not be written to the on-disk playlist
  /// cache (stream URLs embed credentials).
  bool get isSensitive => type == SourceType.xtream;

  ContentSource copyWith({
    bool? enabled,
    String? name,
    String? url,
    String? epgUrl,
  }) => ContentSource(
    id: id,
    name: name ?? this.name,
    type: type,
    url: url ?? this.url,
    enabled: enabled ?? this.enabled,
    epgUrl: epgUrl ?? this.epgUrl,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'url': url,
    'enabled': enabled,
    'epgUrl': epgUrl,
  };

  factory ContentSource.fromJson(Map<String, dynamic> json) => ContentSource(
    id: json['id'] as String,
    name: json['name'] as String,
    type: SourceType.values.byName(json['type'] as String),
    url: json['url'] as String?,
    enabled: json['enabled'] as bool? ?? true,
    epgUrl: json['epgUrl'] as String?,
  );

  @override
  List<Object?> get props => [id, name, type, url, enabled, epgUrl];
}
