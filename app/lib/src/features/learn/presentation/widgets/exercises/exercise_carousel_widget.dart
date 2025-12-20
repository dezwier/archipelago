import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/exercise_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/exercise_feedback_widget.dart';

/// Widget that displays a carousel of exercises with input and feedback screens
class ExerciseCarouselWidget extends StatefulWidget {
  final List<Exercise> exercises;
  final int currentIndex;
  final String? nativeLanguage;
  final String? learningLanguage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;
  final VoidCallback? onDismiss;

  const ExerciseCarouselWidget({
    super.key,
    required this.exercises,
    required this.currentIndex,
    this.nativeLanguage,
    this.learningLanguage,
    this.onPrevious,
    this.onNext,
    this.onFinish,
    this.onDismiss,
  });

  @override
  State<ExerciseCarouselWidget> createState() => _ExerciseCarouselWidgetState();
}

class _ExerciseCarouselWidgetState extends State<ExerciseCarouselWidget> {
  bool _shouldAutoPlay = false;
  int? _lastAutoPlayedIndex;
  bool _showingFeedback = false; // Track if we're showing feedback for current exercise

  @override
  void initState() {
    super.initState();
    // Autoplay the first exercise when lesson starts
    if (widget.currentIndex == 0) {
      _shouldAutoPlay = true;
      _lastAutoPlayedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _shouldAutoPlay = false;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(ExerciseCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset feedback state when moving to a new exercise
    if (widget.currentIndex != oldWidget.currentIndex) {
      _showingFeedback = false;
    }
    // Check if we navigated forward (to next exercise)
    if (widget.currentIndex > oldWidget.currentIndex && oldWidget.currentIndex >= 0) {
      if (_lastAutoPlayedIndex != widget.currentIndex) {
        _shouldAutoPlay = true;
        _lastAutoPlayedIndex = widget.currentIndex;
      } else {
        _shouldAutoPlay = false;
      }
    } else {
      _shouldAutoPlay = false;
    }
  }

  bool get isFirstExercise => widget.currentIndex == 0 && !_showingFeedback;
  bool get isLastExercise => widget.currentIndex >= widget.exercises.length - 1 && _showingFeedback;
  int get totalExercises => widget.exercises.length;

  void _handleExerciseComplete() {
    final currentExercise = widget.exercises[widget.currentIndex];
    // For discovery exercises, skip feedback and go directly to next exercise
    if (currentExercise.type == ExerciseType.discovery) {
      _handleFeedbackContinue();
    } else {
      // Show feedback screen for other exercise types
      setState(() {
        _showingFeedback = true;
      });
    }
  }

  void _handleFeedbackContinue() {
    // Move to next exercise
    if (widget.currentIndex < widget.exercises.length - 1) {
      if (widget.onNext != null) {
        widget.onNext!();
      }
    } else {
      // Last exercise, finish lesson
      if (widget.onFinish != null) {
        widget.onFinish!();
      }
    }
  }

  void _handleNext() {
    final currentExercise = widget.exercises[widget.currentIndex];
    if (_showingFeedback) {
      // On feedback screen, continue to next exercise
      _handleFeedbackContinue();
    } else {
      // On input screen, show feedback first (or skip directly to next for discovery)
      // For Discovery exercises, skip feedback and go directly to next
      if (currentExercise.type == ExerciseType.discovery) {
        _handleFeedbackContinue();
      } else {
        // For other exercises, show feedback first
        setState(() {
          _showingFeedback = true;
        });
      }
    }
  }

  void _handlePrevious() {
    if (_showingFeedback) {
      // Go back to input screen
      setState(() {
        _showingFeedback = false;
      });
    } else if (widget.currentIndex > 0) {
      // Go to previous exercise
      if (widget.onPrevious != null) {
        widget.onPrevious!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldAutoPlayThisBuild = _shouldAutoPlay;
    if (_shouldAutoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _shouldAutoPlay = false;
          });
        }
      });
    }

    if (widget.exercises.isEmpty) {
      return const Center(
        child: Text('No exercises available'),
      );
    }

    if (widget.currentIndex < 0 || widget.currentIndex >= widget.exercises.length) {
      return const Center(
        child: Text('Invalid exercise index'),
      );
    }

    final currentExercise = widget.exercises[widget.currentIndex];

    return Stack(
      children: [
        Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.fromLTRB(0, 21.0, 0, 12),
              child: Center(
                child: Text(
                  'Exercise ${widget.currentIndex + 1} of $totalExercises',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),

            // Progress Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 3.0),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (widget.currentIndex + 1) / totalExercises,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),

            // Exercise Content (Input or Feedback)
            Expanded(
              child: _showingFeedback && currentExercise.type != ExerciseType.discovery
                  ? ExerciseFeedbackWidget(
                      key: ValueKey('feedback_${currentExercise.id}'),
                      exercise: currentExercise,
                      isCorrect: true, // For Discovery, always correct
                      onContinue: _handleFeedbackContinue,
                    )
                  : ExerciseWidget(
                      key: ValueKey('exercise_${currentExercise.id}'),
                      exercise: currentExercise,
                      nativeLanguage: widget.nativeLanguage,
                      learningLanguage: widget.learningLanguage,
                      autoPlay: shouldAutoPlayThisBuild,
                      onComplete: _handleExerciseComplete,
                    ),
            ),

            // Navigation Buttons - Floating
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Button
                    ElevatedButton.icon(
                      onPressed: isFirstExercise ? null : _handlePrevious,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),

                    // Next/Finish Button
                    ElevatedButton.icon(
                      onPressed: _handleNext,
                      icon: Icon((_showingFeedback && isLastExercise) || (!_showingFeedback && widget.currentIndex >= widget.exercises.length - 1)
                          ? Icons.check
                          : Icons.arrow_forward),
                      label: Text((_showingFeedback && isLastExercise) || (!_showingFeedback && widget.currentIndex >= widget.exercises.length - 1)
                          ? 'Finish'
                          : 'Next'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Dismiss button in upper right corner of screen
        if (widget.onDismiss != null)
          Positioned(
            right: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: widget.onDismiss,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss lesson',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

