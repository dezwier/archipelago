// Re-export all dictionary services for backward compatibility
export 'dictionary_query_service.dart';
export 'dictionary_mutation_service.dart';
export 'dictionary_generation_service.dart';

import 'dictionary_query_service.dart';
import 'dictionary_mutation_service.dart';
import 'dictionary_generation_service.dart';

/// Main dictionary service class that provides a unified interface.
/// 
/// This class delegates to specialized services:
/// - DictionaryQueryService: for fetching/querying dictionary data
/// - DictionaryMutationService: for updating/deleting dictionary data
/// - DictionaryGenerationService: for description generation
/// 
/// For backward compatibility, all static methods are available through this class.
/// You can also import the specialized services directly for better organization.
class DictionaryService {
  // Query methods
  static Future<Map<String, dynamic>> getDictionary({
    int? userId,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'alphabetical',
    String? search,
    List<String> visibleLanguageCodes = const [],
    bool includeLemmas = true,
    bool includePhrases = true,
    List<int>? topicIds,
    bool includeWithoutTopic = false,
    List<String>? levels,
    List<String>? partOfSpeech,
    int? hasImages,
    int? isComplete,
  }) =>
      DictionaryQueryService.getDictionary(
        userId: userId,
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        search: search,
        visibleLanguageCodes: visibleLanguageCodes,
        includeLemmas: includeLemmas,
        includePhrases: includePhrases,
        topicIds: topicIds,
        includeWithoutTopic: includeWithoutTopic,
        levels: levels,
        partOfSpeech: partOfSpeech,
        hasImages: hasImages,
        isComplete: isComplete,
      );

  static Future<Map<String, dynamic>> getConceptCountTotal({int? userId}) =>
      DictionaryQueryService.getConceptCountTotal(userId: userId);

  static Future<Map<String, dynamic>> getConceptById({
    required int conceptId,
    List<String> visibleLanguageCodes = const [],
  }) =>
      DictionaryQueryService.getConceptById(
        conceptId: conceptId,
        visibleLanguageCodes: visibleLanguageCodes,
      );

  static Future<Map<String, dynamic>> getConceptDataOnly(int conceptId) =>
      DictionaryQueryService.getConceptDataOnly(conceptId);

  static Future<Map<String, dynamic>> getLemmasOnly(
    int conceptId,
    List<String> visibleLanguageCodes,
  ) =>
      DictionaryQueryService.getLemmasOnly(conceptId, visibleLanguageCodes);

  static Future<Map<String, dynamic>> getTopicDataOnly(int? topicId) =>
      DictionaryQueryService.getTopicDataOnly(topicId);

  // Mutation methods
  static Future<Map<String, dynamic>> updateCard({
    required int cardId,
    String? translation,
    String? description,
  }) =>
      DictionaryMutationService.updateCard(
        cardId: cardId,
        translation: translation,
        description: description,
      );

  static Future<Map<String, dynamic>> deleteConcept({
    required int conceptId,
  }) =>
      DictionaryMutationService.deleteConcept(conceptId: conceptId);

  static Future<Map<String, dynamic>> updateConcept({
    required int conceptId,
    String? term,
    String? description,
    int? topicId,
  }) =>
      DictionaryMutationService.updateConcept(
        conceptId: conceptId,
        term: term,
        description: description,
        topicId: topicId,
      );

  // Generation methods
  static Future<Map<String, dynamic>> startGenerateDescriptions({
    int? userId,
  }) =>
      DictionaryGenerationService.startGenerateDescriptions(userId: userId);

  static Future<Map<String, dynamic>> getDescriptionGenerationStatus({
    required String taskId,
  }) =>
      DictionaryGenerationService.getDescriptionGenerationStatus(taskId: taskId);
}
