class Topic {
  final int id;
  final String name;
  final String? description;
  final String? icon;
  final DateTime? createdAt;

  Topic({required this.id, required this.name, this.description, this.icon, this.createdAt});

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

