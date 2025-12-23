import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';

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
    final queryParams = <String, String>{
      'user_id': userId.toString(),
      'include_lemmas': includeLemmas.toString(),
      'include_phrases': includePhrases.toString(),
      'include_without_topic': includeWithoutTopic.toString(),
    };

    if (visibleLanguageCodes != null && visibleLanguageCodes.isNotEmpty) {
      queryParams['visible_languages'] = visibleLanguageCodes.join(',');
    }

    if (topicIds != null && topicIds.isNotEmpty) {
      queryParams['topic_ids'] = topicIds.join(',');
    }

    if (levels != null && levels.isNotEmpty) {
      queryParams['levels'] = levels.join(',');
    }

    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      queryParams['part_of_speech'] = partOfSpeech.join(',');
    }

    if (hasImages != null) {
      queryParams['has_images'] = hasImages.toString();
    }

    if (hasAudio != null) {
      queryParams['has_audio'] = hasAudio.toString();
    }

    if (isComplete != null) {
      queryParams['is_complete'] = isComplete.toString();
    }

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final url = Uri.parse('${ApiConfig.apiBaseUrl}/user-lemma-stats/summary').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
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
    final queryParams = <String, String>{
      'user_id': userId.toString(),
      'language_code': languageCode,
      'include_lemmas': includeLemmas.toString(),
      'include_phrases': includePhrases.toString(),
      'include_without_topic': includeWithoutTopic.toString(),
    };

    if (topicIds != null && topicIds.isNotEmpty) {
      queryParams['topic_ids'] = topicIds.join(',');
    }

    if (levels != null && levels.isNotEmpty) {
      queryParams['levels'] = levels.join(',');
    }

    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      queryParams['part_of_speech'] = partOfSpeech.join(',');
    }

    if (hasImages != null) {
      queryParams['has_images'] = hasImages.toString();
    }

    if (hasAudio != null) {
      queryParams['has_audio'] = hasAudio.toString();
    }

    if (isComplete != null) {
      queryParams['is_complete'] = isComplete.toString();
    }

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final url = Uri.parse('${ApiConfig.apiBaseUrl}/user-lemma-stats/leitner-distribution').replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
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
}

