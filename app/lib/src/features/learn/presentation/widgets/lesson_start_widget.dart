import 'package:flutter/material.dart';

/// Widget that displays a start screen for the lesson
class LessonStartWidget extends StatelessWidget {
  final int cardCount;
  final int filteredConceptsCount;
  final int conceptsWithBothLanguagesCount;
  final int conceptsWithoutCardsCount;
  final VoidCallback? onStartLesson;

  const LessonStartWidget({
    super.key,
    required this.cardCount,
    required this.filteredConceptsCount,
    required this.conceptsWithBothLanguagesCount,
    required this.conceptsWithoutCardsCount,
    this.onStartLesson,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ready to Learn',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cascading counts display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Cards',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCountRow(
                    context: context,
                    label: 'Concepts matching filters',
                    count: filteredConceptsCount,
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 8),
                  _buildCountRow(
                    context: context,
                    label: 'With lemmas in both languages',
                    count: conceptsWithBothLanguagesCount,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    indent: 16,
                  ),
                  const SizedBox(height: 8),
                  _buildCountRow(
                    context: context,
                    label: 'Not yet learned',
                    count: conceptsWithoutCardsCount,
                    color: colorScheme.primary,
                    indent: 32,
                    isHighlighted: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              cardCount == 1
                  ? '1 card ready for this lesson'
                  : '$cardCount cards ready for this lesson',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartLesson,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Lesson'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCountRow({
    required BuildContext context,
    required String label,
    required int count,
    required Color color,
    double indent = 0,
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            count.toString(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: color,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

