/// مدل دستورالعمل تولید (Recipe)
class Recipe {
  final String id;
  String name;
  String description;
  String product;
  List<RecipeStep> steps;
  Map<String, double> parameters; // tag_name → setpoint
  final String? createdBy;
  final DateTime? createdAt;

  Recipe({
    required this.id,
    required this.name,
    this.description = '',
    this.product = '',
    List<RecipeStep>? steps,
    Map<String, double>? parameters,
    this.createdBy,
    this.createdAt,
  }) : steps = steps ?? [],
       parameters = parameters ?? {};

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description, 'product': product,
    'steps': steps.map((s) => s.toJson()).toList(),
    'parameters': parameters,
    'createdBy': createdBy, 'createdAt': createdAt?.toIso8601String(),
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'], name: json['name'] ?? '',
    description: json['description'] ?? '', product: json['product'] ?? '',
    steps: (json['steps'] as List?)?.map((s) => RecipeStep.fromJson(s)).toList(),
    parameters: json['parameters'] != null ? Map<String, double>.from(
      (json['parameters'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
    ) : null,
    createdBy: json['createdBy'],
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
  );
}

class RecipeStep {
  String name;
  String description;
  int durationSeconds;
  Map<String, double> setpoints; // tag_name → value

  RecipeStep({
    required this.name,
    this.description = '',
    this.durationSeconds = 60,
    Map<String, double>? setpoints,
  }) : setpoints = setpoints ?? {};

  Map<String, dynamic> toJson() => {
    'name': name, 'description': description,
    'durationSeconds': durationSeconds, 'setpoints': setpoints,
  };

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    name: json['name'] ?? '', description: json['description'] ?? '',
    durationSeconds: json['durationSeconds'] ?? 60,
    setpoints: json['setpoints'] != null ? Map<String, double>.from(
      (json['setpoints'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
    ) : null,
  );
}
