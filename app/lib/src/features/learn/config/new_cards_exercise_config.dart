import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Configuration for exercise generation for new cards
/// 
/// Defines which exercises are included in a lesson and how they are generated.
/// This structure allows for easy modification of exercise composition and
/// can be extended in the future to support per-concept exercise selection.
class NewCardsExerciseConfig {
  /// Whether to randomly select exercises per concept (instead of using all configured exercises)
  /// When true, up to [maxExercisesPerConcept] exercises will be randomly selected for each concept
  static const bool randomizeSelection = false;
  
  /// Whether to randomize the order of exercises per concept
  /// When true, exercises will be shuffled for each concept independently
  static const bool randomizeOrdering = false;
  
  /// Maximum number of exercises to generate per concept when [randomizeSelection] is true
  /// If null, all configured exercises will be used (subject to randomization)
  static const int? maxExercisesPerConcept = null;
  
  /// List of exercise configurations defining which exercises to generate
  /// 
  /// Each entry specifies:
  /// - The exercise type(s) - if multiple types are provided, one is randomly selected per concept
  /// - Whether it's generated per-concept (true) or once for all concepts (false)
  /// - Optional parameters specific to the exercise type
  /// 
  /// The order of entries determines the order of exercises in the lesson.
  /// 
  /// Lesson Flow:
  /// 1. Discovery card per concept
  /// 2. Discovery summary card (once, after all discoveries)
  /// 3. Random image-based match exercise per concept (randomly selects from 4 types)
  /// 4. Random non-image match exercise per concept (randomly selects from 2 types)
  /// 5. Scaffold per concept
  /// 6. Close exercise with 33% of words missing per concept
  /// 7. Close exercise with 66% of words missing per concept
  /// 
  /// Example: To have Discovery, then randomly MatchInfoImage OR MatchAudioImage, then CloseExercise:
  /// ```
  /// ExerciseConfigEntry(type: ExerciseType.discovery, perConcept: true),
  /// ExerciseConfigEntry.alternatives(
  ///   types: [ExerciseType.matchInfoImage, ExerciseType.matchAudioImage],
  ///   perConcept: true,
  /// ),
  /// ExerciseConfigEntry(type: ExerciseType.closeExercise, perConcept: true),
  /// ```
  static final List<ExerciseConfigEntry> exercises = [
    // 1. Discovery card: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.discovery,
      perConcept: true,
    ),
    
    // 2. Discovery summary: once after all discoveries
    ExerciseConfigEntry(
      type: ExerciseType.summary,
      perConcept: false,
    ),

    // 3. Match info image: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.matchInfoImage,
      perConcept: true,
    ),

    // 4. Random other match exercise: one per concept
    const ExerciseConfigEntry.alternatives(
      types: [
        ExerciseType.matchAudioImage,
        ExerciseType.matchImageInfo,
        ExerciseType.matchImageAudio,
        ExerciseType.matchDescriptionPhrase,
        ExerciseType.matchPhraseDescription,
      ],
      perConcept: true,
    ),
    
    
    // 5. Scaffold: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.scaffoldFromImage,
      perConcept: true,
    ),
    
    // 6. Close exercise with 33% of words missing: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.closeExercise,
      perConcept: true,
      parameters: {
        'blankPercentage': 0.33,
      },
    ),
    
    // 7. Close exercise with 66% of words missing: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.closeExercise,
      perConcept: true,
      parameters: {
        'blankPercentage': 0.66,
      },
    ),
  ];
}

/// Configuration entry for a single exercise type or multiple alternatives
class ExerciseConfigEntry {
  /// The type(s) of exercise to generate
  /// If a single type is provided, it will always be used.
  /// If multiple types are provided, one will be randomly selected per concept.
  /// The order in the config list determines the position of exercises.
  final List<ExerciseType> types;
  
  /// Whether this exercise should be generated per-concept (true) or once for all concepts (false)
  final bool perConcept;
  
  /// Optional parameters specific to this exercise type
  /// These parameters will be passed through to the exercise via exerciseData
  /// Example: For cloze exercises, {'blankCount': 2} or {'blankPercentage': 0.33}
  /// Note: If multiple types are provided, the same parameters will be used for all
  final Map<String, dynamic>? parameters;
  
  const ExerciseConfigEntry._({
    required this.types,
    required this.perConcept,
    this.parameters,
  });
  
  /// Constructor for a single exercise type
  ExerciseConfigEntry({
    required ExerciseType type,
    required bool perConcept,
    Map<String, dynamic>? parameters,
  }) : this._(
          types: [type],
          perConcept: perConcept,
          parameters: parameters,
        );
  
  /// Constructor for multiple exercise type alternatives
  /// One will be randomly selected per concept
  const ExerciseConfigEntry.alternatives({
    required List<ExerciseType> types,
    required bool perConcept,
    Map<String, dynamic>? parameters,
  }) : this._(
          types: types,
          perConcept: perConcept,
          parameters: parameters,
        );
}

