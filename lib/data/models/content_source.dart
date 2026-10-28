import 'package:equatable/equatable.dart';

/// Where a channel list comes from.
enum SourceType {
  /// Bundled, clearly-labelled demo playlist for first-run experience.
  demo,

  /// Remote M3U/M3U8 playlist fetched over HTTP(S).
  remoteM3u,

  /// Local file path chosen by the user.
  localM3u,
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

  static ContentSource get demo => const ContentSource(
    id: demoId,
    name: 'ADRIAN TV Demo Streams',
    type: SourceType.demo,
    url: 'assets/demo/demo_channels.m3u',
    epgUrl: 'assets/demo/demo_epg.xml',
  );

  final String id;
  final String name;
  final SourceType type;

  /// Playlist URL for remote sources, asset path for demo, file path for local.
  final String? url;
  final bool enabled;

  /// Optional XMLTV guide URL belonging to this source.
  final String? epgUrl;

  bool get isDemo => type == SourceType.demo;

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
