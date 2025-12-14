import 'dart:async';
import 'package:flutter/material.dart';
import 'package:archipelago/src/features/generate_flashcards/data/card_generation_background_service.dart';

class CardGenerationState extends ChangeNotifier {
  // Progress tracking for lemma generation
  int? _totalConcepts;
  int _currentConceptIndex = 0;
  String? _currentConceptTerm;
  List<String> _currentConceptMissingLanguages = [];
  int _conceptsProcessed = 0;
  int _cardsCreated = 0;
  List<String> _errors = [];
  bool _isCancelled = false;
  bool _isGeneratingCards = false;
  double _sessionCostUsd = 0.0;
  
  Timer? _progressPollTimer;

  // Getters
  int? get totalConcepts => _totalConcepts;
  int get currentConceptIndex => _currentConceptIndex;
  String? get currentConceptTerm => _currentConceptTerm;
  List<String> get currentConceptMissingLanguages => _currentConceptMissingLanguages;
  int get conceptsProcessed => _conceptsProcessed;
  int get cardsCreated => _cardsCreated;
  List<String> get errors => _errors;
  bool get isCancelled => _isCancelled;
  bool get isGeneratingCards => _isGeneratingCards;
  double get sessionCostUsd => _sessionCostUsd;

  Future<void> loadExistingTaskState() async {
    final state = await CardGenerationBackgroundService.getTaskState();
    if (state != null && state['isRunning'] == true) {
      // Get missing languages for current concept
      final conceptIds = state['conceptIds'] as List<int>? ?? [];
      final conceptMissingLanguagesMap = state['conceptMissingLanguages'] as Map<int, List<String>>? ?? {};
      final currentIndex = state['currentIndex'] as int? ?? 0;
      final currentConceptMissingLanguages = <String>[];
      
      if (currentIndex < conceptIds.length) {
        final currentConceptId = conceptIds[currentIndex];
        currentConceptMissingLanguages.addAll(conceptMissingLanguagesMap[currentConceptId] ?? []);
      }
      
      _isGeneratingCards = true;
      _totalConcepts = state['totalConcepts'] as int?;
      _currentConceptIndex = currentIndex;
      _currentConceptTerm = state['currentTerm'] as String?;
      _currentConceptMissingLanguages = currentConceptMissingLanguages;
      _conceptsProcessed = state['conceptsProcessed'] as int? ?? 0;
      _cardsCreated = state['cardsCreated'] as int? ?? 0;
      _sessionCostUsd = state['sessionCostUsd'] as double? ?? 0.0;
      _errors = List<String>.from(state['errors'] as List? ?? []);
      _isCancelled = state['isCancelled'] as bool? ?? false;
      notifyListeners();
    }
  }

  void startProgressPolling(VoidCallback onComplete) {
    _progressPollTimer?.cancel();
    _progressPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isGeneratingCards) {
        timer.cancel();
        return;
      }

      final state = await CardGenerationBackgroundService.getTaskState();
      
      // Check if cancelled first
      final isCancelled = state?['isCancelled'] as bool? ?? false;
      if (isCancelled) {
        timer.cancel();
        _isCancelled = true;
        _isGeneratingCards = false;
        notifyListeners();
        onComplete();
        return;
      }
      
      if (state == null || state['isRunning'] != true) {
        // Task completed (not cancelled)
        timer.cancel();
        _isGeneratingCards = false;
        notifyListeners();
        onComplete();
        return;
      }

      // Get missing languages for current concept
      final conceptIds = state['conceptIds'] as List<int>? ?? [];
      final conceptMissingLanguagesMap = state['conceptMissingLanguages'] as Map<int, List<String>>? ?? {};
      final currentIndex = state['currentIndex'] as int? ?? 0;
      final currentConceptMissingLanguages = <String>[];
      
      if (currentIndex < conceptIds.length) {
        final currentConceptId = conceptIds[currentIndex];
        currentConceptMissingLanguages.addAll(conceptMissingLanguagesMap[currentConceptId] ?? []);
      }

      _currentConceptIndex = currentIndex;
      _currentConceptTerm = state['currentTerm'] as String?;
      _currentConceptMissingLanguages = currentConceptMissingLanguages;
      _conceptsProcessed = state['conceptsProcessed'] as int? ?? 0;
      _cardsCreated = state['cardsCreated'] as int? ?? 0;
      _sessionCostUsd = state['sessionCostUsd'] as double? ?? 0.0;
      _errors = List<String>.from(state['errors'] as List? ?? []);
      _isCancelled = false; // Only set to false if we're still running and not cancelled
      notifyListeners();
    });
  }
  
  void dismissProgress() {
    _totalConcepts = null;
    _currentConceptIndex = 0;
    _currentConceptTerm = null;
    _currentConceptMissingLanguages = [];
    _conceptsProcessed = 0;
    _cardsCreated = 0;
    _errors = [];
    _isCancelled = false;
    _isGeneratingCards = false;
    _sessionCostUsd = 0.0;
    notifyListeners();
  }
  
  Future<void> handleCancel() async {
    // Stop polling immediately
    _progressPollTimer?.cancel();
    await CardGenerationBackgroundService.cancelTask();
    _isCancelled = true;
    _isGeneratingCards = false;
    notifyListeners();
  }

  void startGeneration({
    required int totalConcepts,
    required List<int> conceptIds,
    required Map<int, String> conceptTerms,
    required Map<int, List<String>> conceptMissingLanguages,
  }) {
    _isGeneratingCards = true;
    _isCancelled = false;
    _totalConcepts = totalConcepts;
    _currentConceptIndex = 0;
    _currentConceptTerm = null;
    _currentConceptMissingLanguages = [];
    _conceptsProcessed = 0;
    _cardsCreated = 0;
    _errors = [];
    _sessionCostUsd = 0.0;
    notifyListeners();
  }

  void clearCurrentConcept() {
    _currentConceptTerm = null;
    _currentConceptMissingLanguages = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _progressPollTimer?.cancel();
    super.dispose();
  }
}

