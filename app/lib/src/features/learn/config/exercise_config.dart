import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Configuration for exercise generation
/// 
/// Defines which exercises are included in a lesson and how they are generated.
/// This structure allows for easy modification of exercise composition and
/// can be extended in the future to support per-concept exercise selection.
class ExerciseConfig {
  /// List of exercise configurations defining which exercises to generate
  /// 
  /// Each entry specifies:
  /// - The exercise type
  /// - Whether it's generated per-concept (true) or once for all concepts (false)
  static const List<ExerciseConfigEntry> exercises = [
    // Discovery exercises: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.discovery,
      perConcept: true,
    ),
    // Summary exercise: once after all discoveries
    ExerciseConfigEntry(
      type: ExerciseType.summary,
      perConcept: false,
    ),
    // Match Info Image: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.matchInfoImage,
      perConcept: true,
    ),
    // Match Image Info: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.matchImageInfo,
      perConcept: true,
    ),
    // Match Audio Image: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.matchAudioImage,
      perConcept: true,
    ),
    // // Match Image Audio: one per concept
    // ExerciseConfigEntry(
    //   type: ExerciseType.matchImageAudio,
    //   perConcept: true,
    // ),
    // // Match Phrase Description: one per concept
    // ExerciseConfigEntry(
    //   type: ExerciseType.matchPhraseDescription,
    //   perConcept: true,
    // ),
    // // Match Description Phrase: one per concept
    // ExerciseConfigEntry(
    //   type: ExerciseType.matchDescriptionPhrase,
    //   perConcept: true,
    // ),
    // Scaffold From Image: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.scaffoldFromImage,
      perConcept: true,
    ),
  ];
}

/// Configuration entry for a single exercise type
class ExerciseConfigEntry {
  /// The type of exercise to generate
  final ExerciseType type;
  
  /// Whether this exercise should be generated per-concept (true) or once for all concepts (false)
  final bool perConcept;
  
  const ExerciseConfigEntry({
    required this.type,
    required this.perConcept,
  });
}

