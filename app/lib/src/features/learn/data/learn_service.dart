import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';

/// Service for learning feature - retrieving new cards for learning
class LearnService {
  /// Get new cards (concepts without cards for the user in learning language).
  /// Filters concepts using the same parameters as the dictionary endpoint.
  /// Only returns concepts that have lemmas in both native and learning languages.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'concepts': List<Map<String, dynamic>> (if successful) - list of concepts, each with learning_lemma and native_lemma
  /// - 'native_language': String (if successful) - user's native language code
  /// - 'filtered_concepts_count': int (if successful) - number of concepts after dictionary filtering
  /// - 'concepts_with_both_languages_count': int (if successful) - number of concepts with lemmas in both languages
  /// - 'concepts_without_cards_count': int (if successful) - number of concepts without cards for user
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
  }) async {
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/lemmas/new-cards');
    final queryParams = <String, String>{
      'user_id': userId.toString(),
      'language': language,
    };
    
    // Add native_language if provided
    if (nativeLanguage != null && nativeLanguage.isNotEmpty) {
      queryParams['native_language'] = nativeLanguage;
    }
    
    // Add max_n if provided
    if (maxN != null) {
      queryParams['max_n'] = maxN.toString();
    }
    
    // Add filter parameters (same as dictionary endpoint)
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    if (!includeLemmas) {
      queryParams['include_lemmas'] = 'false';
    }
    
    if (!includePhrases) {
      queryParams['include_phrases'] = 'false';
    }
    
    if (topicIds != null && topicIds.isNotEmpty) {
      queryParams['topic_ids'] = topicIds.join(',');
    }
    
    if (includeWithoutTopic) {
      queryParams['include_without_topic'] = 'true';
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
    
    final url = uri.replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final conceptsList = responseData['concepts'] as List<dynamic>;
        final nativeLanguage = responseData['native_language'] as String?;
        final filteredConceptsCount = responseData['filtered_concepts_count'] as int? ?? 0;
        final conceptsWithBothLanguagesCount = responseData['concepts_with_both_languages_count'] as int? ?? 0;
        final conceptsWithoutCardsCount = responseData['concepts_without_cards_count'] as int? ?? 0;
        return {
          'success': true,
          'concepts': conceptsList.map((concept) => concept as Map<String, dynamic>).toList(),
          'native_language': nativeLanguage,
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

