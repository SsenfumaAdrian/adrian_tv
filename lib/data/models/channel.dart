import 'package:equatable/equatable.dart';

/// A playable live channel produced by a content source adapter.
class Channel extends Equatable {
  const Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.sourceId,
    this.logoUrl,
    this.group,
    this.tvgId,
    this.tvgName,
    this.order,
  });

  /// Stable identity: derived from source + playlist position/name so
  /// favourites and history survive re-imports of the same playlist.
  static String buildId({
    required String sourceId,
    required String name,
    String? tvgId,
    int? index,
  }) {
    final key = tvgId != null && tvgId.isNotEmpty
        ? '$sourceId#$tvgId'
        : '$sourceId#$name#${index ?? 0}';
    return key;
  }

  final String id;
  final String name;
  final String streamUrl;
  final String sourceId;
  final String? logoUrl;
  final String? group;
  final String? tvgId;
  final String? tvgName;

  /// Playlist `tvg-chno` ordering hint, if present.
  final int? order;

  bool get isHls => streamUrl.contains('.m3u8') || streamUrl.contains('m3u8?');

  Channel copyWith({String? group, String? logoUrl}) => Channel(
    id: id,
    name: name,
    streamUrl: streamUrl,
    sourceId: sourceId,
    logoUrl: logoUrl ?? this.logoUrl,
    group: group ?? this.group,
    tvgId: tvgId,
    tvgName: tvgName,
    order: order,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'streamUrl': streamUrl,
    'sourceId': sourceId,
    'logoUrl': logoUrl,
    'group': group,
    'tvgId': tvgId,
    'tvgName': tvgName,
    'order': order,
  };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    id: json['id'] as String,
    name: json['name'] as String,
    streamUrl: json['streamUrl'] as String,
    sourceId: json['sourceId'] as String,
    logoUrl: json['logoUrl'] as String?,
    group: json['group'] as String?,
    tvgId: json['tvgId'] as String?,
    tvgName: json['tvgName'] as String?,
    order: (json['order'] as num?)?.toInt(),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    streamUrl,
    sourceId,
    logoUrl,
    group,
    tvgId,
    tvgName,
    order,
  ];
}
