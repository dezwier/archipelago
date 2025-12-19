import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/lesson_card_widget.dart';

/// Widget that displays a carousel of lesson cards with navigation
class LessonCarouselWidget extends StatefulWidget {
  final List<Map<String, dynamic>> concepts;
  final int currentIndex;
  final String? nativeLanguage;
  final String? learningLanguage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;
  final VoidCallback? onDismiss;

  const LessonCarouselWidget({
    super.key,
    required this.concepts,
    required this.currentIndex,
    this.nativeLanguage,
    this.learningLanguage,
    this.onPrevious,
    this.onNext,
    this.onFinish,
    this.onDismiss,
  });

  @override
  State<LessonCarouselWidget> createState() => _LessonCarouselWidgetState();
}

class _LessonCarouselWidgetState extends State<LessonCarouselWidget> {
  bool _shouldAutoPlay = false;
  int? _lastAutoPlayedIndex; // Track which card index we've autoplayed for

  @override
  void initState() {
    super.initState();
    // Autoplay the first card when lesson starts
    if (widget.currentIndex == 0) {
      _shouldAutoPlay = true;
      _lastAutoPlayedIndex = 0;
      // Reset after build so it doesn't autoplay when toggling languages
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
  void didUpdateWidget(LessonCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if we navigated forward (to next card)
    // Only autoplay when navigating forward from an existing card (not on initial load)
    if (widget.currentIndex > oldWidget.currentIndex && oldWidget.currentIndex >= 0) {
      // Only autoplay if we haven't autoplayed for this card index yet
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

  bool get isFirstCard => widget.currentIndex == 0;
  bool get isLastCard => widget.currentIndex >= widget.concepts.length - 1;
  int get totalCards => widget.concepts.length;

  @override
  Widget build(BuildContext context) {
    // Capture autoplay flag for this build and reset it immediately
    // This ensures autoPlay is only true for one build cycle, preventing autoplay when toggling languages
    final shouldAutoPlayThisBuild = _shouldAutoPlay;
    if (_shouldAutoPlay) {
      // Reset immediately after capturing, but schedule the state update for after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _shouldAutoPlay = false;
          });
        }
      });
    }
    if (widget.concepts.isEmpty) {
      return const Center(
        child: Text('No cards available'),
      );
    }

    if (widget.currentIndex < 0 || widget.currentIndex >= widget.concepts.length) {
      return const Center(
        child: Text('Invalid card index'),
      );
    }

    final currentConcept = widget.concepts[widget.currentIndex];

    return Column(
      children: [
        // Progress Indicator with Dismiss Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Card ${widget.currentIndex + 1} of $totalCards',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (widget.onDismiss != null) ...[
                const SizedBox(width: 12),
                IconButton(
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
              ],
            ],
          ),
        ),

        // Progress Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (widget.currentIndex + 1) / totalCards,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Card Content
        Expanded(
          child: LessonCardWidget(
            key: ValueKey('lesson_card_${widget.currentIndex}'),
            concept: currentConcept,
            nativeLanguage: widget.nativeLanguage,
            learningLanguage: widget.learningLanguage,
            autoPlay: shouldAutoPlayThisBuild,
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
                  onPressed: isFirstCard ? null : widget.onPrevious,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),

                // Next/Finish Button
                ElevatedButton.icon(
                  onPressed: isLastCard ? widget.onFinish : widget.onNext,
                  icon: Icon(isLastCard ? Icons.check : Icons.arrow_forward),
                  label: Text(isLastCard ? 'Finish' : 'Next'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

