import 'package:archipelago/src/features/learn/domain/exercise_type.dart';
import 'package:archipelago/src/features/learn/config/new_cards_exercise_config.dart';

/// Configuration for exercise generation for learned cards
/// 
/// Defines which exercises are included in a lesson for learned cards.
/// This configuration contains only the close exercise with 66% blanks.
class LearnedCardsExerciseConfig {
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
  /// For learned cards, only the close exercise with 66% blanks is used.
  static final List<ExerciseConfigEntry> exercises = [
    // Close exercise with 66% of words missing: one per concept
    ExerciseConfigEntry(
      type: ExerciseType.closeExercise,
      perConcept: true,
      parameters: {
        'blankPercentage': 0.66,
      },
    ),
  ];
}

