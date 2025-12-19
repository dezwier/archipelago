/// Interface for filter state that can be used with the generic filter sheet
abstract class FilterState {
  Set<int> get selectedTopicIds;
  bool get showLemmasWithoutTopic;
  Set<String> get selectedLevels;
  Set<String> get selectedPartOfSpeech;
  bool get includeLemmas;
  bool get includePhrases;
  bool get hasImages;
  bool get hasNoImages;
  bool get hasAudio;
  bool get hasNoAudio;
  bool get isComplete;
  bool get isIncomplete;
}

/// Callback interface for applying filter changes
typedef FilterUpdateCallback = void Function({
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
});

