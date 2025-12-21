import 'dart:math';
import 'package:archipelago/src/features/learn/config/exercise_config.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Service that generates exercises from concepts
class ExerciseGeneratorService {
  /// Generate all exercises for a list of concepts
  /// 
  /// Uses ExerciseConfig to determine which exercises to generate.
  /// Exercises are generated in the order specified by the configuration.
  /// 
  /// Generation order: All exercises of each type are generated together before moving to the next type.
  /// For example: all discoveries, then summary, then all matches, etc.
  /// 
  /// Randomization:
  /// - Each exercise type gets its own shuffled concept list (for per-concept exercises)
  /// - Each match exercise card gets its own shuffled option list for random option ordering
  /// - If randomizeSelection is enabled, randomly select exercises per concept
  /// - If randomizeOrdering is enabled, shuffle exercise order per concept
  static List<Exercise> generateExercises(List<Map<String, dynamic>> concepts) {
    final List<Exercise> exercises = [];
    final random = Random();

    // Generate exercises grouped by type, respecting config order
    // Loop through config entries first, then for each entry generate exercises for all concepts
    for (final configEntry in ExerciseConfig.exercises) {
      if (configEntry.perConcept) {
        // For alternatives, create a shuffled list and cycle through without replacement
        // Only reuse types when there are more concepts than available types
        List<ExerciseType>? shuffledTypes;
        int typeIndex = 0;
        
        if (configEntry.types.length > 1) {
          // Multiple types (alternatives): shuffle once and cycle through without replacement
          shuffledTypes = List<ExerciseType>.from(configEntry.types)..shuffle(random);
        }
        
        // Generate one exercise per concept for this config entry
        for (final concept in concepts) {
          // Select exercise type: 
          // - If single type (types.length == 1), always use that type for all concepts
          // - If multiple types (alternatives), cycle through shuffled list without replacement
          final selectedType = configEntry.types.length == 1
              ? configEntry.types[0]  // Single type: use it for all concepts
              : shuffledTypes![typeIndex % shuffledTypes.length];  // Alternatives: cycle without replacement
          
          // Increment index for next concept (only for alternatives)
          if (configEntry.types.length > 1) {
            typeIndex++;
          }
          
          // For match exercises, create a new shuffled list of options for each card
          final shuffledOptions = _isMatchExercise(selectedType)
              ? (List<Map<String, dynamic>>.from(concepts)..shuffle(random))
              : null;
          
          final exerciseId = '${concept['id']}_${selectedType.name}';
          exercises.add(
            Exercise(
              id: exerciseId,
              type: selectedType,
              concept: concept,
              exerciseData: _generateExerciseData(
                selectedType,
                concept,
                concepts,
                shuffledOptions,
                configEntry.parameters,
              ),
            ),
          );
        }
      } else {
        // Generate one exercise for all concepts (e.g., summary)
        // Select exercise type: if multiple types, randomly select one
        final selectedType = configEntry.types.length == 1
            ? configEntry.types[0]
            : configEntry.types[random.nextInt(configEntry.types.length)];
        
        exercises.add(
          Exercise(
            id: '${selectedType.name}_all_concepts',
            type: selectedType,
            concept: {}, // Empty concept for summary-type exercises
            exerciseData: _generateExerciseData(
              selectedType,
              {},
              concepts,
              null, // Summary doesn't need shuffled options
              configEntry.parameters,
            ),
          ),
        );
      }
    }

    return exercises;
  }

  /// Check if an exercise type is a match exercise that needs shuffled options
  static bool _isMatchExercise(ExerciseType type) {
    return type == ExerciseType.matchInfoImage ||
        type == ExerciseType.matchAudioImage ||
        type == ExerciseType.matchImageInfo ||
        type == ExerciseType.matchImageAudio ||
        type == ExerciseType.matchPhraseDescription ||
        type == ExerciseType.matchDescriptionPhrase;
  }

  /// Generate type-specific exercise data
  static Map<String, dynamic>? _generateExerciseData(
    ExerciseType type,
    Map<String, dynamic> concept,
    List<Map<String, dynamic>> allConcepts,
    List<Map<String, dynamic>>? shuffledOptions,
    Map<String, dynamic>? parameters,
  ) {
    switch (type) {
      case ExerciseType.discovery:
        // Discovery doesn't need additional data
        return null;
      case ExerciseType.summary:
        // Summary exercise needs all concepts to show in grid
        return {'all_concepts': allConcepts};
      case ExerciseType.matchInfoImage:
        // MatchInfoImage exercise needs all concepts to show the image grid
        // Each card gets its own shuffled list for random option ordering
        return {'all_concepts': shuffledOptions ?? allConcepts};
      case ExerciseType.matchAudioImage:
        // MatchAudioImage exercise needs all concepts to show the image grid
        // Each card gets its own shuffled list for random option ordering
        return {'all_concepts': shuffledOptions ?? allConcepts};
      case ExerciseType.matchImageInfo:
        // MatchImageInfo exercise needs all concepts to show as selectable cards
        // Each card gets its own shuffled list for random option ordering
        return {'all_concepts': shuffledOptions ?? allConcepts};
      case ExerciseType.matchImageAudio:
        // MatchImageAudio exercise needs all concepts to show as selectable cards
        // Each card gets its own shuffled list for random option ordering
        return {'all_concepts': shuffledOptions ?? allConcepts};
      case ExerciseType.matchPhraseDescription:
        // MatchPhraseDescription exercise needs all concepts to show as selectable cards
        // Each card gets its own shuffled list for random option ordering
        return {'all_concepts': shuffledOptions ?? allConcepts};
      case ExerciseType.matchDescriptionPhrase:
        // MatchDescriptionPhrase exercise needs all concepts to show as selectable cards
        // Each card gets its own shuffled list for random option ordering
        return {'all_concepts': shuffledOptions ?? allConcepts};
      case ExerciseType.scaffoldFromImage:
        // ScaffoldFromImage doesn't need additional data, uses concept's learning_lemma
        return parameters;
      case ExerciseType.closeExercise:
        // CloseExercise uses concept's learning_lemma and optional parameters (minBlanks, maxBlanks)
        return parameters;
    }
  }
}

