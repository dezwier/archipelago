/// Statistics domain models for profile page.

class LanguageStat {
  final String languageCode;
  final int lemmaCount;
  final int exerciseCount;

  LanguageStat({
    required this.languageCode,
    required this.lemmaCount,
    required this.exerciseCount,
  });

  factory LanguageStat.fromJson(Map<String, dynamic> json) {
    return LanguageStat(
      languageCode: json['language_code'] as String,
      lemmaCount: json['lemma_count'] as int,
      exerciseCount: json['exercise_count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_code': languageCode,
      'lemma_count': lemmaCount,
      'exercise_count': exerciseCount,
    };
  }
}

class SummaryStats {
  final List<LanguageStat> languageStats;

  SummaryStats({
    required this.languageStats,
  });

  factory SummaryStats.fromJson(Map<String, dynamic> json) {
    return SummaryStats(
      languageStats: (json['language_stats'] as List<dynamic>)
          .map((item) => LanguageStat.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_stats': languageStats.map((stat) => stat.toJson()).toList(),
    };
  }
}

class LeitnerBinData {
  final int bin;
  final int count;

  LeitnerBinData({
    required this.bin,
    required this.count,
  });

  factory LeitnerBinData.fromJson(Map<String, dynamic> json) {
    return LeitnerBinData(
      bin: json['bin'] as int,
      count: json['count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bin': bin,
      'count': count,
    };
  }
}

class LeitnerDistribution {
  final String languageCode;
  final List<LeitnerBinData> distribution;

  LeitnerDistribution({
    required this.languageCode,
    required this.distribution,
  });

  factory LeitnerDistribution.fromJson(Map<String, dynamic> json) {
    return LeitnerDistribution(
      languageCode: json['language_code'] as String,
      distribution: (json['distribution'] as List<dynamic>)
          .map((item) => LeitnerBinData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_code': languageCode,
      'distribution': distribution.map((data) => data.toJson()).toList(),
    };
  }
}

