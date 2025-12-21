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
  /// Randomization:
  /// - Each exercise type gets its own shuffled concept list (for per-concept exercises)
  /// - Each match exercise card gets its own shuffled option list for random option ordering
  static List<Exercise> generateExercises(List<Map<String, dynamic>> concepts) {
    final List<Exercise> exercises = [];
    final random = Random();

    // Generate exercises based on configuration
    for (final configEntry in ExerciseConfig.exercises) {
      if (configEntry.perConcept) {
        // Generate one exercise per concept, with concepts shuffled for this exercise type
        final shuffledConcepts = List<Map<String, dynamic>>.from(concepts);
        shuffledConcepts.shuffle(random);
        
        for (final concept in shuffledConcepts) {
          // For match exercises, create a new shuffled list of options for each card
          final shuffledOptions = _isMatchExercise(configEntry.type)
              ? (List<Map<String, dynamic>>.from(concepts)..shuffle(random))
              : null;
          
          final exerciseId = '${concept['id']}_${configEntry.type.name}';
          exercises.add(
            Exercise(
              id: exerciseId,
              type: configEntry.type,
              concept: concept,
              exerciseData: _generateExerciseData(
                configEntry.type,
                concept,
                concepts,
                shuffledOptions,
              ),
            ),
          );
        }
      } else {
        // Generate a single exercise for all concepts (e.g., summary)
        exercises.add(
          Exercise(
            id: '${configEntry.type.name}_all_concepts',
            type: configEntry.type,
            concept: {}, // Empty concept for summary-type exercises
            exerciseData: _generateExerciseData(
              configEntry.type,
              {},
              concepts,
              null, // Summary doesn't need shuffled options
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
        return null;
      case ExerciseType.produce:
        // Produce exercise data will be generated when implementing Produce
        return null;
      case ExerciseType.closeExercise:
        // CloseExercise doesn't need additional data, uses concept's learning_lemma
        return null;
    }
  }
}

