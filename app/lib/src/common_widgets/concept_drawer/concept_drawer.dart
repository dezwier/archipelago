import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/utils/html_entity_decoder.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/dictionary/domain/dictionary_card.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/create/data/flashcard_service.dart';
import 'slidable_lemma_widget.dart';
import 'concept_image_widget.dart';
import 'concept_image_buttons.dart';
import 'concept_info_widget.dart';

/// A generic drawer widget that displays concept details based on a concept ID.
/// This widget can be used anywhere in the app to show concept information.
class ConceptDrawer extends StatefulWidget {
  final int conceptId;
  final Map<String, bool>? languageVisibility;
  final List<String>? languagesToShow;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onItemUpdated; // Called when item is updated (for parent to refresh)
  final int? userId; // Optional user ID, will be loaded from SharedPreferences if not provided

  const ConceptDrawer({
    super.key,
    required this.conceptId,
    this.languageVisibility,
    this.languagesToShow,
    this.onEdit,
    this.onDelete,
    this.onItemUpdated,
    this.userId,
  });

  @override
  State<ConceptDrawer> createState() => _ConceptDrawerState();
}

class _ConceptDrawerState extends State<ConceptDrawer> {
  PairedDictionaryItem? _item;
  bool _isLoading = true;
  bool _isLoadingLemmas = true;
  bool _isLoadingTopic = false;
  String? _errorMessage;
  bool _isEditing = false;
  final Set<String> _retrievingLanguages = {};
  int? _userId;
  
  // Partial data for progressive loading
  Map<String, dynamic>? _conceptData;
  List<dynamic>? _lemmasData;
  Map<String, dynamic>? _topicData;

  // Default language visibility - show all languages if not provided
  Map<String, bool> _getLanguageVisibility() {
    if (widget.languageVisibility != null) {
      return widget.languageVisibility!;
    }
    // Default: show all languages that have cards
    if (_item == null) return {};
    final langCodes = _item!.cards.map((c) => c.languageCode).toSet().toList();
    return {
      for (var langCode in langCodes) langCode: true
    };
  }

  // Default languages to show - use all languages from item if not provided
  List<String> _getLanguagesToShow() {
    if (widget.languagesToShow != null) {
      return widget.languagesToShow!;
    }
    // Default: show all languages that have cards, in order
    if (_item == null) return [];
    return _item!.cards.map((c) => c.languageCode).toList();
  }

  /// Check if we should show placeholder (no concept data yet)
  bool _shouldShowPlaceholder() {
    return _item == null;
  }

  /// Check if we should show content area
  bool _shouldShowContent() {
    // Show content if we have lemmas data or if item is built
    return _lemmasData != null || _item != null;
  }

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) => _loadConcept());
  }

  Future<void> _loadUserId() async {
    // Use provided userId or load from SharedPreferences
    if (widget.userId != null) {
      _userId = widget.userId;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _userId = userMap['id'] as int?;
      }
    } catch (e) {
      // If loading fails, continue without userId
      _userId = null;
    }
  }

  Future<void> _loadConcept() async {
    setState(() {
      _isLoading = true;
      _isLoadingLemmas = true;
      _isLoadingTopic = false;
      _errorMessage = null;
      _conceptData = null;
      _lemmasData = null;
      _topicData = null;
    });

    // Get visible language codes for the API call
    List<String> visibleLanguageCodes = [];
    if (widget.languageVisibility != null) {
      visibleLanguageCodes = widget.languageVisibility!.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
    }

    // Start all API calls in parallel for faster loading
    final conceptFuture = DictionaryService.getConceptDataOnly(widget.conceptId);
    final lemmasFuture = DictionaryService.getLemmasOnly(
      widget.conceptId,
      visibleLanguageCodes,
      userId: _userId,
    );
    
    // Handle concept data (needed first to check for topic_id)
    conceptFuture.then((result) {
      if (!mounted) return;
      
      if (result['success'] == true) {
        final conceptData = result['data'] as Map<String, dynamic>;
        setState(() {
          _conceptData = conceptData;
        });
        
        // Build partial item immediately with concept data
        _tryBuildItem();
        
        // Start topic fetch if topic_id exists
        final topicId = conceptData['topic_id'] as int?;
        if (topicId != null) {
          setState(() {
            _isLoadingTopic = true;
          });
          
          DictionaryService.getTopicDataOnly(topicId).then((topicResult) {
            if (!mounted) return;
            
            if (topicResult['success'] == true) {
              setState(() {
                _topicData = topicResult['data'] as Map<String, dynamic>?;
                _isLoadingTopic = false;
              });
            } else {
              setState(() {
                _isLoadingTopic = false;
              });
            }
            
            // Update item with topic data
            _tryBuildItem();
          });
        } else {
          setState(() {
            _isLoadingTopic = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Failed to load concept';
          _isLoading = false;
        });
      }
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading concept: ${e.toString()}';
        _isLoading = false;
      });
    });
    
    // Handle lemmas data
    lemmasFuture.then((result) {
      if (!mounted) return;
      
      if (result['success'] == true) {
        setState(() {
          _lemmasData = result['data'] as List<dynamic>;
          _isLoadingLemmas = false;
        });
        _tryBuildItem();
      } else {
        setState(() {
          _isLoadingLemmas = false;
          // Don't set error here - concept might still be loading
          // Only set error if concept also failed
          if (_conceptData == null) {
            _errorMessage = result['message'] as String? ?? 'Failed to load lemmas';
            _isLoading = false;
          }
        });
      }
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLemmas = false;
        if (_conceptData == null) {
          _errorMessage = 'Error loading lemmas: ${e.toString()}';
          _isLoading = false;
        }
      });
    });
  }

  /// Try to build the PairedDictionaryItem when we have enough data
  /// Can build partial item with just concept data, then update as more data arrives
  void _tryBuildItem() {
    // Need at least concept data to build a partial item
    if (_conceptData == null) {
      return;
    }
    
    try {
      // Extract topic information
      String? topicName;
      String? topicDescription;
      String? topicIcon;
      final topicId = _conceptData!['topic_id'] as int?;
      
      if (_topicData != null) {
        topicName = _topicData!['name'] as String?;
        topicDescription = _topicData!['description'] as String?;
        topicIcon = _topicData!['icon'] as String?;
      }

      // Construct PairedDictionaryItem format
      // Use empty list for lemmas if not loaded yet
      final itemData = <String, dynamic>{
        'concept_id': widget.conceptId,
        'lemmas': _lemmasData ?? [],
        'concept_term': _conceptData!['term'],
        'concept_description': _conceptData!['description'],
        'part_of_speech': _conceptData!['part_of_speech'],
        'concept_level': _conceptData!['level'],
        'image_url': _conceptData!['image_url'],
        'image_path_1': _conceptData!['image_path_1'],
        'topic_id': topicId,
        'topic_name': topicName,
        'topic_description': topicDescription,
        'topic_icon': topicIcon,
      };

      if (mounted) {
        setState(() {
          _item = PairedDictionaryItem.fromJson(itemData);
          // Only mark as fully loaded when we have both concept and lemmas
          if (_lemmasData != null && !_isLoadingTopic) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error building concept item: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _handleSave() {
    setState(() {
      _isEditing = false;
    });
  }

  void _handleCancel() {
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadConcept,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _item == null && !_isLoading
              ? const Center(child: Text('Concept not found'))
              : Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Drag handle
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Images and buttons layout
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _shouldShowPlaceholder()
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Placeholder for image on left - 50% width
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        height: 150,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Placeholder for info and buttons on right - 50% width
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Placeholder for concept info
                                          Container(
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // Placeholder for action buttons
                                          Container(
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : _item != null && _isEditing
                                  ? Column(
                                      children: [
                                        // Images on top
                                        ConceptImageWidget(
                                          item: _item!,
                                          onItemUpdated: (updatedItem) async {
                                            // Reload the concept to get updated data
                                            await _loadConcept();
                                            widget.onItemUpdated?.call();
                                          },
                                          showEditButtons: false,
                                          onEditButtonsChanged: () {},
                                        ),
                                        const SizedBox(height: 12),
                                        // Action buttons horizontally below
                                        DictionaryActionButtons(
                                          isEditing: _isEditing,
                                          onEdit: () {
                                            widget.onEdit?.call();
                                          },
                                          onSave: _handleSave,
                                          onCancel: _handleCancel,
                                          onRegenerate: null,
                                          onDelete: () {
                                            widget.onDelete?.call();
                                          },
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Image on left - 50% width
                                        Expanded(
                                          flex: 1,
                                          child: ConceptImageWidget(
                                            item: _item!,
                                            onItemUpdated: (updatedItem) async {
                                              // Reload the concept to get updated data
                                              await _loadConcept();
                                              widget.onItemUpdated?.call();
                                            },
                                            showEditButtons: false,
                                            onEditButtonsChanged: () {},
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Concept info and buttons on right - 50% width
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Concept info on top
                                              if (_item!.conceptTerm != null ||
                                                  _item!.conceptDescription != null ||
                                                  _item!.topicName != null ||
                                                  _item!.topicDescription != null)
                                                ConceptInfoWidget(
                                                  item: _item!,
                                                ),
                                              if (_item!.conceptTerm != null ||
                                                  _item!.conceptDescription != null ||
                                                  _item!.topicName != null ||
                                                  _item!.topicDescription != null)
                                                const SizedBox(height: 12),
                                              // Action buttons below
                                              DictionaryActionButtons(
                                                isEditing: _isEditing,
                                                onEdit: () {
                                                  widget.onEdit?.call();
                                                },
                                                onSave: _handleSave,
                                                onCancel: _handleCancel,
                                                onRegenerate: null,
                                                onDelete: () {
                                                  widget.onDelete?.call();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                        ),
                        // Content - show progressively as data loads
                        Expanded(
                          child: _shouldShowContent()
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 24),
                                      if (_isLoadingLemmas && _item == null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      else if (_item != null)
                                        ..._buildLanguageSections(context),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
    );
  }

  List<Widget> _buildLanguageSections(BuildContext context) {
    if (_item == null) return [];

    final languageVisibility = _getLanguageVisibility();
    final languagesToShow = _getLanguagesToShow();

    // Build sections for all visible languages in order
    // Show placeholders for missing cards
    final widgets = <Widget>[];

    for (int i = 0; i < languagesToShow.length; i++) {
      final languageCode = languagesToShow[i];

      // Skip if language is not visible
      if (languageVisibility[languageCode] != true) {
        continue;
      }

      if (i > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.2),
            ),
          ),
        );
      }

      // Check if lemma exists for this language
      final card = _item!.getCardByLanguage(languageCode);

      if (card != null) {
        // Show lemma normally
        widgets.add(
          _buildLanguageSection(
            context,
            card: card,
            languageCode: languageCode,
          ),
        );
      } else {
        // Show placeholder for missing lemma
        widgets.add(
          _buildPlaceholderSection(
            context,
            languageCode: languageCode,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildLanguageSection(
    BuildContext context, {
    required DictionaryCard card,
    required String languageCode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlidableLemmaWidget(
          card: card,
          languageCode: languageCode,
          showDescription: true,
          showExtraInfo: true,
          partOfSpeech: _item?.partOfSpeech,
          topicName: _item?.topicName,
          onRegenerate: () => _handleRetrieveLemma(languageCode),
          isRetrieving: _retrievingLanguages.contains(languageCode),
        ),
        // Notes
        if (card.notes != null &&
            card.notes!.isNotEmpty &&
            !_isEditing) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    HtmlEntityDecoder.decode(card.notes!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaceholderSection(
    BuildContext context, {
    required String languageCode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language flag emoji
        Text(
          LanguageEmoji.getEmoji(languageCode),
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 8),
        // Placeholder text
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Lemma to be retrieved',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ),
        ),
        // Retrieve button - still visible for placeholders since there's no card to slide
        if (_retrievingLanguages.contains(languageCode))
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4.0),
            child: IconButton(
              onPressed: () => _handleRetrieveLemma(languageCode),
              icon: const Icon(Icons.auto_awesome, size: 16),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: 'Retrieve lemma',
            ),
          ),
      ],
    );
  }

  Future<void> _handleRetrieveLemma(String languageCode) async {
    if (!mounted || _item == null) return;

    // Set loading state
    setState(() {
      _retrievingLanguages.add(languageCode);
    });

    try {
      // Get concept term, description, and part_of_speech
      final term = _item!.conceptTerm ?? _item!.sourceCard?.translation ?? '';
      final description = _item!.conceptDescription;
      final partOfSpeech = _item!.partOfSpeech;

      if (term.isEmpty) {
        if (!mounted) return;
        setState(() {
          _retrievingLanguages.remove(languageCode);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concept term is missing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await FlashcardService.generateLemma(
        term: term,
        targetLanguage: languageCode,
        description: description,
        partOfSpeech: partOfSpeech,
        conceptId: _item!.conceptId,
      );

      if (!mounted) return;

      // Clear loading state
      setState(() {
        _retrievingLanguages.remove(languageCode);
      });

      if (result['success'] == true) {
        // Reload the concept to get the updated data
        await _loadConcept();
        widget.onItemUpdated?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] as String? ?? 'Failed to retrieve lemma',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Clear loading state
      setState(() {
        _retrievingLanguages.remove(languageCode);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error retrieving lemma: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

/// Helper function to show a concept drawer from anywhere in the app.
/// 
/// Example usage:
/// ```dart
/// showConceptDrawer(
///   context,
///   conceptId: 123,
///   languageVisibility: {'en': true, 'es': true},
///   languagesToShow: ['en', 'es'],
/// );
/// ```
void showConceptDrawer(
  BuildContext context, {
  required int conceptId,
  Map<String, bool>? languageVisibility,
  List<String>? languagesToShow,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onItemUpdated,
  int? userId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ConceptDrawer(
      conceptId: conceptId,
      languageVisibility: languageVisibility,
      languagesToShow: languagesToShow,
      onEdit: onEdit,
      onDelete: onDelete,
      onItemUpdated: onItemUpdated,
      userId: userId,
    ),
  );
}
