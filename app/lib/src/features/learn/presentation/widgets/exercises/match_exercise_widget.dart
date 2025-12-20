import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';

/// Widget that displays a Match exercise
/// Placeholder for future implementation
class MatchExerciseWidget extends StatelessWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;

  const MatchExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.extension,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Match Exercise',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onComplete,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

