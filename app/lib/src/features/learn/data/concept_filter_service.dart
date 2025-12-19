import 'package:archipelago/src/features/dictionary/data/dictionary_query_service.dart';

/// Service for filtering concepts and getting related lemmas
class ConceptFilterService {
  /// Get filtered concepts and extract lemma IDs for specific languages.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'lemmaIds': List<int> (if successful) - list of lemma IDs in the target language
  /// - 'conceptIds': List<int> (if successful) - list of filtered concept IDs
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getFilteredLemmaIds({
    int? userId,
    required String targetLanguage,
    String? nativeLanguage,
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
    try {
      // Get filtered concepts using dictionary query service with pagination
      // Use maximum allowed page size (100) and paginate to get all concepts
      final conceptIds = <int>{};
      final lemmaIds = <int>{};
      int currentPage = 1;
      bool hasMorePages = true;
      
      // Include both native and learning languages in the query
      final visibleLanguages = <String>[targetLanguage];
      if (nativeLanguage != null && nativeLanguage.isNotEmpty) {
        visibleLanguages.add(nativeLanguage);
      }
      
      while (hasMorePages) {
        final result = await DictionaryQueryService.getDictionary(
          userId: userId,
          page: currentPage,
          pageSize: 100, // Maximum allowed page size
          sortBy: 'alphabetical',
          visibleLanguageCodes: visibleLanguages, // Include both native and learning languages
          includeLemmas: includeLemmas,
          includePhrases: includePhrases,
          topicIds: topicIds,
          includeWithoutTopic: includeWithoutTopic,
          levels: levels,
          partOfSpeech: partOfSpeech,
          hasImages: hasImages,
          hasAudio: hasAudio,
          isComplete: isComplete,
        );
        
        if (result['success'] != true) {
          return {
            'success': false,
            'message': result['message'] as String? ?? 'Failed to get filtered concepts',
          };
        }
        
        final items = result['items'] as List<dynamic>? ?? [];
        
        // Extract concept IDs and lemma IDs from the dictionary items
        for (final item in items) {
          final itemMap = item as Map<String, dynamic>;
          final conceptId = itemMap['concept_id'] as int?;
          if (conceptId != null) {
            conceptIds.add(conceptId);
          }
          
          // Extract lemma IDs from cards/lemmas
          // The dictionary response can have either 'lemmas' or 'cards' field
          final lemmasData = itemMap['lemmas'] as List<dynamic>? ?? itemMap['cards'] as List<dynamic>? ?? [];
          for (final lemma in lemmasData) {
            final lemmaMap = lemma as Map<String, dynamic>;
            // Only include lemmas in the target language (learning language)
            final lemmaLanguage = lemmaMap['language_code'] as String?;
            if (lemmaLanguage == targetLanguage) {
              // The lemma ID is in the 'id' field (not 'lemma_id')
              final lemmaId = lemmaMap['id'] as int?;
              if (lemmaId != null) {
                lemmaIds.add(lemmaId);
              }
            }
          }
        }
        
        // Check if there are more pages
        hasMorePages = result['has_next'] as bool? ?? false;
        currentPage++;
      }
      
      return {
        'success': true,
        'lemmaIds': lemmaIds.toList(),
        'conceptIds': conceptIds.toList(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error filtering concepts: ${e.toString()}',
      };
    }
  }
}

