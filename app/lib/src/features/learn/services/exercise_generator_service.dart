import 'dart:math';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Service that generates exercises from concepts
class ExerciseGeneratorService {
  /// Generate all exercises for a list of concepts
  /// Exercises are grouped by type: all discoveries first, then all matches, then scaffolds, then produces
  /// Cards are shuffled per exercise type, and images are shuffled once for all match exercises
  static List<Exercise> generateExercises(List<Map<String, dynamic>> concepts) {
    final List<Exercise> exercises = [];
    final random = Random();

    // Create a shuffled list of all concepts for match exercises (same shuffle for all match cards)
    final shuffledConceptsForMatch = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForMatch.shuffle(random);

    // Generate exercises grouped by type: Discovery -> Match -> Scaffold -> Produce
    for (final type in ExerciseType.values) {
      // Shuffle concepts for this exercise type to randomize card order
      final shuffledConcepts = List<Map<String, dynamic>>.from(concepts);
      shuffledConcepts.shuffle(random);

      // For each type, generate an exercise for each concept (in shuffled order)
      for (final concept in shuffledConcepts) {
        final exerciseId = '${concept['id']}_${type.name}';
        exercises.add(
          Exercise(
            id: exerciseId,
            type: type,
            concept: concept,
            exerciseData: _generateExerciseData(type, concept, concepts, shuffledConceptsForMatch),
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
    List<Map<String, dynamic>> allConcepts,
    List<Map<String, dynamic>> shuffledConceptsForMatch,
  ) {
    switch (type) {
      case ExerciseType.discovery:
        // Discovery doesn't need additional data
        return null;
      case ExerciseType.match:
        // Match exercise needs all concepts to show the image grid
        // Use the pre-shuffled list to keep the same image order across all match cards
        return {'all_concepts': shuffledConceptsForMatch};
      case ExerciseType.scaffold:
        // Scaffold exercise data will be generated when implementing Scaffold
        return null;
      case ExerciseType.produce:
        // Produce exercise data will be generated when implementing Produce
        return null;
    }
  }
}

