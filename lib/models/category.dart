class AppCategory {
  final int id;
  final String name;
  final String description;
  final DateTime createdAt;

  AppCategory({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
  });

  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}
