class AppLocation {
  final int id;
  final String name;
  final String description;
  final DateTime createdAt;

  AppLocation({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
  });

  factory AppLocation.fromJson(Map<String, dynamic> json) {
    return AppLocation(
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
