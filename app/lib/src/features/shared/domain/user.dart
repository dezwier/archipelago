class User {
  final int id;
  final String username;
  final String email;
  final String langNative;
  final String? langLearning;
  final String createdAt;
  final String? fullName;
  final String? imageUrl;
  final int leitnerMaxBins;
  final String leitnerAlgorithm;
  final int leitnerIntervalStart;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.langNative,
    this.langLearning,
    required this.createdAt,
    this.fullName,
    this.imageUrl,
    this.leitnerMaxBins = 7,
    this.leitnerAlgorithm = 'fibonacci',
    this.leitnerIntervalStart = 23,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      langNative: json['lang_native'] as String,
      langLearning: json['lang_learning'] as String?,
      createdAt: json['created_at'] as String,
      fullName: json['full_name'] as String?,
      imageUrl: json['image_url'] as String?,
      leitnerMaxBins: json['leitner_max_bins'] as int? ?? 7,
      leitnerAlgorithm: json['leitner_algorithm'] as String? ?? 'fibonacci',
      leitnerIntervalStart: json['leitner_interval_start'] as int? ?? 23,
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
      'full_name': fullName,
      'image_url': imageUrl,
      'leitner_max_bins': leitnerMaxBins,
      'leitner_algorithm': leitnerAlgorithm,
      'leitner_interval_start': leitnerIntervalStart,
    };
  }
}

