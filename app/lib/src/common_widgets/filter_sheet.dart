import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'filter_interface.dart';

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
    'Numeral',
  ];
}

/// Generic bottom sheet widget for filtering concepts
class FilterSheet extends StatefulWidget {
  final FilterState filterState;
  final FilterUpdateCallback onApplyFilters;
  final List<Topic> topics;
  final bool isLoadingTopics;
  final List<int> availableBins; // Available Leitner bins for the user
  final int? userId; // User ID for determining available bins
  final int maxBins; // Maximum number of bins (from User.leitner_max_bins)

  const FilterSheet({
    super.key,
    required this.filterState,
    required this.onApplyFilters,
    required this.topics,
    this.isLoadingTopics = false,
    this.availableBins = const [],
    this.userId,
    this.maxBins = 7, // Default to 7 if not provided
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  // Pending filter changes - only applied when drawer is closed
  Set<int>? _pendingTopicIds;
  bool? _pendingShowLemmasWithoutTopic;
  Set<String>? _pendingLevels;
  Set<String>? _pendingPartOfSpeech;
  bool? _pendingIncludeLemmas;
  bool? _pendingIncludePhrases;
  bool? _pendingHasImages;
  bool? _pendingHasNoImages;
  bool? _pendingHasAudio;
  bool? _pendingHasNoAudio;
  bool? _pendingIsComplete;
  bool? _pendingIsIncomplete;
  Set<int>? _pendingLeitnerBins;
  Set<String>? _pendingLearningStatus;

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
    // Initialize pending changes with current filter state
    _pendingTopicIds = Set<int>.from(widget.filterState.selectedTopicIds);
    _pendingShowLemmasWithoutTopic = widget.filterState.showLemmasWithoutTopic;
    _pendingLevels = Set<String>.from(widget.filterState.selectedLevels);
    _pendingPartOfSpeech = Set<String>.from(widget.filterState.selectedPartOfSpeech);
    _pendingIncludeLemmas = widget.filterState.includeLemmas;
    _pendingIncludePhrases = widget.filterState.includePhrases;
    _pendingHasImages = widget.filterState.hasImages;
    _pendingHasNoImages = widget.filterState.hasNoImages;
    _pendingHasAudio = widget.filterState.hasAudio;
    _pendingHasNoAudio = widget.filterState.hasNoAudio;
    _pendingIsComplete = widget.filterState.isComplete;
    _pendingIsIncomplete = widget.filterState.isIncomplete;
    
    // Initialize Leitner bins - if empty, select all bins (1 to maxBins)
    if (widget.filterState.selectedLeitnerBins.isEmpty) {
      _pendingLeitnerBins = Set<int>.from(List.generate(widget.maxBins, (index) => index + 1));
    } else {
      _pendingLeitnerBins = Set<int>.from(widget.filterState.selectedLeitnerBins);
    }
    
    // Initialize learning status - default to all if empty
    if (widget.filterState.selectedLearningStatus.isEmpty) {
      _pendingLearningStatus = {'new', 'due', 'learned'};
    } else {
      _pendingLearningStatus = Set<String>.from(widget.filterState.selectedLearningStatus);
    }
  }

  void _applyPendingChanges() {
    // Apply all pending filter changes via callback
    // Use pending values if set, otherwise fall back to current filter state
    // This ensures all filters are explicitly passed and topic selection doesn't affect other filters
    widget.onApplyFilters(
      topicIds: _pendingTopicIds ?? widget.filterState.selectedTopicIds,
      showLemmasWithoutTopic: _pendingShowLemmasWithoutTopic ?? widget.filterState.showLemmasWithoutTopic,
      levels: _pendingLevels ?? widget.filterState.selectedLevels,
      partOfSpeech: _pendingPartOfSpeech ?? widget.filterState.selectedPartOfSpeech,
      includeLemmas: _pendingIncludeLemmas ?? widget.filterState.includeLemmas,
      includePhrases: _pendingIncludePhrases ?? widget.filterState.includePhrases,
      hasImages: _pendingHasImages ?? widget.filterState.hasImages,
      hasNoImages: _pendingHasNoImages ?? widget.filterState.hasNoImages,
      hasAudio: _pendingHasAudio ?? widget.filterState.hasAudio,
      hasNoAudio: _pendingHasNoAudio ?? widget.filterState.hasNoAudio,
      isComplete: _pendingIsComplete ?? widget.filterState.isComplete,
      isIncomplete: _pendingIsIncomplete ?? widget.filterState.isIncomplete,
      leitnerBins: _pendingLeitnerBins ?? widget.filterState.selectedLeitnerBins,
      learningStatus: _pendingLearningStatus ?? widget.filterState.selectedLearningStatus,
    );
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
                    _buildLemmasPhrasesFilter(),
                    const Divider(height: 1),
                    _buildIncludeWithFilter(),
                    const Divider(height: 1),
                    _buildTopicsFilter(),
                    const Divider(height: 1),
                    _buildLevelsFilter(),
                    const Divider(height: 1),
                    _buildPartOfSpeechFilter(),
                    const Divider(height: 1),
                    _buildLeitnerBinsFilter(),
                    const Divider(height: 1),
                    _buildLearningStatusFilter(),
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

  Widget _buildLemmasPhrasesFilter() {
    return StatefulBuilder(
      builder: (context, setMenuState) {
        final currentIncludeLemmas = _pendingIncludeLemmas ?? widget.filterState.includeLemmas;
        final currentIncludePhrases = _pendingIncludePhrases ?? widget.filterState.includePhrases;
        final allSelected = currentIncludeLemmas && currentIncludePhrases;
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVerticalTitle('TYPE'),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'Lemmas',
                      isSelected: currentIncludeLemmas,
                      onTap: () {
                        setMenuState(() {
                          _pendingIncludeLemmas = !currentIncludeLemmas;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Phrases',
                      isSelected: currentIncludePhrases,
                      onTap: () {
                        setMenuState(() {
                          _pendingIncludePhrases = !currentIncludePhrases;
                        });
                      },
                    ),
                    _buildAllOnButton(
                      allSelected: allSelected,
                      onPressed: () {
                        setMenuState(() {
                          final newValue = !allSelected;
                          _pendingIncludeLemmas = newValue;
                          _pendingIncludePhrases = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIncludeWithFilter() {
    return StatefulBuilder(
      builder: (context, setMenuState) {
        final currentHasImages = _pendingHasImages ?? widget.filterState.hasImages;
        final currentHasNoImages = _pendingHasNoImages ?? widget.filterState.hasNoImages;
        final currentHasAudio = _pendingHasAudio ?? widget.filterState.hasAudio;
        final currentHasNoAudio = _pendingHasNoAudio ?? widget.filterState.hasNoAudio;
        final currentIsComplete = _pendingIsComplete ?? widget.filterState.isComplete;
        final currentIsIncomplete = _pendingIsIncomplete ?? widget.filterState.isIncomplete;
        final allSelected = currentHasImages && currentHasNoImages && 
            currentHasAudio && currentHasNoAudio && 
            currentIsComplete && currentIsIncomplete;
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVerticalTitle('INCLUDE'),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'Image',
                      isSelected: currentHasImages,
                      onTap: () {
                        setMenuState(() {
                          _pendingHasImages = !currentHasImages;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'No Image',
                      isSelected: currentHasNoImages,
                      onTap: () {
                        setMenuState(() {
                          _pendingHasNoImages = !currentHasNoImages;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Audio',
                      isSelected: currentHasAudio,
                      onTap: () {
                        setMenuState(() {
                          _pendingHasAudio = !currentHasAudio;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'No Audio',
                      isSelected: currentHasNoAudio,
                      onTap: () {
                        setMenuState(() {
                          _pendingHasNoAudio = !currentHasNoAudio;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Complete',
                      isSelected: currentIsComplete,
                      onTap: () {
                        setMenuState(() {
                          _pendingIsComplete = !currentIsComplete;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Incomplete',
                      isSelected: currentIsIncomplete,
                      onTap: () {
                        setMenuState(() {
                          _pendingIsIncomplete = !currentIsIncomplete;
                        });
                      },
                    ),
                    _buildAllOnButton(
                      allSelected: allSelected,
                      onPressed: () {
                        setMenuState(() {
                          final newValue = !allSelected;
                          _pendingHasImages = newValue;
                          _pendingHasNoImages = newValue;
                          _pendingHasAudio = newValue;
                          _pendingHasNoAudio = newValue;
                          _pendingIsComplete = newValue;
                          _pendingIsIncomplete = newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopicsFilter() {
    if (widget.isLoadingTopics) {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerticalTitle('TOPICS'),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      );
    } else if (widget.topics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerticalTitle('TOPICS'),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  'No topics available',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return StatefulBuilder(
        builder: (context, setMenuState) {
          final currentTopicIds = _pendingTopicIds ?? widget.filterState.selectedTopicIds;
          final allTopicIds = widget.topics.map((t) => t.id).toSet();
          final allSelected = allTopicIds.isNotEmpty && 
              currentTopicIds.length == allTopicIds.length &&
              currentTopicIds.containsAll(allTopicIds);
          return Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVerticalTitle('TOPICS'),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...widget.topics.map((topic) {
                        final isSelected = currentTopicIds.contains(topic.id);
                        return _buildFilterChip(
                          label: _capitalizeWords(topic.name),
                          isSelected: isSelected,
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
                        );
                      }),
                      _buildAllOnButton(
                        allSelected: allSelected,
                        onPressed: () {
                          setMenuState(() {
                            if (allSelected) {
                              _pendingTopicIds = <int>{};
                            } else {
                              _pendingTopicIds = Set<int>.from(allTopicIds);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildLevelsFilter() {
    return StatefulBuilder(
      builder: (context, setMenuState) {
        final currentLevels = _pendingLevels ?? widget.filterState.selectedLevels;
        final allLevels = FilterConstants.cefrLevels.toSet();
        final allSelected = currentLevels.length == allLevels.length &&
            currentLevels.containsAll(allLevels);
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVerticalTitle('CEFR'),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...FilterConstants.cefrLevels.map((level) {
                      final isSelected = currentLevels.contains(level);
                      return _buildFilterChip(
                        label: level,
                        isSelected: isSelected,
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
                      );
                    }),
                    _buildAllOnButton(
                      allSelected: allSelected,
                      onPressed: () {
                        setMenuState(() {
                          if (allSelected) {
                            _pendingLevels = <String>{};
                          } else {
                            _pendingLevels = Set<String>.from(allLevels);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPartOfSpeechFilter() {
    return StatefulBuilder(
      builder: (context, setMenuState) {
        final currentPartOfSpeech = _pendingPartOfSpeech ?? widget.filterState.selectedPartOfSpeech;
        final allPOS = FilterConstants.partOfSpeechValues.toSet();
        final allSelected = currentPartOfSpeech.length == allPOS.length &&
            currentPartOfSpeech.containsAll(allPOS);
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVerticalTitle('PART OF SPEECH'),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...FilterConstants.partOfSpeechValues.map((pos) {
                      final isSelected = currentPartOfSpeech.contains(pos);
                      return _buildFilterChip(
                        label: pos,
                        isSelected: isSelected,
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
                      );
                    }),
                    _buildAllOnButton(
                      allSelected: allSelected,
                      onPressed: () {
                        setMenuState(() {
                          if (allSelected) {
                            _pendingPartOfSpeech = <String>{};
                          } else {
                            _pendingPartOfSpeech = Set<String>.from(allPOS);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeitnerBinsFilter() {
    // Show all bins from 1 to maxBins, all selectable
    
    return StatefulBuilder(
      builder: (context, setMenuState) {
        final currentBins = _pendingLeitnerBins ?? widget.filterState.selectedLeitnerBins;
        
        // Generate all bins from 1 to maxBins
        final allBins = List.generate(widget.maxBins, (index) => index + 1);
        final allBinsSet = allBins.toSet();
        
        // Check if all bins are selected
        final allBinsSelected = allBinsSet.isNotEmpty && 
            currentBins.length == allBinsSet.length &&
            currentBins.containsAll(allBinsSet);
        
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVerticalTitle('BINS'),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...allBins.map((bin) {
                          final isSelected = currentBins.contains(bin);
                          return _buildFilterChip(
                            label: bin.toString(),
                            isSelected: isSelected,
                            onTap: () {
                              setMenuState(() {
                                final newSet = Set<int>.from(currentBins);
                                if (isSelected) {
                                  newSet.remove(bin);
                                } else {
                                  newSet.add(bin);
                                }
                                _pendingLeitnerBins = newSet;
                              });
                            },
                          );
                        }),
                        _buildAllOnButton(
                          allSelected: allBinsSelected,
                          onPressed: () {
                            setMenuState(() {
                              if (allBinsSelected) {
                                _pendingLeitnerBins = <int>{};
                              } else {
                                _pendingLeitnerBins = Set<int>.from(allBinsSet);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLearningStatusFilter() {
    return StatefulBuilder(
      builder: (context, setMenuState) {
        final currentStatus = _pendingLearningStatus ?? widget.filterState.selectedLearningStatus;
        final allStatuses = {'new', 'due', 'learned'};
        final allSelected = currentStatus.length == allStatuses.length &&
            currentStatus.containsAll(allStatuses);
        return Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVerticalTitle('STATUS'),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip(
                      label: 'New',
                      isSelected: currentStatus.contains('new'),
                      onTap: () {
                        setMenuState(() {
                          final newSet = Set<String>.from(currentStatus);
                          if (currentStatus.contains('new')) {
                            newSet.remove('new');
                          } else {
                            newSet.add('new');
                          }
                          _pendingLearningStatus = newSet;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Due',
                      isSelected: currentStatus.contains('due'),
                      onTap: () {
                        setMenuState(() {
                          final newSet = Set<String>.from(currentStatus);
                          if (currentStatus.contains('due')) {
                            newSet.remove('due');
                          } else {
                            newSet.add('due');
                          }
                          _pendingLearningStatus = newSet;
                        });
                      },
                    ),
                    _buildFilterChip(
                      label: 'Learned',
                      isSelected: currentStatus.contains('learned'),
                      onTap: () {
                        setMenuState(() {
                          final newSet = Set<String>.from(currentStatus);
                          if (currentStatus.contains('learned')) {
                            newSet.remove('learned');
                          } else {
                            newSet.add('learned');
                          }
                          _pendingLearningStatus = newSet;
                        });
                      },
                    ),
                    _buildAllOnButton(
                      allSelected: allSelected,
                      onPressed: () {
                        setMenuState(() {
                          if (allSelected) {
                            _pendingLearningStatus = <String>{};
                          } else {
                            _pendingLearningStatus = Set<String>.from(allStatuses);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerticalTitle(String title) {
    return RotatedBox(
      quarterTurns: -1, // 90 degrees counter-clockwise for vertical text reading top to bottom
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAllOnButton({
    required bool allSelected,
    required VoidCallback? onPressed,
    bool isEnabled = true,
  }) {
    final isDisabled = !isEnabled || onPressed == null;
    
    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Text(
          allSelected ? 'All Off' : 'All On',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDisabled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    final isDisabled = !isEnabled || onTap == null;
    
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isDisabled
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)
                : isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDisabled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                : isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the filter bottom sheet
void showFilterSheet({
  required BuildContext context,
  required FilterState filterState,
  required FilterUpdateCallback onApplyFilters,
  required List<Topic> topics,
  bool isLoadingTopics = false,
  List<int> availableBins = const [],
  int? userId,
  int maxBins = 7, // Default to 7 if not provided
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => FilterSheet(
      filterState: filterState,
      onApplyFilters: onApplyFilters,
      topics: topics,
      isLoadingTopics: isLoadingTopics,
      availableBins: availableBins,
      userId: userId,
      maxBins: maxBins,
    ),
  );
}


