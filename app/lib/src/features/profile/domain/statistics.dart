/// Statistics domain models for profile page.

class LanguageStat {
  final String languageCode;
  final int lemmaCount;
  final int exerciseCount;
  final int lessonCount;
  final int totalTimeSeconds;

  LanguageStat({
    required this.languageCode,
    required this.lemmaCount,
    required this.exerciseCount,
    required this.lessonCount,
    required this.totalTimeSeconds,
  });

  factory LanguageStat.fromJson(Map<String, dynamic> json) {
    return LanguageStat(
      languageCode: json['language_code'] as String,
      lemmaCount: json['lemma_count'] as int,
      exerciseCount: json['exercise_count'] as int,
      lessonCount: json['lesson_count'] as int,
      totalTimeSeconds: json['total_time_seconds'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_code': languageCode,
      'lemma_count': lemmaCount,
      'exercise_count': exerciseCount,
      'lesson_count': lessonCount,
      'total_time_seconds': totalTimeSeconds,
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
  final int countDue;
  final int countNotDue;

  LeitnerBinData({
    required this.bin,
    required this.count,
    this.countDue = 0,
    this.countNotDue = 0,
  });

  factory LeitnerBinData.fromJson(Map<String, dynamic> json) {
    return LeitnerBinData(
      bin: json['bin'] as int,
      count: json['count'] as int,
      countDue: json['count_due'] as int? ?? 0,
      countNotDue: json['count_not_due'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bin': bin,
      'count': count,
      'count_due': countDue,
      'count_not_due': countNotDue,
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

class PracticeDailyData {
  final String date;
  final int count;

  PracticeDailyData({
    required this.date,
    required this.count,
  });

  factory PracticeDailyData.fromJson(Map<String, dynamic> json) {
    return PracticeDailyData(
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

class LanguagePracticeData {
  final String languageCode;
  final List<PracticeDailyData> dailyData;

  LanguagePracticeData({
    required this.languageCode,
    required this.dailyData,
  });

  factory LanguagePracticeData.fromJson(Map<String, dynamic> json) {
    return LanguagePracticeData(
      languageCode: json['language_code'] as String,
      dailyData: (json['daily_data'] as List<dynamic>)
          .map((item) => PracticeDailyData.fromJson(item as Map<String, dynamic>))
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

class PracticeDaily {
  final List<LanguagePracticeData> languageData;

  PracticeDaily({
    required this.languageData,
  });

  factory PracticeDaily.fromJson(Map<String, dynamic> json) {
    return PracticeDaily(
      languageData: (json['language_data'] as List<dynamic>)
          .map((item) => LanguagePracticeData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_data': languageData.map((data) => data.toJson()).toList(),
    };
  }
}

// Keep old names for backward compatibility
typedef ExerciseDailyData = PracticeDailyData;
typedef LanguageExerciseData = LanguagePracticeData;
typedef ExercisesDaily = PracticeDaily;

