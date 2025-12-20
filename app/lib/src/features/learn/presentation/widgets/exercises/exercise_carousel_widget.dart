import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/exercises/exercise_widget.dart';

/// Widget that displays a carousel of exercises
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

  bool get isFirstExercise => widget.currentIndex == 0;
  bool get isLastExercise => widget.currentIndex >= widget.exercises.length - 1;
  int get totalExercises => widget.exercises.length;

  void _handleExerciseComplete() {
    // Move to next exercise when exercise completes
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

  void _handlePrevious() {
    if (widget.currentIndex > 0) {
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
            // Progress Bar
            Container(
              margin: const EdgeInsets.fromLTRB(56.0, 32.0, 56.0, 12.0),
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

            // Exercise Content
            Expanded(
              child: ExerciseWidget(
                key: ValueKey('exercise_${currentExercise.id}'),
                exercise: currentExercise,
                nativeLanguage: widget.nativeLanguage,
                learningLanguage: widget.learningLanguage,
                autoPlay: shouldAutoPlayThisBuild,
                onComplete: _handleExerciseComplete,
              ),
            ),
          ],
        ),
        // Back arrow button in upper left corner of screen
        Positioned(
          left: 0,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: isFirstExercise ? null : _handlePrevious,
                icon: Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: isFirstExercise ? 0.2 : 0.4,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Previous',
              ),
            ),
          ),
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
        // Floating Next/Finish Button - Bottom Right
        if (currentExercise.type != ExerciseType.match)
          Positioned(
            right: 16,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Material(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(28),
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: InkWell(
                    onTap: _handleNext,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLastExercise ? 'Finish' : 'Next',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastExercise ? Icons.check : Icons.arrow_forward,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

