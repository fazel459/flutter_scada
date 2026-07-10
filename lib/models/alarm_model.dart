import 'enums.dart';

class AlarmLog {
  final int? id;
  final String? pageId;
  final String widgetId;
  final String? widgetLabel;
  final String alarmType;
  final double? value;
  final double? threshold;
  final String? message;
  final bool acknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime createdAt;

  const AlarmLog({
    this.id,
    this.pageId,
    required this.widgetId,
    this.widgetLabel,
    required this.alarmType,
    this.value,
    this.threshold,
    this.message,
    this.acknowledged = false,
    this.acknowledgedBy,
    this.acknowledgedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageId': pageId,
        'widgetId': widgetId,
        'widgetLabel': widgetLabel,
        'alarmType': alarmType,
        'value': value,
        'threshold': threshold,
        'message': message,
        'acknowledged': acknowledged,
        'acknowledgedBy': acknowledgedBy,
        'acknowledgedAt': acknowledgedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  AlarmLog copyWith({bool? acknowledged, String? acknowledgedBy}) {
    return AlarmLog(
      id: id,
      pageId: pageId,
      widgetId: widgetId,
      widgetLabel: widgetLabel,
      alarmType: alarmType,
      value: value,
      threshold: threshold,
      message: message,
      acknowledged: acknowledged ?? this.acknowledged,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt,
      createdAt: createdAt,
    );
  }

  factory AlarmLog.fromJson(Map<String, dynamic> json) => AlarmLog(
        id: json['id'],
        pageId: json['pageId'],
        widgetId: json['widgetId'],
        widgetLabel: json['widgetLabel'],
        alarmType: json['alarmType'],
        value: json['value']?.toDouble(),
        threshold: json['threshold']?.toDouble(),
        message: json['message'],
        acknowledged: json['acknowledged'] ?? false,
        acknowledgedBy: json['acknowledgedBy'],
        acknowledgedAt: json['acknowledgedAt'] != null
            ? DateTime.parse(json['acknowledgedAt'])
            : null,
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class AlarmNotification {
  final String widgetId;
  final String widgetLabel;
  final AlarmType alarmType;
  final double value;
  final double threshold;

  const AlarmNotification({
    required this.widgetId,
    required this.widgetLabel,
    required this.alarmType,
    required this.value,
    required this.threshold,
  });
}
