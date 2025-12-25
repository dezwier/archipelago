import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/shared/domain/filter_config.dart';

/// Service for learning feature - retrieving new cards for learning
class LearnService {
  /// Get new cards (concepts with/without cards for the user in learning language).
  /// Filters concepts using the same parameters as the dictionary endpoint.
  /// Only returns concepts that have lemmas in both native and learning languages.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'concepts': List<Map<String, dynamic>> (if successful) - list of concepts, each with learning_lemma and native_lemma
  /// - 'native_language': String (if successful) - user's native language code
  /// - 'total_concepts_count': int (if successful) - total number of concepts visible to the user
  /// - 'filtered_concepts_count': int (if successful) - number of concepts after dictionary filtering
  /// - 'concepts_with_both_languages_count': int (if successful) - number of concepts with lemmas in both languages
  /// - 'concepts_without_cards_count': int (if successful) - number of concepts matching user_lemma criteria
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getNewCards({
    required int userId,
    required String language, // Learning language
    String? nativeLanguage, // Native language (optional)
    int? maxN,
    String? search,
    bool includeLemmas = true,
    bool includePhrases = true,
    List<int>? topicIds,
    bool includeWithoutTopic = true,
    List<String>? levels,
    List<String>? partOfSpeech,
    int? hasImages,
    int? hasAudio,
    int? isComplete,
    bool includeWithUserLemma = false, // Include concepts that have a user lemma
    bool includeWithoutUserLemma = true, // Include concepts that don't have a user lemma
    String? leitnerBins, // Comma-separated list of bin numbers, or null if all bins selected
    String? learningStatus, // Comma-separated list, or null if all statuses selected
  }) async {
    // Create FilterConfig from parameters
    final filterConfig = FilterConfig(
      userId: userId,
      visibleLanguages: null, // Will be set in backend based on native/learning languages
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
      leitnerBins: leitnerBins,
      learningStatus: learningStatus,
    );
    
    // Create request body
    final requestBody = {
      'filter_config': filterConfig.toJson(),
      'language': language,
      if (nativeLanguage != null && nativeLanguage.isNotEmpty) 'native_language': nativeLanguage,
      if (maxN != null) 'max_n': maxN,
      'include_with_user_lemma': includeWithUserLemma,
      'include_without_user_lemma': includeWithoutUserLemma,
    };
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lessons/generate');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final conceptsList = responseData['concepts'] as List<dynamic>;
        final nativeLanguage = responseData['native_language'] as String?;
        final totalConceptsCount = responseData['total_concepts_count'] as int? ?? 0;
        final filteredConceptsCount = responseData['filtered_concepts_count'] as int? ?? 0;
        final conceptsWithBothLanguagesCount = responseData['concepts_with_both_languages_count'] as int? ?? 0;
        final conceptsWithoutCardsCount = responseData['concepts_without_cards_count'] as int? ?? 0;
        return {
          'success': true,
          'concepts': conceptsList.map((concept) => concept as Map<String, dynamic>).toList(),
          'native_language': nativeLanguage,
          'total_concepts_count': totalConceptsCount,
          'filtered_concepts_count': filteredConceptsCount,
          'concepts_with_both_languages_count': conceptsWithBothLanguagesCount,
          'concepts_without_cards_count': conceptsWithoutCardsCount,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to get new cards',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting new cards: ${e.toString()}',
      };
    }
  }
}

