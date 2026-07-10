import 'widget_model.dart';

class ScadaPage {
  final String id;
  String title;
  String description;
  String backgroundColor;
  String? backgroundImage;
  double bgOpacity;
  double width;
  double height;
  List<ScadaWidget> widgets;
  String theme;
  bool isPublished;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScadaPage({
    required this.id,
    required this.title,
    this.description = '',
    this.backgroundColor = '#1A1A2E',
    this.backgroundImage,
    this.bgOpacity = 1.0,
    this.width = 1920,
    this.height = 1080,
    this.widgets = const [],
    this.theme = 'dark',
    this.isPublished = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'backgroundColor': backgroundColor,
        'backgroundImage': backgroundImage,
        'bgOpacity': bgOpacity,
        'width': width,
        'height': height,
        'widgets': widgets.map((w) => w.toJson()).toList(),
        'theme': theme,
        'isPublished': isPublished,
        'createdBy': createdBy,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toSaveJson() => {
        'title': title,
        'description': description,
        'backgroundColor': backgroundColor,
        'backgroundImage': backgroundImage,
        'bgOpacity': bgOpacity,
        'width': width,
        'height': height,
        'widgets': widgets.map((w) => w.toJson()).toList(),
        'theme': theme,
        'isPublished': isPublished,
      };

  ScadaPage copyWith({
    String? title,
    String? description,
    String? backgroundColor,
    String? backgroundImage,
    double? bgOpacity,
    double? width,
    double? height,
    List<ScadaWidget>? widgets,
    String? theme,
    bool? isPublished,
  }) {
    return ScadaPage(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      bgOpacity: bgOpacity ?? this.bgOpacity,
      width: width ?? this.width,
      height: height ?? this.height,
      widgets: widgets ?? this.widgets,
      theme: theme ?? this.theme,
      isPublished: isPublished ?? this.isPublished,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory ScadaPage.fromJson(Map<String, dynamic> json) => ScadaPage(
        id: json['id'],
        title: json['title'] ?? 'Untitled',
        description: json['description'] ?? '',
        backgroundColor: json['backgroundColor'] ?? '#1A1A2E',
        backgroundImage: json['backgroundImage'],
        bgOpacity: (json['bgOpacity'] ?? 1.0).toDouble(),
        width: (json['width'] ?? 1920).toDouble(),
        height: (json['height'] ?? 1080).toDouble(),
        widgets: json['widgets'] != null
            ? (json['widgets'] as List<dynamic>)
                .map((w) => ScadaWidget.fromJson(w))
                .toList()
            : [],
        theme: json['theme'] ?? 'dark',
        isPublished: json['isPublished'] ?? false,
        createdBy: json['createdBy'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
      );
}

class PageSummary {
  final String id;
  final String title;
  final String description;
  final String backgroundColor;
  final String? thumbnailUrl;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PageSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.backgroundColor,
    this.thumbnailUrl,
    required this.isPublished,
    this.createdAt,
    this.updatedAt,
  });

  factory PageSummary.fromJson(Map<String, dynamic> json) => PageSummary(
        id: json['id'],
        title: json['title'] ?? 'Untitled',
        description: json['description'] ?? '',
        backgroundColor: json['backgroundColor'] ?? '#1A1A2E',
        thumbnailUrl: json['thumbnailUrl'],
        isPublished: json['isPublished'] ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
      );
}
