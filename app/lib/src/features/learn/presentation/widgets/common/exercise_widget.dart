import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';
import 'package:archipelago/src/features/learn/domain/exercise_performance.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/discovery_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/discovery_summary_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/match_info_image_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/match_audio_image_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/match_image_info_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/match_image_audio_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/match_description_phrase_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/match_phrase_description_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/scaffold_from_image_exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/close_exercise_widget.dart';

/// Base widget that routes to specific exercise type widgets
class ExerciseWidget extends StatelessWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete; // Called when exercise is completed
  final GlobalKey? matchImageAudioKey; // For accessing matchImageAudio widget state
  final Function(Exercise exercise)? onExerciseStart;
  final Function(Exercise exercise, ExerciseOutcome outcome, {int? hintCount, String? failureReason})? onExerciseComplete;

  const ExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
    this.matchImageAudioKey,
    this.onExerciseStart,
    this.onExerciseComplete,
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
      case ExerciseType.summary:
        return DiscoverySummaryExerciseWidget(
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
        );
      case ExerciseType.matchInfoImage:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptIdMatchInfo = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return MatchInfoImageExerciseWidget(
          key: ValueKey('matchInfoImage_${exercise.id}_${conceptIdMatchInfo}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
      case ExerciseType.matchAudioImage:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptIdMatchAudio = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return MatchAudioImageExerciseWidget(
          key: ValueKey('matchAudioImage_${exercise.id}_${conceptIdMatchAudio}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
      case ExerciseType.matchImageInfo:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptIdMatchImageInfo = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return MatchImageInfoExerciseWidget(
          key: ValueKey('matchImageInfo_${exercise.id}_${conceptIdMatchImageInfo}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
      case ExerciseType.matchImageAudio:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        // Use provided GlobalKey if available, otherwise use ValueKey
        final conceptIdMatchImageAudio = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return MatchImageAudioExerciseWidget(
          key: matchImageAudioKey ?? ValueKey('matchImageAudio_${exercise.id}_${conceptIdMatchImageAudio}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
      case ExerciseType.matchDescriptionPhrase:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptIdMatchDescriptionPhrase = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return MatchDescriptionPhraseExerciseWidget(
          key: ValueKey('matchDescriptionPhrase_${exercise.id}_${conceptIdMatchDescriptionPhrase}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
      case ExerciseType.matchPhraseDescription:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptIdMatchPhraseDescription = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return MatchPhraseDescriptionExerciseWidget(
          key: ValueKey('matchPhraseDescription_${exercise.id}_${conceptIdMatchPhraseDescription}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
      case ExerciseType.scaffoldFromImage:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptIdScaffoldFromImage = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return ScaffoldFromImageExerciseWidget(
          key: ValueKey('scaffoldFromImage_${exercise.id}_${conceptIdScaffoldFromImage}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
      case ExerciseType.closeExercise:
        // Use a unique key that includes exercise ID and concept ID to ensure widget recreation
        final conceptIdCloseExercise = exercise.concept['id'] ?? exercise.concept['concept_id'];
        return CloseExerciseWidget(
          key: ValueKey('closeExercise_${exercise.id}_${conceptIdCloseExercise}'),
          exercise: exercise,
          nativeLanguage: nativeLanguage,
          learningLanguage: learningLanguage,
          autoPlay: autoPlay,
          onComplete: onComplete,
          onExerciseStart: onExerciseStart,
          onExerciseComplete: onExerciseComplete,
        );
    }
  }
}

