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
  bool _includeLemmas = true;
  bool _includePhrases = true;
  bool _hasImages = true;
  bool _hasNoImages = true;
  bool _hasAudio = true;
  bool _hasNoAudio = true;
  bool _isComplete = true;
  bool _isIncomplete = true;

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
  }

  // Convert to API parameters
  int? get hasImagesParam => _hasImages && !_hasNoImages ? 1 : (!_hasImages && _hasNoImages ? 0 : null);
  int? get hasAudioParam => _hasAudio && !_hasNoAudio ? 1 : (!_hasAudio && _hasNoAudio ? 0 : null);
  int? get isCompleteParam => _isComplete && !_isIncomplete ? 1 : (!_isComplete && _isIncomplete ? 0 : null);
  List<int>? get topicIdsParam => _selectedTopicIds.isEmpty ? null : _selectedTopicIds.toList();
  List<String>? get levelsParam => _selectedLevels.length == 6 ? null : _selectedLevels.toList();
  List<String>? get partOfSpeechParam => _selectedPartOfSpeech.length == 10 ? null : _selectedPartOfSpeech.toList();
}

