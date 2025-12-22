import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';
import 'package:archipelago/src/features/learn/domain/exercise_performance.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/exercise_widget.dart';

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
  final Function(Exercise exercise)? onExerciseStart;
  final Function(Exercise exercise, ExerciseOutcome outcome, {int? hintCount, String? failureReason})? onExerciseComplete;

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
    this.onExerciseStart,
    this.onExerciseComplete,
  });

  @override
  State<ExerciseCarouselWidget> createState() => _ExerciseCarouselWidgetState();
}

class _ExerciseCarouselWidgetState extends State<ExerciseCarouselWidget> {
  bool _shouldAutoPlay = false;
  int? _lastAutoPlayedIndex;
  final GlobalKey _matchImageAudioKey = GlobalKey();

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
    final currentExercise = widget.exercises[widget.currentIndex];
    
    // For matchImageAudio exercises, check answer first if not checked
    if (currentExercise.type == ExerciseType.matchImageAudio) {
      final state = _matchImageAudioKey.currentState;
      if (state != null) {
        // Use dynamic to call the method (state is _MatchImageInfoExerciseWidgetState)
        try {
          final result = (state as dynamic).checkAnswerIfNeeded();
          if (result == true) {
            // Answer was checked, don't proceed yet (will proceed after feedback)
            return;
          }
        } catch (e) {
          // Method doesn't exist or error, proceed normally
        }
      }
    }
    
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

  Widget _buildExerciseTypeTag(BuildContext context, String displayName, int currentCard, int totalCards) {
    final words = displayName.split(' ');
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    final baseStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
      fontSize: 12,
    );

    final boldStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.bold,
    );

    final cardInfoText = ' ($currentCard/$totalCards)';

    if (words.length == 1) {
      // Single word - make it bold
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: words[0],
              style: boldStyle,
            ),
            TextSpan(
              text: cardInfoText,
              style: baseStyle,
            ),
          ],
        ),
      );
    }

    if (words.length == 2) {
      // Two words - both bold
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: words[0],
              style: boldStyle,
            ),
            TextSpan(
              text: ' ${words[1]}',
              style: boldStyle,
            ),
            TextSpan(
              text: cardInfoText,
              style: baseStyle,
            ),
          ],
        ),
      );
    }

    // Three or more words - first two words bold, rest normal
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${words[0]} ${words[1]}',
            style: boldStyle,
          ),
          TextSpan(
            text: ' ${words.sublist(2).join(' ')}',
            style: baseStyle,
          ),
          TextSpan(
            text: cardInfoText,
            style: baseStyle,
          ),
        ],
      ),
    );
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

            // Exercise Type Tag
            Center(
              child: _buildExerciseTypeTag(
                context,
                currentExercise.type.displayName,
                widget.currentIndex + 1,
                totalExercises,
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
                matchImageAudioKey: currentExercise.type == ExerciseType.matchImageAudio ? _matchImageAudioKey : null,
                onExerciseStart: widget.onExerciseStart,
                onExerciseComplete: widget.onExerciseComplete,
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
        // Floating Next/Finish Button - Bottom Right (hide for matchImageInfo, matchInfoImage, matchAudioImage, matchDescriptionPhrase, matchPhraseDescription, scaffoldFromImage, and closeExercise exercises)
        if (currentExercise.type != ExerciseType.matchImageInfo && 
            currentExercise.type != ExerciseType.matchInfoImage &&
            currentExercise.type != ExerciseType.matchAudioImage &&
            currentExercise.type != ExerciseType.matchDescriptionPhrase &&
            currentExercise.type != ExerciseType.matchPhraseDescription &&
            currentExercise.type != ExerciseType.scaffoldFromImage &&
            currentExercise.type != ExerciseType.closeExercise)
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

