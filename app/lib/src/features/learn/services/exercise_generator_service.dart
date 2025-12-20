import 'dart:math';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Service that generates exercises from concepts
class ExerciseGeneratorService {
  /// Generate all exercises for a list of concepts
  /// 
  /// Generates the following exercises for ALL concepts:
  /// - Discovery: one exercise per concept
  /// - Summary: one exercise for all concepts combined
  /// - Match Info Image (info to image): one exercise per concept
  /// - Match Image Info (image to info): one exercise per concept
  /// - Match Audio Image (audio to image): one exercise per concept
  /// - Match Image Audio (image to audio): one exercise per concept
  /// - Scaffold: one exercise per concept
  /// - Produce: one exercise per concept
  /// 
  /// Exercises are grouped by type: all discoveries first, then summary, then match_info_image, match_audio_image, match_image_info, match_image_audio, then scaffolds, then produces
  /// Cards are shuffled per exercise type, and images are shuffled once for all match exercises
  static List<Exercise> generateExercises(List<Map<String, dynamic>> concepts) {
    final List<Exercise> exercises = [];
    final random = Random();

    // Create a shuffled list of all concepts for match exercises (same shuffle for all match cards)
    final shuffledConceptsForMatch = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForMatch.shuffle(random);

    // Generate exercises in specific order: Discovery -> Summary -> Match Info Image -> Match Audio Image -> Match Image Info -> Match Image Audio -> Scaffold -> Produce
    
    // 1. Discovery exercises
    final shuffledConceptsForDiscovery = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForDiscovery.shuffle(random);
    for (final concept in shuffledConceptsForDiscovery) {
      final exerciseId = '${concept['id']}_${ExerciseType.discovery.name}';
      exercises.add(
        Exercise(
          id: exerciseId,
          type: ExerciseType.discovery,
          concept: concept,
          exerciseData: _generateExerciseData(ExerciseType.discovery, concept, concepts, shuffledConceptsForMatch),
        ),
      );
    }

    // 2. Summary exercise (once after all discoveries)
    exercises.add(
      Exercise(
        id: 'summary_all_concepts',
        type: ExerciseType.summary,
        concept: {}, // Empty concept for summary
        exerciseData: {'all_concepts': concepts},
      ),
    );

    // 3. Match Info Image exercises
    final shuffledConceptsForMatchInfoImage = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForMatchInfoImage.shuffle(random);
    for (final concept in shuffledConceptsForMatchInfoImage) {
      final exerciseId = '${concept['id']}_${ExerciseType.matchInfoImage.name}';
      exercises.add(
        Exercise(
          id: exerciseId,
          type: ExerciseType.matchInfoImage,
          concept: concept,
          exerciseData: _generateExerciseData(ExerciseType.matchInfoImage, concept, concepts, shuffledConceptsForMatch),
        ),
      );
    }

    // 4. Match Image Info exercises
    final shuffledConceptsForMatchImageInfo = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForMatchImageInfo.shuffle(random);
    for (final concept in shuffledConceptsForMatchImageInfo) {
      final exerciseId = '${concept['id']}_${ExerciseType.matchImageInfo.name}';
      exercises.add(
        Exercise(
          id: exerciseId,
          type: ExerciseType.matchImageInfo,
          concept: concept,
          exerciseData: _generateExerciseData(ExerciseType.matchImageInfo, concept, concepts, shuffledConceptsForMatch),
        ),
      );
    }

    // 5. Match Audio Image exercises
    final shuffledConceptsForMatchAudioImage = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForMatchAudioImage.shuffle(random);
    for (final concept in shuffledConceptsForMatchAudioImage) {
      final exerciseId = '${concept['id']}_${ExerciseType.matchAudioImage.name}';
      exercises.add(
        Exercise(
          id: exerciseId,
          type: ExerciseType.matchAudioImage,
          concept: concept,
          exerciseData: _generateExerciseData(ExerciseType.matchAudioImage, concept, concepts, shuffledConceptsForMatch),
        ),
      );
    }

    // 6. Match Image Audio exercises
    final shuffledConceptsForMatchImageAudio = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForMatchImageAudio.shuffle(random);
    for (final concept in shuffledConceptsForMatchImageAudio) {
      final exerciseId = '${concept['id']}_${ExerciseType.matchImageAudio.name}';
      exercises.add(
        Exercise(
          id: exerciseId,
          type: ExerciseType.matchImageAudio,
          concept: concept,
          exerciseData: _generateExerciseData(ExerciseType.matchImageAudio, concept, concepts, shuffledConceptsForMatch),
        ),
      );
    }

    // 7. Scaffold exercises
    final shuffledConceptsForScaffold = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForScaffold.shuffle(random);
    for (final concept in shuffledConceptsForScaffold) {
      final exerciseId = '${concept['id']}_${ExerciseType.scaffold.name}';
      exercises.add(
        Exercise(
          id: exerciseId,
          type: ExerciseType.scaffold,
          concept: concept,
          exerciseData: _generateExerciseData(ExerciseType.scaffold, concept, concepts, shuffledConceptsForMatch),
        ),
      );
    }

    // 8. Produce exercises
    final shuffledConceptsForProduce = List<Map<String, dynamic>>.from(concepts);
    shuffledConceptsForProduce.shuffle(random);
    for (final concept in shuffledConceptsForProduce) {
      final exerciseId = '${concept['id']}_${ExerciseType.produce.name}';
      exercises.add(
        Exercise(
          id: exerciseId,
          type: ExerciseType.produce,
          concept: concept,
          exerciseData: _generateExerciseData(ExerciseType.produce, concept, concepts, shuffledConceptsForMatch),
        ),
      );
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
      case ExerciseType.summary:
        // Summary exercise needs all concepts to show in grid
        return {'all_concepts': allConcepts};
      case ExerciseType.matchInfoImage:
        // MatchInfoImage exercise needs all concepts to show the image grid
        // Use the pre-shuffled list to keep the same image order across all matchInfoImage cards
        return {'all_concepts': shuffledConceptsForMatch};
      case ExerciseType.matchAudioImage:
        // MatchAudioImage exercise needs all concepts to show the image grid
        // Use the pre-shuffled list to keep the same image order across all matchAudioImage cards
        return {'all_concepts': shuffledConceptsForMatch};
      case ExerciseType.matchImageInfo:
        // MatchImageInfo exercise needs all concepts to show as selectable cards
        // Use the pre-shuffled list to keep the same order across all matchImageInfo cards
        return {'all_concepts': shuffledConceptsForMatch};
      case ExerciseType.matchImageAudio:
        // MatchImageAudio exercise needs all concepts to show as selectable cards
        // Use the pre-shuffled list to keep the same order across all matchImageAudio cards
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

