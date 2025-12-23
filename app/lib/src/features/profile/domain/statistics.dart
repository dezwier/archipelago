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

class ExerciseDailyData {
  final String date;
  final int count;

  ExerciseDailyData({
    required this.date,
    required this.count,
  });

  factory ExerciseDailyData.fromJson(Map<String, dynamic> json) {
    return ExerciseDailyData(
      date: json['date'] as String,
      count: json['count'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'count': count,
    };
  }
}

class LanguageExerciseData {
  final String languageCode;
  final List<ExerciseDailyData> dailyData;

  LanguageExerciseData({
    required this.languageCode,
    required this.dailyData,
  });

  factory LanguageExerciseData.fromJson(Map<String, dynamic> json) {
    return LanguageExerciseData(
      languageCode: json['language_code'] as String,
      dailyData: (json['daily_data'] as List<dynamic>)
          .map((item) => ExerciseDailyData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_code': languageCode,
      'daily_data': dailyData.map((data) => data.toJson()).toList(),
    };
  }
}

class ExercisesDaily {
  final List<LanguageExerciseData> languageData;

  ExercisesDaily({
    required this.languageData,
  });

  factory ExercisesDaily.fromJson(Map<String, dynamic> json) {
    return ExercisesDaily(
      languageData: (json['language_data'] as List<dynamic>)
          .map((item) => LanguageExerciseData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_data': languageData.map((data) => data.toJson()).toList(),
    };
  }
}

