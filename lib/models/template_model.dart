import 'widget_model.dart';

/// مدل تمپلت ویجت - ترکیبی از چند ویجت
class WidgetTemplate {
  final String id;
  final String name;
  final String? description;
  final String icon;          // آیکون نمایشی
  final String createdBy;
  final DateTime createdAt;
  final double width;         // عرض کلی تمپلت
  final double height;        // ارتفاع کلی تمپلت
  final List<ScadaWidget> widgets;  // ویجت‌های داخل تمپلت (با مختصات نسبی)

  const WidgetTemplate({
    required this.id,
    required this.name,
    this.description,
    this.icon = '📦',
    required this.createdBy,
    required this.createdAt,
    required this.width,
    required this.height,
    required this.widgets,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'width': width,
    'height': height,
    'widgets': widgets.map((w) => w.toJson()).toList(),
  };

  factory WidgetTemplate.fromJson(Map<String, dynamic> json) => WidgetTemplate(
    id: json['id'],
    name: json['name'] ?? 'Template',
    description: json['description'],
    icon: json['icon'] ?? '📦',
    createdBy: json['createdBy'] ?? '',
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    width: (json['width'] ?? 200).toDouble(),
    height: (json['height'] ?? 200).toDouble(),
    widgets: json['widgets'] != null
        ? (json['widgets'] as List<dynamic>).map((w) => ScadaWidget.fromJson(w)).toList()
        : [],
  );
}
