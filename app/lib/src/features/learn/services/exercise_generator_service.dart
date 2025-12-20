import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Service that generates exercises from concepts
class ExerciseGeneratorService {
  /// Generate all exercises for a list of concepts
  /// Exercises are grouped by type: all discoveries first, then all matches, then scaffolds, then produces
  static List<Exercise> generateExercises(List<Map<String, dynamic>> concepts) {
    final List<Exercise> exercises = [];

    // Generate exercises grouped by type: Discovery -> Match -> Scaffold -> Produce
    for (final type in ExerciseType.values) {
      // For each type, generate an exercise for each concept
      for (final concept in concepts) {
        final exerciseId = '${concept['id']}_${type.name}';
        exercises.add(
          Exercise(
            id: exerciseId,
            type: type,
            concept: concept,
            exerciseData: _generateExerciseData(type, concept),
          ),
        );
      }
    }

    return exercises;
  }

  /// Generate type-specific exercise data
  static Map<String, dynamic>? _generateExerciseData(
    ExerciseType type,
    Map<String, dynamic> concept,
  ) {
    switch (type) {
      case ExerciseType.discovery:
        // Discovery doesn't need additional data
        return null;
      case ExerciseType.match:
        // Match exercise data will be generated when implementing Match
        return null;
      case ExerciseType.scaffold:
        // Scaffold exercise data will be generated when implementing Scaffold
        return null;
      case ExerciseType.produce:
        // Produce exercise data will be generated when implementing Produce
        return null;
    }
  }
}

