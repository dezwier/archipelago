class User {
  final int id;
  final String username;
  final String email;
  final String langNative;
  final String? langLearning;
  final String createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.langNative,
    this.langLearning,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      langNative: json['lang_native'] as String,
      langLearning: json['lang_learning'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'lang_native': langNative,
      'lang_learning': langLearning,
      'created_at': createdAt,
    };
  }
}

