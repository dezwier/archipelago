import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:archipelago/src/common_widgets/filter_interface.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/features/learn/data/learn_service.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';
import 'package:archipelago/src/features/learn/domain/exercise_performance.dart';
import 'package:archipelago/src/features/learn/services/exercise_generator_service.dart';
import 'package:archipelago/src/constants/api_config.dart';

class LearnController extends ChangeNotifier implements FilterState {
  User? _currentUser;
  List<Map<String, dynamic>> _concepts = []; // List of concepts, each with learning_lemma and native_lemma
  List<Exercise> _exercises = []; // List of exercises generated from concepts
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _learningLanguage;
  String? _nativeLanguage;
  
  // Counts for cascading display
  int _totalConceptsCount = 0;
  int _filteredConceptsCount = 0;
  int _conceptsWithBothLanguagesCount = 0;
  int _conceptsWithoutCardsCount = 0;
  
  // Lesson state
  bool _isLessonActive = false;
  int _currentLessonIndex = 0; // Now tracks exercise index
  int _cardsToLearn = 4; // Number of cards to learn
  bool _showReportCard = false;
  
  // Performance tracking
  List<ExercisePerformance> _exercisePerformances = [];
  Map<String, DateTime> _exerciseStartTimes = {}; // Map exercise ID to start time
  
  // Filter state
  Set<int> _selectedTopicIds = {};
  bool _showLemmasWithoutTopic = true;
  Set<String> _selectedLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};
  Set<String> _selectedPartOfSpeech = {
    'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
    'Conjunction', 'Determiner / Article', 'Interjection', 'Numeral'
  };
  bool _includeLemmas = true;
  bool _includePhrases = true;
  bool _hasImages = true;
  bool _hasNoImages = true;
  bool _hasAudio = true;
  bool _hasNoAudio = true;
  bool _isComplete = true;
  bool _isIncomplete = true;
  
  // Getters
  User? get currentUser => _currentUser;
  List<Map<String, dynamic>> get concepts => _concepts; // List of concepts with both lemmas
  List<Exercise> get exercises => _exercises; // List of exercises
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  String? get learningLanguage => _learningLanguage;
  String? get nativeLanguage => _nativeLanguage;
  
  // Count getters
  int get totalConceptsCount => _totalConceptsCount;
  int get filteredConceptsCount => _filteredConceptsCount;
  int get conceptsWithBothLanguagesCount => _conceptsWithBothLanguagesCount;
  int get conceptsWithoutCardsCount => _conceptsWithoutCardsCount;
  
  // Lesson state getters
  bool get isLessonActive => _isLessonActive;
  int get currentLessonIndex => _currentLessonIndex;
  int get cardsToLearn => _cardsToLearn;
  bool get showReportCard => _showReportCard;
  
  // Performance tracking getters
  List<ExercisePerformance> get exercisePerformances => List.unmodifiable(_exercisePerformances);
  
  // FilterState interface implementation
  @override
  Set<int> get selectedTopicIds => _selectedTopicIds;
  
  @override
  bool get showLemmasWithoutTopic => _showLemmasWithoutTopic;
  
  @override
  Set<String> get selectedLevels => _selectedLevels;
  
  @override
  Set<String> get selectedPartOfSpeech => _selectedPartOfSpeech;
  
  @override
  bool get includeLemmas => _includeLemmas;
  
  @override
  bool get includePhrases => _includePhrases;
  
  @override
  bool get hasImages => _hasImages;
  
  @override
  bool get hasNoImages => _hasNoImages;
  
  @override
  bool get hasAudio => _hasAudio;
  
  @override
  bool get hasNoAudio => _hasNoAudio;
  
  @override
  bool get isComplete => _isComplete;
  
  @override
  bool get isIncomplete => _isIncomplete;
  
  /// Initialize the controller and load user
  Future<void> initialize() async {
    await _loadCurrentUser();
    if (_currentUser != null && _currentUser!.langLearning != null && _currentUser!.langLearning!.isNotEmpty) {
      _learningLanguage = _currentUser!.langLearning;
      await loadNewCards();
    } else {
      _isLoading = false;
      _errorMessage = 'Please set your learning language in Profile settings';
      notifyListeners();
    }
  }
  
  /// Load current user from SharedPreferences
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userMap);
        notifyListeners();
      }
    } catch (e) {
      // Ignore errors
    }
  }
  
  /// Batch update filters (without reloading cards - cards are only loaded when Generate Workout is pressed)
  void batchUpdateFilters({
    Set<int>? topicIds,
    bool? showLemmasWithoutTopic,
    Set<String>? levels,
    Set<String>? partOfSpeech,
    bool? includeLemmas,
    bool? includePhrases,
    bool? hasImages,
    bool? hasNoImages,
    bool? hasAudio,
    bool? hasNoAudio,
    bool? isComplete,
    bool? isIncomplete,
  }) {
    bool hasChanges = false;
    
    if (topicIds != null && _selectedTopicIds != topicIds) {
      _selectedTopicIds = topicIds;
      hasChanges = true;
    }
    if (showLemmasWithoutTopic != null && _showLemmasWithoutTopic != showLemmasWithoutTopic) {
      _showLemmasWithoutTopic = showLemmasWithoutTopic;
      hasChanges = true;
    }
    if (levels != null && _selectedLevels != levels) {
      _selectedLevels = levels;
      hasChanges = true;
    }
    if (partOfSpeech != null && _selectedPartOfSpeech != partOfSpeech) {
      _selectedPartOfSpeech = partOfSpeech;
      hasChanges = true;
    }
    if (includeLemmas != null && _includeLemmas != includeLemmas) {
      _includeLemmas = includeLemmas;
      hasChanges = true;
    }
    if (includePhrases != null && _includePhrases != includePhrases) {
      _includePhrases = includePhrases;
      hasChanges = true;
    }
    if (hasImages != null && _hasImages != hasImages) {
      _hasImages = hasImages;
      hasChanges = true;
    }
    if (hasNoImages != null && _hasNoImages != hasNoImages) {
      _hasNoImages = hasNoImages;
      hasChanges = true;
    }
    if (hasAudio != null && _hasAudio != hasAudio) {
      _hasAudio = hasAudio;
      hasChanges = true;
    }
    if (hasNoAudio != null && _hasNoAudio != hasNoAudio) {
      _hasNoAudio = hasNoAudio;
      hasChanges = true;
    }
    if (isComplete != null && _isComplete != isComplete) {
      _isComplete = isComplete;
      hasChanges = true;
    }
    if (isIncomplete != null && _isIncomplete != isIncomplete) {
      _isIncomplete = isIncomplete;
      hasChanges = true;
    }
    
    if (hasChanges) {
      notifyListeners();
      // Don't call loadNewCards() here - only update when Generate Workout button is pressed
    }
  }
  
  /// Get effective topic IDs to pass to API
  List<int>? getEffectiveTopicIds() {
    if (_selectedTopicIds.isEmpty) {
      return null;
    }
    return _selectedTopicIds.toList();
  }
  
  /// Get effective levels to pass to API
  List<String>? getEffectiveLevels() {
    if (_selectedLevels.isEmpty || _selectedLevels.length == 6) {
      return null; // All levels selected
    }
    return _selectedLevels.toList();
  }
  
  /// Get effective part of speech to pass to API
  List<String>? getEffectivePartOfSpeech() {
    final allPOS = FilterConstants.partOfSpeechValues.toSet();
    if (_selectedPartOfSpeech.isEmpty || 
        (_selectedPartOfSpeech.length == allPOS.length && 
         _selectedPartOfSpeech.containsAll(allPOS))) {
      return null; // All POS selected
    }
    return _selectedPartOfSpeech.toList();
  }
  
  /// Get effective has_images filter (1, 0, or null)
  int? getEffectiveHasImages() {
    if (_hasImages && _hasNoImages) return null; // Include all
    if (_hasImages && !_hasNoImages) return 1; // Only with images
    if (!_hasImages && _hasNoImages) return 0; // Only without images
    return null; // Both false means include all
  }
  
  /// Get effective has_audio filter (1, 0, or null)
  int? getEffectiveHasAudio() {
    if (_hasAudio && _hasNoAudio) return null; // Include all
    if (_hasAudio && !_hasNoAudio) return 1; // Only with audio
    if (!_hasAudio && _hasNoAudio) return 0; // Only without audio
    return null; // Both false means include all
  }
  
  /// Get effective is_complete filter (1, 0, or null)
  int? getEffectiveIsComplete() {
    if (_isComplete && _isIncomplete) return null; // Include all
    if (_isComplete && !_isIncomplete) return 1; // Only complete
    if (!_isComplete && _isIncomplete) return 0; // Only incomplete
    return null; // Both false means include all
  }
  
  /// Load new cards based on current filters
  Future<void> loadNewCards({bool isRefresh = false}) async {
    if (_currentUser == null || _learningLanguage == null) {
      _isLoading = false;
      _isRefreshing = false;
      _errorMessage = 'Please set your learning language in Profile settings';
      notifyListeners();
      return;
    }
    
    if (isRefresh) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Get new cards directly with filter parameters
      // The endpoint handles:
      // - Filtering concepts using dictionary logic
      // - Filtering to concepts with lemmas in both native and learning languages
      // - Filtering to concepts without cards for user in learning language
      // - Randomly selecting max_n concepts
      final result = await LearnService.getNewCards(
        userId: _currentUser!.id,
        language: _learningLanguage!,
        nativeLanguage: _currentUser!.langNative,
        maxN: _cardsToLearn,
        includeLemmas: _includeLemmas,
        includePhrases: _includePhrases,
        topicIds: getEffectiveTopicIds(),
        includeWithoutTopic: _showLemmasWithoutTopic,
        levels: getEffectiveLevels(),
        partOfSpeech: getEffectivePartOfSpeech(),
        hasImages: getEffectiveHasImages(),
        hasAudio: getEffectiveHasAudio(),
        isComplete: getEffectiveIsComplete(),
      );
      
      _isLoading = false;
      _isRefreshing = false;
      
      if (result['success'] == true) {
        final conceptsList = result['concepts'] as List<dynamic>?;
        _concepts = conceptsList?.map((concept) => concept as Map<String, dynamic>).toList() ?? [];
        _nativeLanguage = result['native_language'] as String?;
        _totalConceptsCount = result['total_concepts_count'] as int? ?? 0;
        _filteredConceptsCount = result['filtered_concepts_count'] as int? ?? 0;
        _conceptsWithBothLanguagesCount = result['concepts_with_both_languages_count'] as int? ?? 0;
        _conceptsWithoutCardsCount = result['concepts_without_cards_count'] as int? ?? 0;
        _errorMessage = null;
        
        // Generate exercises from concepts
        _exercises = ExerciseGeneratorService.generateExercises(_concepts);
        
        // If no concepts found, show helpful message
        if (_concepts.isEmpty) {
          _errorMessage = 'No new cards found matching the current filters. Try adjusting your filters or ensure you have concepts with lemmas in both your native and learning languages that you haven\'t learned yet.';
        }
        
        // Reset lesson state when new cards are loaded
        _isLessonActive = false;
        _currentLessonIndex = 0;
        _showReportCard = false;
        _exercisePerformances.clear();
        _exerciseStartTimes.clear();
      } else {
        _concepts = [];
        _exercises = [];
        _nativeLanguage = null;
        _totalConceptsCount = 0;
        _filteredConceptsCount = 0;
        _conceptsWithBothLanguagesCount = 0;
        _conceptsWithoutCardsCount = 0;
        _errorMessage = result['message'] as String? ?? 'Failed to load new cards';
        // Reset lesson state on error
        _isLessonActive = false;
        _currentLessonIndex = 0;
        _showReportCard = false;
        _exercisePerformances.clear();
        _exerciseStartTimes.clear();
      }
    } catch (e) {
      _isLoading = false;
      _isRefreshing = false;
      _concepts = [];
      _exercises = [];
      _errorMessage = 'Error loading new cards: ${e.toString()}';
    }
    
    notifyListeners();
  }
  
  /// Refresh the data
  Future<void> refresh() async {
    await _loadCurrentUser();
    if (_currentUser != null && _currentUser!.langLearning != null && _currentUser!.langLearning!.isNotEmpty) {
      _learningLanguage = _currentUser!.langLearning;
    }
    await loadNewCards(isRefresh: true);
  }
  
  /// Start the lesson
  void startLesson() {
    if (_exercises.isNotEmpty) {
      _isLessonActive = true;
      _currentLessonIndex = 0;
      _showReportCard = false;
      _exercisePerformances.clear();
      _exerciseStartTimes.clear();
      notifyListeners();
    }
  }
  
  /// Navigate to next exercise
  void nextCard() {
    if (_currentLessonIndex < _exercises.length - 1) {
      _currentLessonIndex++;
      notifyListeners();
    }
  }
  
  /// Navigate to previous exercise
  void previousCard() {
    if (_currentLessonIndex > 0) {
      _currentLessonIndex--;
      notifyListeners();
    }
  }
  
  /// Finish the lesson (completed normally - shows report card)
  void finishLesson() {
    _showReportCard = true;
    _isLessonActive = false;
    _currentLessonIndex = 0;
    notifyListeners();
  }
  
  /// Dismiss the lesson early (does not show report card)
  void dismissLesson() {
    _showReportCard = false;
    _isLessonActive = false;
    _currentLessonIndex = 0;
    _exercisePerformances.clear();
    _exerciseStartTimes.clear();
    notifyListeners();
  }
  
  /// Dismiss the report card and return to lesson start screen
  void dismissReportCard() {
    _showReportCard = false;
    notifyListeners();
  }
  
  /// Start tracking an exercise
  void startExerciseTracking(Exercise exercise) {
    // Only track interactive exercises (not discovery or summary)
    if (exercise.type == ExerciseType.discovery || exercise.type == ExerciseType.summary) {
      return;
    }
    
    // Don't track if already started
    if (_exerciseStartTimes.containsKey(exercise.id)) {
      return;
    }
    
    _exerciseStartTimes[exercise.id] = DateTime.now();
  }
  
  /// Get the full image URL from a relative path
  String? _getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    
    // Build base URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    } else {
      // Otherwise, prepend the API base URL
      final cleanUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
      return '${ApiConfig.baseUrl}/$cleanUrl';
    }
  }

  /// Complete tracking an exercise
  void completeExerciseTracking(
    Exercise exercise,
    ExerciseOutcome outcome, {
    int? hintCount,
    String? failureReason,
  }) {
    // Only track interactive exercises (not discovery or summary)
    if (exercise.type == ExerciseType.discovery || exercise.type == ExerciseType.summary) {
      return;
    }
    
    final startTime = _exerciseStartTimes[exercise.id];
    // Clear the start time so if the exercise is done again, it gets a fresh start time
    _exerciseStartTimes.remove(exercise.id);
    
    final endTime = DateTime.now();
    final actualStartTime = startTime ?? endTime;
    final conceptId = exercise.concept['id'] ?? exercise.concept['concept_id'];
    
    // Get concept term/translation from learning_lemma
    String? conceptTerm;
    int? learningLemmaId;
    String? learningAudioPath;
    String? learningLanguageCode;
    String? learningTerm;
    
    final learningLemma = exercise.concept['learning_lemma'] as Map<String, dynamic>?;
    if (learningLemma != null) {
      conceptTerm = learningLemma['translation'] as String?;
      learningLemmaId = learningLemma['id'] as int?;
      learningAudioPath = learningLemma['audio_path'] as String?;
      learningLanguageCode = learningLemma['language_code'] as String?;
      learningTerm = learningLemma['translation'] as String?;
    }
    // Fallback to concept term if translation not available
    if (conceptTerm == null || conceptTerm.isEmpty) {
      conceptTerm = exercise.concept['term'] as String?;
    }
    
    // Get concept image URL
    final imageUrl = exercise.concept['image_url'] as String?;
    final conceptImageUrl = _getImageUrl(imageUrl);
    
    // Always add a new performance entry to track each completion separately
    // This allows tracking multiple completions of the same exercise
    final performance = ExercisePerformance(
      exerciseId: exercise.id,
      conceptId: conceptId,
      exerciseType: exercise.type,
      conceptTerm: conceptTerm,
      conceptImageUrl: conceptImageUrl,
      learningLemmaId: learningLemmaId,
      learningAudioPath: learningAudioPath,
      learningLanguageCode: learningLanguageCode,
      learningTerm: learningTerm,
      startTime: actualStartTime,
      endTime: endTime,
      outcome: outcome,
      hintCount: hintCount ?? 0,
      failureReason: failureReason,
    );
    
    // Add new performance (don't update existing, track each completion separately)
    _exercisePerformances.add(performance);
    
    notifyListeners();
  }
  
  /// Update the number of cards to learn (without loading cards)
  void setCardsToLearn(int count) {
    if (count != _cardsToLearn && count > 0) {
      _cardsToLearn = count;
      notifyListeners();
    }
  }
  
  /// Generate workout with specified parameters
  Future<void> generateWorkout({
    required int cardsToLearn,
    required bool includeNewCards,
    required bool includeLearnedCards,
  }) async {
    _cardsToLearn = cardsToLearn;
    // TODO: Implement includeLearnedCards support in backend if needed
    // For now, we only support new cards (which is what the endpoint returns)
    await loadNewCards();
  }
}

