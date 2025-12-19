import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:archipelago/src/common_widgets/filter_interface.dart';
import 'package:archipelago/src/features/learn/data/learn_service.dart';
import 'package:archipelago/src/features/learn/data/concept_filter_service.dart';

class LearnController extends ChangeNotifier implements FilterState {
  User? _currentUser;
  List<Map<String, dynamic>> _concepts = []; // List of concepts, each with learning_lemma and native_lemma
  bool _isLoading = true;
  String? _errorMessage;
  String? _learningLanguage;
  String? _nativeLanguage;
  
  // Filter state
  Set<int> _selectedTopicIds = {};
  bool _showLemmasWithoutTopic = true;
  Set<String> _selectedLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};
  Set<String> _selectedPartOfSpeech = {
    'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
    'Conjunction', 'Determiner / Article', 'Interjection'
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
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get learningLanguage => _learningLanguage;
  String? get nativeLanguage => _nativeLanguage;
  
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
  
  /// Batch update filters and reload cards
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
      loadNewCards();
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
    if (_selectedPartOfSpeech.isEmpty || _selectedPartOfSpeech.length == 9) {
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
  Future<void> loadNewCards() async {
    if (_currentUser == null || _learningLanguage == null) {
      _isLoading = false;
      _errorMessage = 'Please set your learning language in Profile settings';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // First, get filtered lemma IDs from concepts
      final filterResult = await ConceptFilterService.getFilteredLemmaIds(
        userId: _currentUser!.id,
        targetLanguage: _learningLanguage!,
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
      
      if (filterResult['success'] != true) {
        _isLoading = false;
        _errorMessage = filterResult['message'] as String? ?? 'Failed to filter concepts';
        notifyListeners();
        return;
      }
      
      final lemmaIds = filterResult['lemmaIds'] as List<dynamic>?;
      final lemmaIdList = lemmaIds?.map((id) => id as int).toList() ?? [];
      
      // If no lemma IDs found, show helpful message
      if (lemmaIdList.isEmpty) {
        _isLoading = false;
        _concepts = [];
        _errorMessage = 'No lemmas found matching the current filters. Try adjusting your filters or ensure you have concepts with lemmas in your learning language.';
        notifyListeners();
        return;
      }
      
      // Then get new cards for these lemmas (randomly select max 10)
      final result = await LearnService.getNewCards(
        userId: _currentUser!.id,
        language: _learningLanguage!,
        nativeLanguage: _currentUser!.langNative,
        lemmaIds: lemmaIdList,
        maxN: 10,
      );
      
      _isLoading = false;
      
      if (result['success'] == true) {
        final conceptsList = result['concepts'] as List<dynamic>?;
        _concepts = conceptsList?.map((concept) => concept as Map<String, dynamic>).toList() ?? [];
        _nativeLanguage = result['native_language'] as String?;
        _errorMessage = null;
      } else {
        _concepts = [];
        _nativeLanguage = null;
        _errorMessage = result['message'] as String? ?? 'Failed to load new cards';
      }
    } catch (e) {
      _isLoading = false;
      _concepts = [];
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
    await loadNewCards();
  }
}

