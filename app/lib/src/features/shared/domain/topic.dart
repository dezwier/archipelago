class Topic {
  final int id;
  final String name;
  final String? description;
  final String? icon;
  final int createdByUserId;
  final String visibility; // 'public' or 'private'
  final int liked;
  final DateTime? createdAt;

  Topic({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    required this.createdByUserId,
    this.visibility = 'private',
    this.liked = 0,
    this.createdAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      createdByUserId: json['created_by_user_id'] as int,
      visibility: json['visibility'] as String? ?? 'private',
      liked: json['liked'] as int? ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

