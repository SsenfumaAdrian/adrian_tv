import 'package:equatable/equatable.dart';

/// One TV listing entry from an XMLTV guide.
class Programme extends Equatable {
  const Programme({
    required this.channelRef,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
    this.category,
  });

  /// The XMLTV channel id this programme belongs to (matched against
  /// [Channel.tvgId]).
  final String channelRef;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;
  final String? category;

  Duration get duration => stop.difference(start);

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(stop);

  /// 0..1 progress through the programme at [moment].
  double progressAt(DateTime moment) {
    final total = duration.inSeconds;
    if (total <= 0) return 1;
    final done = moment.difference(start).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    channelRef,
    title,
    start,
    stop,
    description,
    category,
  ];
}
