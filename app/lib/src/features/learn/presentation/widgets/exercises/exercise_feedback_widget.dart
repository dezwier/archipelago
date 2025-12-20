import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Widget that displays feedback after an exercise
class ExerciseFeedbackWidget extends StatelessWidget {
  final Exercise exercise;
  final bool isCorrect;
  final VoidCallback onContinue;

  const ExerciseFeedbackWidget({
    super.key,
    required this.exercise,
    required this.isCorrect,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Feedback Icon
            Icon(
              isCorrect ? Icons.check_circle : Icons.info_outline,
              size: 80,
              color: isCorrect
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            // Feedback Message
            Text(
              _getFeedbackMessage(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isCorrect
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Additional feedback text
            Text(
              _getAdditionalFeedback(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFeedbackMessage() {
    switch (exercise.type) {
      case ExerciseType.discovery:
        return 'Great! You\'ve discovered this phrase.';
      case ExerciseType.match:
        return isCorrect ? 'Correct!' : 'Not quite right.';
      case ExerciseType.scaffold:
        return isCorrect ? 'Well done!' : 'Try again.';
      case ExerciseType.produce:
        return isCorrect ? 'Excellent!' : 'Keep practicing.';
    }
  }

  String _getAdditionalFeedback() {
    switch (exercise.type) {
      case ExerciseType.discovery:
        return 'Take your time to familiarize yourself with this phrase.';
      case ExerciseType.match:
        return isCorrect
            ? 'You matched it correctly!'
            : 'Review the correct answer and try again next time.';
      case ExerciseType.scaffold:
        return isCorrect
            ? 'You built the phrase correctly!'
            : 'Remember the word order and try again.';
      case ExerciseType.produce:
        return isCorrect
            ? 'You produced the phrase correctly!'
            : 'Practice makes perfect. Keep going!';
    }
  }
}

