import 'package:archipelago/src/common_widgets/filter_interface.dart';

/// Filter state for profile statistics.
class ProfileFilterState implements FilterState {
  Set<int> _selectedTopicIds = {};
  bool _showLemmasWithoutTopic = true;
  Set<String> _selectedLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};
  Set<String> _selectedPartOfSpeech = {
    'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition',
    'Conjunction', 'Determiner / Article', 'Interjection', 'Numeral'
  };
  bool _includeLemmas = false;
  bool _includePhrases = true;
  bool _hasImages = true;
  bool _hasNoImages = true;
  bool _hasAudio = true;
  bool _hasNoAudio = true;
  bool _isComplete = true;
  bool _isIncomplete = true;
  Set<int> _selectedLeitnerBins = {}; // Will be initialized with all bins (1 to maxBins)
  Set<String> _selectedLearningStatus = {'new', 'due', 'learned'}; // All enabled by default

  // Getters
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

  @override
  Set<int> get selectedLeitnerBins => _selectedLeitnerBins;

  @override
  Set<String> get selectedLearningStatus => _selectedLearningStatus;

  // Setters
  void updateFilters({
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
    Set<int>? leitnerBins,
    Set<String>? learningStatus,
  }) {
    if (topicIds != null) _selectedTopicIds = topicIds;
    if (showLemmasWithoutTopic != null) _showLemmasWithoutTopic = showLemmasWithoutTopic;
    if (levels != null) _selectedLevels = levels;
    if (partOfSpeech != null) _selectedPartOfSpeech = partOfSpeech;
    if (includeLemmas != null) _includeLemmas = includeLemmas;
    if (includePhrases != null) _includePhrases = includePhrases;
    if (hasImages != null) _hasImages = hasImages;
    if (hasNoImages != null) _hasNoImages = hasNoImages;
    if (hasAudio != null) _hasAudio = hasAudio;
    if (hasNoAudio != null) _hasNoAudio = hasNoAudio;
    if (isComplete != null) _isComplete = isComplete;
    if (isIncomplete != null) _isIncomplete = isIncomplete;
    if (leitnerBins != null) _selectedLeitnerBins = leitnerBins;
    if (learningStatus != null) _selectedLearningStatus = learningStatus;
  }

  // Convert to API parameters
  int? get hasImagesParam => _hasImages && !_hasNoImages ? 1 : (!_hasImages && _hasNoImages ? 0 : null);
  int? get hasAudioParam => _hasAudio && !_hasNoAudio ? 1 : (!_hasAudio && _hasNoAudio ? 0 : null);
  int? get isCompleteParam => _isComplete && !_isIncomplete ? 1 : (!_isComplete && _isIncomplete ? 0 : null);
  List<int>? get topicIdsParam => _selectedTopicIds.isEmpty ? null : _selectedTopicIds.toList();
  List<String>? get levelsParam => _selectedLevels.length == 6 ? null : _selectedLevels.toList();
  List<String>? get partOfSpeechParam => _selectedPartOfSpeech.length == 10 ? null : _selectedPartOfSpeech.toList();

  /// Get effective leitner_bins filter (comma-separated string, or null if all bins selected)
  /// Optimization: Returns null if all bins (1 to maxBins) are selected to skip backend joins
  String? getLeitnerBinsParam(int maxBins) {
    if (_selectedLeitnerBins.isEmpty) return null; // All bins selected (empty set means all)
    
    // Generate all bins from 1 to maxBins
    final allBins = Set<int>.from(List.generate(maxBins, (index) => index + 1));
    
    // If all bins (1 to maxBins) are selected, return null (no filtering)
    if (_selectedLeitnerBins.length == allBins.length && 
        _selectedLeitnerBins.containsAll(allBins)) {
      return null; // All bins selected
    }
    
    final sortedBins = _selectedLeitnerBins.toList()..sort();
    return sortedBins.join(',');
  }
  
  /// Initialize all bins (1 to maxBins) if empty
  void initializeBinsIfEmpty(int maxBins) {
    if (_selectedLeitnerBins.isEmpty) {
      _selectedLeitnerBins = Set<int>.from(List.generate(maxBins, (index) => index + 1));
    }
  }

  /// Get effective learning_status filter (comma-separated string, or null if all statuses selected)
  /// Optimization: Returns null if all statuses are selected to skip backend joins
  String? getLearningStatusParam() {
    final allStatuses = {'new', 'due', 'learned'};
    if (_selectedLearningStatus.isEmpty) return null; // All statuses selected (empty set means all)
    if (_selectedLearningStatus.length == allStatuses.length &&
        _selectedLearningStatus.containsAll(allStatuses)) {
      return null; // All statuses selected
    }
    final sortedStatuses = _selectedLearningStatus.toList()..sort();
    return sortedStatuses.join(',');
  }
}

