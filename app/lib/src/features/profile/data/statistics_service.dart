import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/shared/domain/filter_config.dart';

/// Service for fetching user statistics.
class StatisticsService {
  /// Get language summary statistics (lemmas and exercises per language).
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'data': SummaryStats (if successful)
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getLanguageSummaryStats({
    required int userId,
    List<String>? visibleLanguageCodes,
    bool includeLemmas = true,
    bool includePhrases = true,
    List<int>? topicIds,
    bool includeWithoutTopic = true,
    List<String>? levels,
    List<String>? partOfSpeech,
    int? hasImages,
    int? hasAudio,
    int? isComplete,
    String? search,
  }) async {
    // Create FilterConfig from parameters
    final filterConfig = FilterConfig(
      userId: userId,
      visibleLanguages: visibleLanguageCodes != null && visibleLanguageCodes.isNotEmpty 
          ? visibleLanguageCodes.join(',') 
          : null,
      includeLemmas: includeLemmas,
      includePhrases: includePhrases,
      topicIds: topicIds != null && topicIds.isNotEmpty ? topicIds.join(',') : null,
      includeWithoutTopic: includeWithoutTopic,
      levels: levels != null && levels.isNotEmpty ? levels.join(',') : null,
      partOfSpeech: partOfSpeech != null && partOfSpeech.isNotEmpty ? partOfSpeech.join(',') : null,
      hasImages: hasImages,
      hasAudio: hasAudio,
      isComplete: isComplete,
      search: search,
    );
    
    // Create request body
    final requestBody = {
      'filter_config': filterConfig.toJson(),
    };
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/user-lemma-stats/summary');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': SummaryStats.fromJson(data),
        };
      } else {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to fetch summary statistics',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to fetch summary statistics: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching summary statistics: ${e.toString()}',
      };
    }
  }

  /// Get Leitner bin distribution for a specific language.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'data': LeitnerDistribution (if successful)
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getLeitnerDistribution({
    required int userId,
    required String languageCode,
    bool includeLemmas = true,
    bool includePhrases = true,
    List<int>? topicIds,
    bool includeWithoutTopic = true,
    List<String>? levels,
    List<String>? partOfSpeech,
    int? hasImages,
    int? hasAudio,
    int? isComplete,
    String? search,
  }) async {
    // Create FilterConfig from parameters
    final filterConfig = FilterConfig(
      userId: userId,
      visibleLanguages: languageCode, // Single language for this endpoint
      includeLemmas: includeLemmas,
      includePhrases: includePhrases,
      topicIds: topicIds != null && topicIds.isNotEmpty ? topicIds.join(',') : null,
      includeWithoutTopic: includeWithoutTopic,
      levels: levels != null && levels.isNotEmpty ? levels.join(',') : null,
      partOfSpeech: partOfSpeech != null && partOfSpeech.isNotEmpty ? partOfSpeech.join(',') : null,
      hasImages: hasImages,
      hasAudio: hasAudio,
      isComplete: isComplete,
      search: search,
    );
    
    // Create request body
    final requestBody = {
      'filter_config': filterConfig.toJson(),
      'language_code': languageCode,
    };
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/user-lemma-stats/leitner-distribution');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': LeitnerDistribution.fromJson(data),
        };
      } else {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to fetch Leitner distribution',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to fetch Leitner distribution: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching Leitner distribution: ${e.toString()}',
      };
    }
  }

  /// Get practice data per language per day.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'data': PracticeDaily (if successful)
  /// - 'message': String (if error)
  /// 
  /// metricType: 'exercises', 'lessons', 'lemmas', or 'time'
  static Future<Map<String, dynamic>> getPracticeDaily({
    required int userId,
    String metricType = 'exercises',
    List<String>? visibleLanguageCodes,
    bool includeLemmas = true,
    bool includePhrases = true,
    List<int>? topicIds,
    bool includeWithoutTopic = true,
    List<String>? levels,
    List<String>? partOfSpeech,
    int? hasImages,
    int? hasAudio,
    int? isComplete,
    String? search,
  }) async {
    // Create FilterConfig from parameters
    final filterConfig = FilterConfig(
      userId: userId,
      visibleLanguages: visibleLanguageCodes != null && visibleLanguageCodes.isNotEmpty 
          ? visibleLanguageCodes.join(',') 
          : null,
      includeLemmas: includeLemmas,
      includePhrases: includePhrases,
      topicIds: topicIds != null && topicIds.isNotEmpty ? topicIds.join(',') : null,
      includeWithoutTopic: includeWithoutTopic,
      levels: levels != null && levels.isNotEmpty ? levels.join(',') : null,
      partOfSpeech: partOfSpeech != null && partOfSpeech.isNotEmpty ? partOfSpeech.join(',') : null,
      hasImages: hasImages,
      hasAudio: hasAudio,
      isComplete: isComplete,
      search: search,
    );
    
    // Create request body
    final requestBody = {
      'filter_config': filterConfig.toJson(),
      'metric_type': metricType,
    };
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/user-lemma-stats/exercises-daily');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': PracticeDaily.fromJson(data),
        };
      } else {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to fetch practice daily',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to fetch practice daily: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching practice daily: ${e.toString()}',
      };
    }
  }

  /// Get exercises per language per day (backward compatibility).
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'data': ExercisesDaily (if successful)
  /// - 'message': String (if error)
  @Deprecated('Use getPracticeDaily with metricType: "exercises" instead')
  static Future<Map<String, dynamic>> getExercisesDaily({
    required int userId,
    List<String>? visibleLanguageCodes,
    bool includeLemmas = true,
    bool includePhrases = true,
    List<int>? topicIds,
    bool includeWithoutTopic = true,
    List<String>? levels,
    List<String>? partOfSpeech,
    int? hasImages,
    int? hasAudio,
    int? isComplete,
    String? search,
  }) async {
    return getPracticeDaily(
      userId: userId,
      metricType: 'exercises',
      visibleLanguageCodes: visibleLanguageCodes,
      includeLemmas: includeLemmas,
      includePhrases: includePhrases,
      topicIds: topicIds,
      includeWithoutTopic: includeWithoutTopic,
      levels: levels,
      partOfSpeech: partOfSpeech,
      hasImages: hasImages,
      hasAudio: hasAudio,
      isComplete: isComplete,
      search: search,
    );
  }
}

