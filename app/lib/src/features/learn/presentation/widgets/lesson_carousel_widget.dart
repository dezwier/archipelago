import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/lesson_card_widget.dart';

/// Widget that displays a carousel of lesson cards with navigation
class LessonCarouselWidget extends StatelessWidget {
  final List<Map<String, dynamic>> concepts;
  final int currentIndex;
  final String? nativeLanguage;
  final String? learningLanguage;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;

  const LessonCarouselWidget({
    super.key,
    required this.concepts,
    required this.currentIndex,
    this.nativeLanguage,
    this.learningLanguage,
    this.onPrevious,
    this.onNext,
    this.onFinish,
  });

  bool get isFirstCard => currentIndex == 0;
  bool get isLastCard => currentIndex >= concepts.length - 1;
  int get totalCards => concepts.length;

  @override
  Widget build(BuildContext context) {
    if (concepts.isEmpty) {
      return const Center(
        child: Text('No cards available'),
      );
    }

    if (currentIndex < 0 || currentIndex >= concepts.length) {
      return const Center(
        child: Text('Invalid card index'),
      );
    }

    final currentConcept = concepts[currentIndex];

    return Column(
      children: [
        // Progress Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Card ${currentIndex + 1} of $totalCards',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
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
            widthFactor: (currentIndex + 1) / totalCards,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Card Content
        Expanded(
          child: LessonCardWidget(
            concept: currentConcept,
            nativeLanguage: nativeLanguage,
            learningLanguage: learningLanguage,
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
                  onPressed: isFirstCard ? null : onPrevious,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),

                // Next/Finish Button
                ElevatedButton.icon(
                  onPressed: isLastCard ? onFinish : onNext,
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

