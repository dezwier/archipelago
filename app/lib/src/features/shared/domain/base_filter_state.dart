import 'package:archipelago/src/common_widgets/filter_interface.dart';

/// Mixin that provides common filter logic implementations.
/// Controllers and filter state classes can use this mixin for consistent filter behavior.
/// 
/// Classes using this mixin must implement FilterState interface.
mixin BaseFilterStateMixin implements FilterState {
  // These should be implemented by subclasses
  @override
  Set<int> get selectedTopicIds;
  
  @override
  bool get showLemmasWithoutTopic;
  
  @override
  Set<String> get selectedLevels;
  
  @override
  Set<String> get selectedPartOfSpeech;
  
  @override
  bool get includeLemmas;
  
  @override
  bool get includePhrases;
  
  @override
  bool get hasImages;
  
  @override
  bool get hasNoImages;
  
  @override
  bool get hasAudio;
  
  @override
  bool get hasNoAudio;
  
  @override
  bool get isComplete;
  
  @override
  bool get isIncomplete;
  
  @override
  Set<int> get selectedLeitnerBins;
  
  @override
  Set<String> get selectedLearningStatus;

  /// Get effective has_images filter (1, 0, or null)
  /// Returns: 1 = include only concepts with images, 0 = include only concepts without images, null = include all
  int? getEffectiveHasImages() {
    if (hasImages && !hasNoImages) {
      return 1; // Only "Has Images" selected -> include only concepts with images
    } else if (!hasImages && hasNoImages) {
      return 0; // Only "Has no Images" selected -> include only concepts without images
    }
    // Both selected or neither selected -> include all
    return null;
  }

  /// Get effective has_audio filter (1, 0, or null)
  /// Returns: 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
  int? getEffectiveHasAudio() {
    if (hasAudio && !hasNoAudio) {
      return 1; // Only "Has Audio" selected -> include only concepts with audio
    } else if (!hasAudio && hasNoAudio) {
      return 0; // Only "Has no Audio" selected -> include only concepts without audio
    }
    // Both selected or neither selected -> include all
    return null;
  }

  /// Get effective is_complete filter (1, 0, or null)
  /// Returns: 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
  int? getEffectiveIsComplete() {
    if (isComplete && !isIncomplete) {
      return 1; // Only "Is Complete" selected -> include only complete concepts
    } else if (!isComplete && isIncomplete) {
      return 0; // Only "Is Incomplete" selected -> include only incomplete concepts
    }
    // Both selected or neither selected -> include all
    return null;
  }

  /// Get effective levels filter (list of level strings, or null if all selected)
  /// Optimization: Returns null if all levels are selected to skip backend filtering
  List<String>? getEffectiveLevels() {
    const allLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};
    if (selectedLevels.isEmpty || 
        (selectedLevels.length == allLevels.length && 
         selectedLevels.containsAll(allLevels))) {
      return null; // All levels selected
    }
    return selectedLevels.toList();
  }

  /// Get effective part of speech filter (list of POS strings, or null if all selected)
  /// Optimization: Returns null if all POS are selected to skip backend filtering
  List<String>? getEffectivePartOfSpeech() {
    const allPOS = {
      'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
      'Conjunction', 'Determiner / Article', 'Interjection', 'Numeral'
    };
    if (selectedPartOfSpeech.isEmpty || 
        (selectedPartOfSpeech.length == allPOS.length && 
         selectedPartOfSpeech.containsAll(allPOS))) {
      return null; // All POS selected
    }
    return selectedPartOfSpeech.toList();
  }

  /// Get effective leitner_bins filter (comma-separated string, or null if all bins selected)
  /// Optimization: Returns null if all bins (1 to maxBins) are selected to skip backend joins
  /// 
  /// [maxBins] - Maximum number of bins (from user's Leitner config)
  String? getEffectiveLeitnerBins(int maxBins) {
    if (selectedLeitnerBins.isEmpty) return null; // All bins selected (empty set means all)
    
    // Generate all bins from 1 to maxBins
    final allBins = Set<int>.from(List.generate(maxBins, (index) => index + 1));
    
    // If all bins (1 to maxBins) are selected, return null (no filtering)
    if (selectedLeitnerBins.length == allBins.length && 
        selectedLeitnerBins.containsAll(allBins)) {
      return null; // All bins selected
    }
    
    final sortedBins = selectedLeitnerBins.toList()..sort();
    return sortedBins.join(',');
  }

  /// Get effective learning_status filter (comma-separated string, or null if all statuses selected)
  /// Optimization: Returns null if all statuses are selected to skip backend joins
  String? getEffectiveLearningStatus() {
    const allStatuses = {'new', 'due', 'learned'};
    if (selectedLearningStatus.isEmpty) return null; // All statuses selected (empty set means all)
    if (selectedLearningStatus.length == allStatuses.length &&
        selectedLearningStatus.containsAll(allStatuses)) {
      return null; // All statuses selected
    }
    final sortedStatuses = selectedLearningStatus.toList()..sort();
    return sortedStatuses.join(',');
  }
}

