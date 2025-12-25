import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/leitner_distribution_card.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';

/// Widget that displays a start screen for the lesson
class LessonStartWidget extends StatefulWidget {
  final int cardCount;
  final int totalConceptsCount;
  final int filteredConceptsCount;
  final int conceptsWithBothLanguagesCount;
  final int conceptsWithoutCardsCount;
  final int cardsToLearn;
  final String cardMode; // 'new' or 'learned'
  final ValueChanged<int>? onCardsToLearnChanged;
  final VoidCallback? onFilterPressed;
  final void Function(int cardsToLearn, String cardMode)? onSettingsChanged;
  final Future<void> Function(int cardsToLearn, String cardMode)? onGenerateAndStartLesson;
  final void Function(Map<String, dynamic> Function() getCurrentSettings)? onGetCurrentSettingsReady;
  final LeitnerDistribution? leitnerDistribution;
  final List<Language> languages;
  final int? userId;
  final VoidCallback? onRefreshLeitner;
  final bool isLoadingLeitner;
  final int? maxBins;
  final String? algorithm;
  final int? intervalStartHours;
  final VoidCallback? onConfigUpdated;

  const LessonStartWidget({
    super.key,
    required this.cardCount,
    required this.totalConceptsCount,
    required this.filteredConceptsCount,
    required this.conceptsWithBothLanguagesCount,
    required this.conceptsWithoutCardsCount,
    required this.cardsToLearn,
    required this.cardMode,
    this.onCardsToLearnChanged,
    this.onFilterPressed,
    this.onSettingsChanged,
    this.onGenerateAndStartLesson,
    this.onGetCurrentSettingsReady,
    this.leitnerDistribution,
    this.languages = const [],
    this.userId,
    this.onRefreshLeitner,
    this.isLoadingLeitner = false,
    this.maxBins,
    this.algorithm,
    this.intervalStartHours,
    this.onConfigUpdated,
  });

  @override
  State<LessonStartWidget> createState() => _LessonStartWidgetState();
}

/// Widget that displays the counts section - rebuilds independently
class _LessonCountsWidget extends StatelessWidget {
  final int cardCount;
  final int totalConceptsCount;
  final int filteredConceptsCount;
  final int conceptsWithBothLanguagesCount;
  final int conceptsWithoutCardsCount;
  final String cardMode; // 'new' or 'learned'

  const _LessonCountsWidget({
    required this.cardCount,
    required this.totalConceptsCount,
    required this.filteredConceptsCount,
    required this.conceptsWithBothLanguagesCount,
    required this.conceptsWithoutCardsCount,
    required this.cardMode,
  });

  String _getConceptsLabel() {
    if (cardMode == 'new') {
      return 'New Concepts';
    } else if (cardMode == 'learned') {
      return 'Learned Concepts';
    } else {
      return 'Concepts';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ),
        const SizedBox(height: 8),
        _buildCountRow(
          context: context,
          label: 'Concepts with languages available',
          count: conceptsWithBothLanguagesCount,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 8),
        _buildCountRow(
          context: context,
          label: _getConceptsLabel(),
          count: conceptsWithoutCardsCount,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 8),
        _buildCountRow(
          context: context,
          label: cardCount == 1 ? 'Card ready for this lesson' : 'Cards ready for this lesson',
          count: cardCount,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          isHighlighted: true,
        ),
      ],
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

class _LessonStartWidgetState extends State<LessonStartWidget> {
  String _cardMode = 'new';
  int _localCardsToLearn = 4;

  @override
  void initState() {
    super.initState();
    _localCardsToLearn = widget.cardsToLearn;
    _cardMode = widget.cardMode;
    
    // Register callback to expose current settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onGetCurrentSettingsReady?.call(() {
        return {
          'cardsToLearn': _localCardsToLearn,
          'cardMode': _cardMode,
        };
      });
    });
  }

  @override
  void didUpdateWidget(LessonStartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cardsToLearn != oldWidget.cardsToLearn) {
      _localCardsToLearn = widget.cardsToLearn;
    }
    if (widget.cardMode != oldWidget.cardMode) {
      _cardMode = widget.cardMode;
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
            // Learning Settings content (without card wrapper)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters, Mode, and Number of Cards side by side
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
                        const SizedBox(height: 9),
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
                    const SizedBox(width: 20),
                    // Mode selection section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'new', label: Text('New')),
                              ButtonSegment(value: 'learned', label: Text('Learned')),
                            ],
                            selected: <String>{_cardMode},
                            onSelectionChanged: (Set<String> newSelection) {
                              if (newSelection.isNotEmpty) {
                                final newMode = newSelection.first;
                                setState(() {
                                  _cardMode = newMode;
                                });
                                // Update counters when mode changes
                                widget.onSettingsChanged?.call(_localCardsToLearn, newMode);
                              }
                            },
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              padding: WidgetStateProperty.all<EdgeInsets>(
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              ),
                              minimumSize: WidgetStateProperty.all<Size>(
                                const Size(0, 32),
                              ),
                              textStyle: WidgetStateProperty.all<TextStyle>(
                                const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 0),
                    // Number of cards section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cards',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 2, label: Text('2')),
                              ButtonSegment(value: 4, label: Text('4')),
                              ButtonSegment(value: 6, label: Text('6')),
                              ButtonSegment(value: 8, label: Text('8')),
                            ],
                            selected: <int>{_localCardsToLearn},
                            onSelectionChanged: (Set<int> newSelection) {
                              if (newSelection.isNotEmpty) {
                                final newCount = newSelection.first;
                                setState(() {
                                  _localCardsToLearn = newCount;
                                });
                                // Update counters when cards count changes
                                widget.onSettingsChanged?.call(newCount, _cardMode);
                              }
                            },
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              padding: WidgetStateProperty.all<EdgeInsets>(
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              ),
                              minimumSize: WidgetStateProperty.all<Size>(
                                const Size(0, 32),
                              ),
                              textStyle: WidgetStateProperty.all<TextStyle>(
                                const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cascading counts display (without card wrapper)
            // Wrapped in RepaintBoundary to optimize rendering when only counts change
            RepaintBoundary(
              child: _LessonCountsWidget(
                cardCount: widget.cardCount,
                totalConceptsCount: widget.totalConceptsCount,
                filteredConceptsCount: widget.filteredConceptsCount,
                conceptsWithBothLanguagesCount: widget.conceptsWithBothLanguagesCount,
                conceptsWithoutCardsCount: widget.conceptsWithoutCardsCount,
                cardMode: widget.cardMode,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onGenerateAndStartLesson != null
                    ? () async {
                        await widget.onGenerateAndStartLesson!(
                          _localCardsToLearn,
                          _cardMode,
                        );
                      }
                    : null,
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
            const SizedBox(height: 16),
            // Leitner distribution chart
            if (widget.leitnerDistribution != null && widget.languages.isNotEmpty && widget.userId != null)
              LeitnerDistributionCard(
                distribution: widget.leitnerDistribution!,
                languages: widget.languages,
                userId: widget.userId!,
                onRefresh: widget.onRefreshLeitner,
                maxBins: widget.maxBins ?? 7,
                algorithm: widget.algorithm ?? 'fibonacci',
                intervalStartHours: widget.intervalStartHours ?? 23,
                onConfigUpdated: widget.onConfigUpdated,
              )
            else if (widget.isLoadingLeitner)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
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

}

