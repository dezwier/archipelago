import 'package:flutter/material.dart';

/// Widget that displays a start screen for the lesson
class LessonStartWidget extends StatelessWidget {
  final int cardCount;
  final int totalConceptsCount;
  final int filteredConceptsCount;
  final int conceptsWithBothLanguagesCount;
  final int conceptsWithoutCardsCount;
  final VoidCallback? onStartLesson;

  const LessonStartWidget({
    super.key,
    required this.cardCount,
    required this.totalConceptsCount,
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
                color: colorScheme.surfaceContainerLow,
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
                    label: 'Concepts in dictionary',
                    count: totalConceptsCount,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  _buildCountRow(
                    context: context,
                    label: 'Concepts after filtering',
                    count: filteredConceptsCount,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    indent: 16,
                  ),
                  const SizedBox(height: 8),
                  _buildCountRow(
                    context: context,
                    label: 'Concepts with languages available',
                    count: conceptsWithBothLanguagesCount,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    indent: 32,
                  ),
                  const SizedBox(height: 8),
                  _buildCountRow(
                    context: context,
                    label: 'Concepts not yet learned',
                    count: conceptsWithoutCardsCount,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    indent: 48,
                  ),
                  const SizedBox(height: 8),
                  _buildCountRow(
                    context: context,
                    label: cardCount == 1 ? 'Card ready for this lesson' : 'Cards ready for this lesson',
                    count: cardCount,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    indent: 64,
                    isHighlighted: true,
                  ),
                ],
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
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            count.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

