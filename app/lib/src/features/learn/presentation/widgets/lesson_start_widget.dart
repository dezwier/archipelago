import 'package:flutter/material.dart';

/// Widget that displays a start screen for the lesson
class LessonStartWidget extends StatefulWidget {
  final int cardCount;
  final int totalConceptsCount;
  final int filteredConceptsCount;
  final int conceptsWithBothLanguagesCount;
  final int conceptsWithoutCardsCount;
  final int cardsToLearn;
  final bool includeNewCards;
  final bool includeLearnedCards;
  final ValueChanged<int>? onCardsToLearnChanged;
  final VoidCallback? onFilterPressed;
  final VoidCallback? onStartLesson;
  final void Function(int cardsToLearn, bool includeNewCards, bool includeLearnedCards)? onGenerateWorkout;

  const LessonStartWidget({
    super.key,
    required this.cardCount,
    required this.totalConceptsCount,
    required this.filteredConceptsCount,
    required this.conceptsWithBothLanguagesCount,
    required this.conceptsWithoutCardsCount,
    required this.cardsToLearn,
    required this.includeNewCards,
    required this.includeLearnedCards,
    this.onCardsToLearnChanged,
    this.onFilterPressed,
    this.onStartLesson,
    this.onGenerateWorkout,
  });

  @override
  State<LessonStartWidget> createState() => _LessonStartWidgetState();
}

class _LessonStartWidgetState extends State<LessonStartWidget> {
  bool _includeNewCards = true;
  bool _includeLearnedCards = false;
  int _localCardsToLearn = 4;

  @override
  void initState() {
    super.initState();
    _localCardsToLearn = widget.cardsToLearn;
    _includeNewCards = widget.includeNewCards;
    _includeLearnedCards = widget.includeLearnedCards;
  }

  @override
  void didUpdateWidget(LessonStartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cardsToLearn != oldWidget.cardsToLearn) {
      _localCardsToLearn = widget.cardsToLearn;
    }
    if (widget.includeNewCards != oldWidget.includeNewCards) {
      _includeNewCards = widget.includeNewCards;
    }
    if (widget.includeLearnedCards != oldWidget.includeLearnedCards) {
      _includeLearnedCards = widget.includeLearnedCards;
    }
  }

  String _getConceptsLabel() {
    if (widget.includeNewCards && widget.includeLearnedCards) {
      return 'New and Learned Concepts';
    } else if (widget.includeNewCards) {
      return 'New Concepts';
    } else if (widget.includeLearnedCards) {
      return 'Learned Concepts';
    } else {
      return 'New and Learned Concepts';
    }
  }

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
                  Icons.settings,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lesson Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Learning Settings content (without card wrapper)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters and To Include side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filters section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.onFilterPressed != null)
                          _buildFilterChip(
                            context: context,
                            label: '',
                            isSelected: false,
                            onTap: widget.onFilterPressed!,
                            icon: Icons.filter_list,
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // To Include section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To Include',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildToggleChip(
                              context: context,
                              label: 'New Cards',
                              isSelected: _includeNewCards,
                              onTap: () {
                                setState(() {
                                  _includeNewCards = !_includeNewCards;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildToggleChip(
                              context: context,
                              label: 'Learned Cards',
                              isSelected: _includeLearnedCards,
                              onTap: () {
                                setState(() {
                                  _includeLearnedCards = !_includeLearnedCards;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Number of cards section
                Text(
                  'Number of Cards',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [2, 4, 6, 8].map((count) {
                    final isSelected = _localCardsToLearn == count;
                    return _buildFilterChip(
                      context: context,
                      label: count.toString(),
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _localCardsToLearn = count;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Generate Workout button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onGenerateWorkout != null
                        ? () {
                            widget.onGenerateWorkout!(
                              _localCardsToLearn,
                              _includeNewCards,
                              _includeLearnedCards,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Lesson'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
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

            // Cascading counts display (without card wrapper)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCountRow(
                  context: context,
                  label: 'Concepts in dictionary',
                  count: widget.totalConceptsCount,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                _buildCountRow(
                  context: context,
                  label: 'Concepts after filtering',
                  count: widget.filteredConceptsCount,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  indent: 16,
                ),
                const SizedBox(height: 8),
                _buildCountRow(
                  context: context,
                  label: 'Concepts with languages available',
                  count: widget.conceptsWithBothLanguagesCount,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  indent: 32,
                ),
                const SizedBox(height: 8),
                _buildCountRow(
                  context: context,
                  label: _getConceptsLabel(),
                  count: widget.conceptsWithoutCardsCount,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  indent: 48,
                ),
                const SizedBox(height: 8),
                _buildCountRow(
                  context: context,
                  label: widget.cardCount == 1 ? 'Card ready for this lesson' : 'Cards ready for this lesson',
                  count: widget.cardCount,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  indent: 64,
                  isHighlighted: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onStartLesson,
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

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: icon != null ? 10 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: icon != null
            ? Icon(
                icon,
                size: 20,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              )
            : Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

