import 'dart:io';
import 'package:archipelago/src/features/create/data/concept_service.dart';
import 'package:archipelago/src/features/create/data/lemma_service.dart';
import 'package:archipelago/src/features/create/data/image_service.dart';

/// Facade class that delegates to specialized services.
/// This maintains backward compatibility while the implementation is split across multiple files.
class FlashcardService {
  // Concept operations
  static Future<Map<String, dynamic>> previewConcept({
    required String term,
    int? topicId,
    String? partOfSpeech,
    String? coreMeaningEn,
    required List<String> languages,
    List<String>? excludedSenses,
  }) =>
      ConceptService.previewConcept(
        term: term,
        topicId: topicId,
        partOfSpeech: partOfSpeech,
        coreMeaningEn: coreMeaningEn,
        languages: languages,
        excludedSenses: excludedSenses,
      );

  static Future<Map<String, dynamic>> confirmConcept({
    required String term,
    int? topicId,
    int? userId,
    String? partOfSpeech,
    required Map<String, dynamic> conceptData,
    required List<Map<String, dynamic>> cardsData,
  }) =>
      ConceptService.confirmConcept(
        term: term,
        topicId: topicId,
        userId: userId,
        partOfSpeech: partOfSpeech,
        conceptData: conceptData,
        cardsData: cardsData,
      );

  static Future<Map<String, dynamic>> createConcept({
    required String term,
    int? topicId,
    int? userId,
    String? partOfSpeech,
    String? coreMeaningEn,
    required List<String> languages,
    List<String>? excludedSenses,
  }) =>
      ConceptService.createConcept(
        term: term,
        topicId: topicId,
        userId: userId,
        partOfSpeech: partOfSpeech,
        coreMeaningEn: coreMeaningEn,
        languages: languages,
        excludedSenses: excludedSenses,
      );

  static Future<Map<String, dynamic>> createConceptOnly({
    required String term,
    String? description,
    int? topicId,
    List<int>? topicIds,
    int? userId,
  }) =>
      ConceptService.createConceptOnly(
        term: term,
        description: description,
        topicId: topicId,
        topicIds: topicIds,
        userId: userId,
      );

  static Future<Map<String, dynamic>> getConceptsWithMissingLanguages({
    required List<String> languages,
    List<String>? levels,
    List<String>? partOfSpeech,
    List<int>? topicIds,
    bool includeWithoutTopic = false,
    bool includeLemmas = true,
    bool includePhrases = true,
    String? search,
  }) =>
      ConceptService.getConceptsWithMissingLanguages(
        languages: languages,
        levels: levels,
        partOfSpeech: partOfSpeech,
        topicIds: topicIds,
        includeWithoutTopic: includeWithoutTopic,
        includeLemmas: includeLemmas,
        includePhrases: includePhrases,
        search: search,
      );

  // Lemma operations
  static Future<Map<String, dynamic>> generateLemma({
    required String term,
    required String targetLanguage,
    String? description,
    String? partOfSpeech,
    int? conceptId,
  }) =>
      LemmaService.generateLemma(
        term: term,
        targetLanguage: targetLanguage,
        description: description,
        partOfSpeech: partOfSpeech,
        conceptId: conceptId,
      );

  static Future<Map<String, dynamic>> generateLemmasBatch({
    required String term,
    required List<String> targetLanguages,
    String? description,
    String? partOfSpeech,
    int? conceptId,
  }) =>
      LemmaService.generateLemmasBatch(
        term: term,
        targetLanguages: targetLanguages,
        description: description,
        partOfSpeech: partOfSpeech,
        conceptId: conceptId,
      );

  static Future<Map<String, dynamic>> generateCardsForConcept({
    required int conceptId,
    required List<String> languages,
  }) =>
      LemmaService.generateCardsForConcept(
        conceptId: conceptId,
        languages: languages,
      );

  static Future<Map<String, dynamic>> generateCardsForConcepts({
    required List<int> conceptIds,
    required List<String> languages,
  }) =>
      LemmaService.generateCardsForConcepts(
        conceptIds: conceptIds,
        languages: languages,
      );

  // Image operations
  static Future<Map<String, dynamic>> uploadConceptImage({
    required int conceptId,
    required File imageFile,
  }) =>
      ImageService.uploadConceptImage(
        conceptId: conceptId,
        imageFile: imageFile,
      );

  static Future<Map<String, dynamic>> generateImagePreview({
    required String term,
    String? description,
    String? topicDescription,
  }) =>
      ImageService.generateImagePreview(
        term: term,
        description: description,
        topicDescription: topicDescription,
      );
}
