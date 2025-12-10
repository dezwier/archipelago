import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'flashcard_service.dart';

/// Service to manage background card generation tasks.
/// Persists state to SharedPreferences so it can survive app backgrounding.
class CardGenerationBackgroundService {
  static const String _keyPrefix = 'card_generation_';
  static const String _keyIsRunning = '${_keyPrefix}is_running';
  static const String _keyTotalConcepts = '${_keyPrefix}total_concepts';
  static const String _keyCurrentIndex = '${_keyPrefix}current_index';
  static const String _keyCurrentTerm = '${_keyPrefix}current_term';
  static const String _keyConceptsProcessed = '${_keyPrefix}concepts_processed';
  static const String _keyCardsCreated = '${_keyPrefix}cards_created';
  static const String _keySessionCost = '${_keyPrefix}session_cost';
  static const String _keyErrors = '${_keyPrefix}errors';
  static const String _keySelectedLanguages = '${_keyPrefix}selected_languages';
  static const String _keyConceptIds = '${_keyPrefix}concept_ids';
  static const String _keyConceptTerms = '${_keyPrefix}concept_terms';
  static const String _keyConceptMissingLanguages = '${_keyPrefix}concept_missing_languages';
  static const String _keyIsCancelled = '${_keyPrefix}is_cancelled';

  /// Start a background card generation task
  static Future<void> startTask({
    required List<int> conceptIds,
    required Map<int, String> conceptTerms,
    required Map<int, List<String>> conceptMissingLanguages,
    required List<String> selectedLanguages,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save initial state
    await prefs.setBool(_keyIsRunning, true);
    await prefs.setInt(_keyTotalConcepts, conceptIds.length);
    await prefs.setInt(_keyCurrentIndex, 0);
    await prefs.setInt(_keyConceptsProcessed, 0);
    await prefs.setInt(_keyCardsCreated, 0);
    await prefs.setDouble(_keySessionCost, 0.0);
    await prefs.setStringList(_keyErrors, []);
    await prefs.setStringList(_keySelectedLanguages, selectedLanguages);
    await prefs.setStringList(_keyConceptIds, conceptIds.map((id) => id.toString()).toList());
    await prefs.setString(_keyConceptTerms, jsonEncode(conceptTerms.map((k, v) => MapEntry(k.toString(), v))));
    await prefs.setString(_keyConceptMissingLanguages, jsonEncode(conceptMissingLanguages.map((k, v) => MapEntry(k.toString(), v))));
    await prefs.setBool(_keyIsCancelled, false);
  }

  /// Get current task state
  static Future<Map<String, dynamic>?> getTaskState() async {
    final prefs = await SharedPreferences.getInstance();
    final isRunning = prefs.getBool(_keyIsRunning) ?? false;
    
    if (!isRunning) {
      return null;
    }

    final conceptIdsStr = prefs.getStringList(_keyConceptIds) ?? [];
    final conceptIds = conceptIdsStr.map((id) => int.parse(id)).toList();
    
    final conceptTermsStr = prefs.getString(_keyConceptTerms) ?? '{}';
    final conceptTermsMap = jsonDecode(conceptTermsStr) as Map<String, dynamic>;
    final conceptTerms = conceptTermsMap.map((k, v) => MapEntry(int.parse(k), v as String));
    
    final conceptMissingLanguagesStr = prefs.getString(_keyConceptMissingLanguages) ?? '{}';
    final conceptMissingLanguagesMap = jsonDecode(conceptMissingLanguagesStr) as Map<String, dynamic>;
    final conceptMissingLanguages = conceptMissingLanguagesMap.map((k, v) => 
      MapEntry(int.parse(k), (v as List<dynamic>).map((e) => e.toString()).toList()));

    return {
      'isRunning': isRunning,
      'totalConcepts': prefs.getInt(_keyTotalConcepts),
      'currentIndex': prefs.getInt(_keyCurrentIndex) ?? 0,
      'currentTerm': prefs.getString(_keyCurrentTerm),
      'conceptsProcessed': prefs.getInt(_keyConceptsProcessed) ?? 0,
      'cardsCreated': prefs.getInt(_keyCardsCreated) ?? 0,
      'sessionCostUsd': prefs.getDouble(_keySessionCost) ?? 0.0,
      'errors': prefs.getStringList(_keyErrors) ?? [],
      'selectedLanguages': prefs.getStringList(_keySelectedLanguages) ?? [],
      'conceptIds': conceptIds,
      'conceptTerms': conceptTerms,
      'conceptMissingLanguages': conceptMissingLanguages,
      'isCancelled': prefs.getBool(_keyIsCancelled) ?? false,
    };
  }

  /// Update progress during task execution
  static Future<void> updateProgress({
    required int currentIndex,
    String? currentTerm,
    required int conceptsProcessed,
    required int cardsCreated,
    required double sessionCostUsd,
    List<String>? errors,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentIndex, currentIndex);
    if (currentTerm != null) {
      await prefs.setString(_keyCurrentTerm, currentTerm);
    }
    await prefs.setInt(_keyConceptsProcessed, conceptsProcessed);
    await prefs.setInt(_keyCardsCreated, cardsCreated);
    await prefs.setDouble(_keySessionCost, sessionCostUsd);
    if (errors != null) {
      await prefs.setStringList(_keyErrors, errors);
    }
  }

  /// Mark task as cancelled
  static Future<void> cancelTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsCancelled, true);
  }

  /// Check if task is cancelled
  static Future<bool> isCancelled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsCancelled) ?? false;
  }

  /// Complete the task and clear state
  static Future<void> completeTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRunning, false);
    await prefs.remove(_keyTotalConcepts);
    await prefs.remove(_keyCurrentIndex);
    await prefs.remove(_keyCurrentTerm);
    await prefs.remove(_keyConceptsProcessed);
    await prefs.remove(_keyCardsCreated);
    await prefs.remove(_keySessionCost);
    await prefs.remove(_keyErrors);
    await prefs.remove(_keySelectedLanguages);
    await prefs.remove(_keyConceptIds);
    await prefs.remove(_keyConceptTerms);
    await prefs.remove(_keyConceptMissingLanguages);
    await prefs.remove(_keyIsCancelled);
  }

  /// Execute the card generation task
  /// This should be called from a background isolate or service
  static Future<Map<String, dynamic>> executeTask() async {
    final state = await getTaskState();
    if (state == null) {
      return {
        'success': false,
        'message': 'No task state found',
      };
    }

    final taskCancelled = await isCancelled();
    if (taskCancelled) {
      await completeTask();
      return {
        'success': false,
        'message': 'Task was cancelled',
      };
    }

    final conceptIds = state['conceptIds'] as List<int>;
    final conceptTerms = state['conceptTerms'] as Map<int, String>;
    final selectedLanguages = state['selectedLanguages'] as List<String>;
    final currentIndex = state['currentIndex'] as int;
    int conceptsProcessed = state['conceptsProcessed'] as int;
    int cardsCreated = state['cardsCreated'] as int;
    double sessionCostUsd = state['sessionCostUsd'] as double;
    List<String> errors = List<String>.from(state['errors'] as List);

    // Process remaining concepts
    for (int i = currentIndex; i < conceptIds.length; i++) {
      // Check if cancelled
      final cancelled = await isCancelled();
      if (cancelled) {
        break;
      }

      final conceptId = conceptIds[i];
      final conceptTerm = conceptTerms[conceptId] ?? 'Unknown';

      // Update current progress
      await updateProgress(
        currentIndex: i,
        currentTerm: conceptTerm,
        conceptsProcessed: conceptsProcessed,
        cardsCreated: cardsCreated,
        sessionCostUsd: sessionCostUsd,
        errors: errors,
      );

      // Generate cards for this concept
      final generateResult = await FlashcardService.generateCardsForConcept(
        conceptId: conceptId,
        languages: selectedLanguages,
      );

      if (generateResult['success'] == true) {
        final data = generateResult['data'] as Map<String, dynamic>?;
        final cardsCreatedForConcept = data?['cards_created'] as int? ?? 0;
        final costUsd = (data?['session_cost_usd'] as num?)?.toDouble() ?? 0.0;

        conceptsProcessed++;
        cardsCreated += cardsCreatedForConcept;
        sessionCostUsd += costUsd;
      } else {
        final errorMsg = generateResult['message'] as String? ?? 'Unknown error';
        errors.add('Concept $conceptId ($conceptTerm): $errorMsg');
      }

      // Update progress after each concept
      await updateProgress(
        currentIndex: i + 1,
        currentTerm: null,
        conceptsProcessed: conceptsProcessed,
        cardsCreated: cardsCreated,
        sessionCostUsd: sessionCostUsd,
        errors: errors,
      );
    }

    // Complete the task
    await completeTask();

    return {
      'success': true,
      'message': 'Task completed',
      'data': {
        'conceptsProcessed': conceptsProcessed,
        'cardsCreated': cardsCreated,
        'sessionCostUsd': sessionCostUsd,
        'errors': errors,
      },
    };
  }
}

