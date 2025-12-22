import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Outcome of an exercise attempt
enum ExerciseOutcome {
  succeeded,
  neededHints,
  failed,
}

/// Tracks performance metrics for a single exercise
class ExercisePerformance {
  final String exerciseId;
  final dynamic conceptId;
  final ExerciseType exerciseType;
  final String? conceptTerm; // The concept's term/translation
  final String? conceptImageUrl; // The concept's image URL
  final int? learningLemmaId; // The learning lemma ID for audio playback
  final String? learningAudioPath; // The learning lemma audio path
  final String? learningLanguageCode; // The learning language code
  final String? learningTerm; // The learning term (for TTS if audio doesn't exist)
  final DateTime startTime;
  final DateTime endTime;
  final ExerciseOutcome outcome;
  final int hintCount;
  final String? failureReason;

  ExercisePerformance({
    required this.exerciseId,
    required this.conceptId,
    required this.exerciseType,
    this.conceptTerm,
    this.conceptImageUrl,
    this.learningLemmaId,
    this.learningAudioPath,
    this.learningLanguageCode,
    this.learningTerm,
    required this.startTime,
    required this.endTime,
    required this.outcome,
    this.hintCount = 0,
    this.failureReason,
  });

  /// Calculate the duration of the exercise
  Duration get duration => endTime.difference(startTime);

  /// Get a human-readable duration string
  String get durationString {
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  /// Get display name for the outcome
  String get outcomeDisplayName {
    switch (outcome) {
      case ExerciseOutcome.succeeded:
        return 'Succeeded';
      case ExerciseOutcome.neededHints:
        return 'Needed Hints';
      case ExerciseOutcome.failed:
        return 'Failed';
    }
  }
}

