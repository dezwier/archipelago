import 'package:flutter/material.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';

/// Constants for filter options
class FilterConstants {
  // CEFR levels
  static const List<String> cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  
  // Part of speech values (from the schema)
  static const List<String> partOfSpeechValues = [
    'Noun',
    'Verb',
    'Adjective',
    'Adverb',
    'Pronoun',
    'Preposition',
    'Conjunction',
    'Determiner / Article',
    'Interjection',
  ];
}

/// Bottom sheet widget for dictionary filtering
class DictionaryFilterSheet extends StatefulWidget {
  final DictionaryController controller;
  final List<Topic> topics;
  final bool isLoadingTopics;
  final VoidCallback? onApplyFilters;
  final String? firstVisibleLanguage;

  const DictionaryFilterSheet({
    super.key,
    required this.controller,
    required this.topics,
    this.isLoadingTopics = false,
    this.onApplyFilters,
    this.firstVisibleLanguage,
  });

  @override
  State<DictionaryFilterSheet> createState() => _DictionaryFilterSheetState();
}

class _DictionaryFilterSheetState extends State<DictionaryFilterSheet> {
  // Pending filter changes - only applied when drawer is closed
  SortOption? _pendingSortOption;
  Set<int>? _pendingTopicIds;
  bool? _pendingShowLemmasWithoutTopic;
  Set<String>? _pendingLevels;
  Set<String>? _pendingPartOfSpeech;
  bool? _pendingIncludePublic;
  bool? _pendingIncludePrivate;

  // Helper method to capitalize words in a string
  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  void initState() {
    super.initState();
    // Initialize pending changes with current controller state
    _pendingSortOption = widget.controller.sortOption;
    _pendingTopicIds = Set<int>.from(widget.controller.selectedTopicIds);
    _pendingShowLemmasWithoutTopic = widget.controller.showLemmasWithoutTopic;
    _pendingLevels = Set<String>.from(widget.controller.selectedLevels);
    _pendingPartOfSpeech = Set<String>.from(widget.controller.selectedPartOfSpeech);
    _pendingIncludePublic = widget.controller.includePublic;
    _pendingIncludePrivate = widget.controller.includePrivate;
  }

  void applyPendingChanges() {
    // Apply all pending filter changes to the controller
    if (_pendingSortOption != null && _pendingSortOption != widget.controller.sortOption) {
      widget.controller.setSortOption(
        _pendingSortOption!,
        firstVisibleLanguage: widget.firstVisibleLanguage,
      );
    }
    if (_pendingTopicIds != null && _pendingTopicIds != widget.controller.selectedTopicIds) {
      widget.controller.setTopicFilter(_pendingTopicIds!);
    }
    if (_pendingShowLemmasWithoutTopic != null && 
        _pendingShowLemmasWithoutTopic != widget.controller.showLemmasWithoutTopic) {
      widget.controller.setShowLemmasWithoutTopic(_pendingShowLemmasWithoutTopic!);
    }
    if (_pendingLevels != null && _pendingLevels != widget.controller.selectedLevels) {
      widget.controller.setLevelFilter(_pendingLevels!);
    }
    if (_pendingPartOfSpeech != null && 
        _pendingPartOfSpeech != widget.controller.selectedPartOfSpeech) {
      widget.controller.setPartOfSpeechFilter(_pendingPartOfSpeech!);
    }
    if (_pendingIncludePublic != null && 
        _pendingIncludePublic != widget.controller.includePublic) {
      widget.controller.setIncludePublic(_pendingIncludePublic!);
    }
    if (_pendingIncludePrivate != null && 
        _pendingIncludePrivate != widget.controller.includePrivate) {
      widget.controller.setIncludePrivate(_pendingIncludePrivate!);
    }
  }
  
  void _applyPendingChanges() {
    applyPendingChanges();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Apply pending changes when the sheet is dismissed
          _applyPendingChanges();
        }
      },
      child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 0.0),
            child: Row(
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _applyPendingChanges();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort options
                  StatefulBuilder(
                    builder: (context, setMenuState) {
                      final currentSortOption = _pendingSortOption ?? widget.controller.sortOption;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                            child: Text(
                              'Sort',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              children: [
                                // Alphabetical button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setMenuState(() {
                                        _pendingSortOption = SortOption.alphabetical;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: currentSortOption == SortOption.alphabetical
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: currentSortOption == SortOption.alphabetical
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                          width: currentSortOption == SortOption.alphabetical ? 1 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.sort_by_alpha,
                                            size: 18,
                                            color: currentSortOption == SortOption.alphabetical
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Alphabetical',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: currentSortOption == SortOption.alphabetical
                                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Recent button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setMenuState(() {
                                        _pendingSortOption = SortOption.timeCreatedRecentFirst;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: currentSortOption == SortOption.timeCreatedRecentFirst
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: currentSortOption == SortOption.timeCreatedRecentFirst
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                          width: currentSortOption == SortOption.timeCreatedRecentFirst ? 1 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 18,
                                            color: currentSortOption == SortOption.timeCreatedRecentFirst
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Recent',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: currentSortOption == SortOption.timeCreatedRecentFirst
                                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Random button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setMenuState(() {
                                        _pendingSortOption = SortOption.random;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: currentSortOption == SortOption.random
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: currentSortOption == SortOption.random
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                          width: currentSortOption == SortOption.random ? 1 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.shuffle,
                                            size: 18,
                                            color: currentSortOption == SortOption.random
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Random',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: currentSortOption == SortOption.random
                                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Public/Private filter
                  StatefulBuilder(
                    builder: (context, setMenuState) {
                      final currentIncludePublic = _pendingIncludePublic ?? widget.controller.includePublic;
                      final currentIncludePrivate = _pendingIncludePrivate ?? widget.controller.includePrivate;
                      final isLoggedIn = widget.controller.currentUser != null;
                      final allSelected = currentIncludePublic && currentIncludePrivate;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                            child: Row(
                              children: [
                                Text(
                                  'Visibility',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setMenuState(() {
                                      final newValue = !allSelected;
                                      _pendingIncludePublic = newValue;
                                      _pendingIncludePrivate = newValue;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    allSelected ? 'All Off' : 'All On',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Public button
                                GestureDetector(
                                  onTap: () {
                                    setMenuState(() {
                                      _pendingIncludePublic = !currentIncludePublic;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: currentIncludePublic
                                          ? Theme.of(context).colorScheme.primaryContainer
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: currentIncludePublic
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                        width: currentIncludePublic ? 1 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Public',
                                      style: TextStyle(
                                        color: currentIncludePublic
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                // Private button
                                GestureDetector(
                                  onTap: isLoggedIn
                                      ? () {
                                          setMenuState(() {
                                            _pendingIncludePrivate = !currentIncludePrivate;
                                          });
                                        }
                                      : null,
                                  child: Opacity(
                                    opacity: isLoggedIn ? 1.0 : 0.5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: currentIncludePrivate
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: currentIncludePrivate
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                          width: currentIncludePrivate ? 1 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Private',
                                        style: TextStyle(
                                          color: currentIncludePrivate
                                              ? Theme.of(context).colorScheme.onPrimaryContainer
                                              : Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Topics filter
                  if (widget.isLoadingTopics)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                          child: Text(
                            'Topics',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    )
                  else if (widget.topics.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                          child: Text(
                            'Topics',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                          child: Text(
                            'No topics available',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    )
                    else
                    StatefulBuilder(
                      builder: (context, setMenuState) {
                        final currentTopicIds = _pendingTopicIds ?? widget.controller.selectedTopicIds;
                        final allTopicIds = widget.topics.map((t) => t.id).toSet();
                        final allSelected = allTopicIds.isNotEmpty && 
                            currentTopicIds.length == allTopicIds.length &&
                            currentTopicIds.containsAll(allTopicIds);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    'Topics',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {
                                      setMenuState(() {
                                        if (allSelected) {
                                          _pendingTopicIds = <int>{};
                                        } else {
                                          _pendingTopicIds = Set<int>.from(allTopicIds);
                                        }
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      allSelected ? 'All Off' : 'All On',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Topic buttons
                                  ...widget.topics.map((topic) {
                                    final isSelected = currentTopicIds.contains(topic.id);
                                    return GestureDetector(
                                      onTap: () {
                                        setMenuState(() {
                                          final newSet = Set<int>.from(currentTopicIds);
                                          if (isSelected) {
                                            newSet.remove(topic.id);
                                          } else {
                                            newSet.add(topic.id);
                                          }
                                          _pendingTopicIds = newSet;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.primaryContainer
                                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                            width: isSelected ? 1 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          _capitalizeWords(topic.name),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  const Divider(height: 1),
                  // Levels filter
                  StatefulBuilder(
                    builder: (context, setMenuState) {
                      final currentLevels = _pendingLevels ?? widget.controller.selectedLevels;
                      final allLevels = FilterConstants.cefrLevels.toSet();
                      final allSelected = currentLevels.length == allLevels.length &&
                          currentLevels.containsAll(allLevels);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                            child: Row(
                              children: [
                                Text(
                                  'CEFR Levels',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setMenuState(() {
                                      if (allSelected) {
                                        _pendingLevels = <String>{};
                                      } else {
                                        _pendingLevels = Set<String>.from(allLevels);
                                      }
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    allSelected ? 'All Off' : 'All On',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: FilterConstants.cefrLevels.map((level) {
                                final isSelected = currentLevels.contains(level);
                                return GestureDetector(
                                  onTap: () {
                                    setMenuState(() {
                                      final newSet = Set<String>.from(currentLevels);
                                      if (isSelected) {
                                        newSet.remove(level);
                                      } else {
                                        newSet.add(level);
                                      }
                                      _pendingLevels = newSet;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primaryContainer
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                        width: isSelected ? 1 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      level,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Part of Speech filter
                  StatefulBuilder(
                    builder: (context, setMenuState) {
                      final currentPartOfSpeech = _pendingPartOfSpeech ?? widget.controller.selectedPartOfSpeech;
                      final allPOS = FilterConstants.partOfSpeechValues.toSet();
                      final allSelected = currentPartOfSpeech.length == allPOS.length &&
                          currentPartOfSpeech.containsAll(allPOS);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                            child: Row(
                              children: [
                                Text(
                                  'Part of Speech',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setMenuState(() {
                                      if (allSelected) {
                                        _pendingPartOfSpeech = <String>{};
                                      } else {
                                        _pendingPartOfSpeech = Set<String>.from(allPOS);
                                      }
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    allSelected ? 'All Off' : 'All On',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: FilterConstants.partOfSpeechValues.map((pos) {
                                final isSelected = currentPartOfSpeech.contains(pos);
                                return GestureDetector(
                                  onTap: () {
                                    setMenuState(() {
                                      final newSet = Set<String>.from(currentPartOfSpeech);
                                      if (isSelected) {
                                        newSet.remove(pos);
                                      } else {
                                        newSet.add(pos);
                                      }
                                      _pendingPartOfSpeech = newSet;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primaryContainer
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                        width: isSelected ? 1 : 1,
                                      ),
                                    ),
                                    child: Text(
                                      pos,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.onPrimaryContainer
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Bottom padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Helper function to show the filter bottom sheet
void showDictionaryFilterSheet({
  required BuildContext context,
  required DictionaryController controller,
  required List<Topic> topics,
  bool isLoadingTopics = false,
  String? firstVisibleLanguage,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => DictionaryFilterSheet(
      controller: controller,
      topics: topics,
      isLoadingTopics: isLoadingTopics,
      firstVisibleLanguage: firstVisibleLanguage,
    ),
  );
}

