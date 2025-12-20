import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/discovery_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/match_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/scaffold_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/produce_exercise_widget.dart';

/// Base widget that routes to specific exercise type widgets
class ExerciseWidget extends StatelessWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete; // Called when exercise is completed

  const ExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    switch (exercise.type) {
      case ExerciseType.discovery:
        return DiscoveryExerciseWidget(
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
        );
      case ExerciseType.match:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptId = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return MatchExerciseWidget(
          key: ValueKey('match_${exercise.id}_${conceptId}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
        );
      case ExerciseType.scaffold:
        return ScaffoldExerciseWidget(
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
        );
      case ExerciseType.produce:
        return ProduceExerciseWidget(
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
        );
    }
  }
}

