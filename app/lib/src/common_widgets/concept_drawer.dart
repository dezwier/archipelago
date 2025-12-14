import 'package:flutter/material.dart';
import '../utils/html_entity_decoder.dart';
import '../utils/language_emoji.dart';
import '../features/dictionary/domain/paired_dictionary_item.dart';
import '../features/dictionary/domain/dictionary_card.dart';
import '../features/dictionary/data/dictionary_service.dart';
import '../features/generate_flashcards/data/flashcard_service.dart';
import '../features/dictionary/presentation/widgets/language_lemma_widget.dart';
import '../features/dictionary/presentation/widgets/concept_image_widget.dart';
import '../features/dictionary/presentation/widgets/dictionary_action_buttons.dart';
import '../features/dictionary/presentation/widgets/concept_info_widget.dart';

/// A generic drawer widget that displays concept details based on a concept ID.
/// This widget can be used anywhere in the app to show concept information.
class ConceptDrawer extends StatefulWidget {
  final int conceptId;
  final Map<String, bool>? languageVisibility;
  final List<String>? languagesToShow;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onItemUpdated; // Called when item is updated (for parent to refresh)

  const ConceptDrawer({
    super.key,
    required this.conceptId,
    this.languageVisibility,
    this.languagesToShow,
    this.onEdit,
    this.onDelete,
    this.onItemUpdated,
  });

  @override
  State<ConceptDrawer> createState() => _ConceptDrawerState();
}

class _ConceptDrawerState extends State<ConceptDrawer> {
  PairedDictionaryItem? _item;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isEditing = false;
  final Set<String> _retrievingLanguages = {};

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

  @override
  void initState() {
    super.initState();
    _loadConcept();
  }

  Future<void> _loadConcept() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get visible language codes for the API call
      // If languageVisibility is provided, use it; otherwise fetch all languages
      List<String> visibleLanguageCodes = [];
      if (widget.languageVisibility != null) {
        visibleLanguageCodes = widget.languageVisibility!.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();
      }
      // If no language visibility specified, pass empty list to get all languages

      final result = await DictionaryService.getConceptById(
        conceptId: widget.conceptId,
        visibleLanguageCodes: visibleLanguageCodes,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final itemData = result['item'] as Map<String, dynamic>;
        setState(() {
          _item = PairedDictionaryItem.fromJson(itemData);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] as String? ?? 'Failed to load concept';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading concept: ${e.toString()}';
        _isLoading = false;
      });
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
                          child: _item == null
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
                              : _isEditing
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
                                                ConceptInfoWidget(item: _item!),
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
                        // Content
                        Expanded(
                          child: _isLoading || _item == null
                              ? const SizedBox.shrink()
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 24),
                                      ..._buildLanguageSections(context),
                                    ],
                                  ),
                                ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LanguageLemmaWidget(
                card: card,
                languageCode: languageCode,
                showDescription: true,
                showExtraInfo: true,
                translationController: null,
                isEditing: false,
                partOfSpeech: _item?.partOfSpeech,
              ),
            ),
            // Retrieve button on the right
            if (_retrievingLanguages.contains(languageCode))
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
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
        // Button or spinner on the right
        if (_retrievingLanguages.contains(languageCode))
          SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          )
        else
          IconButton(
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
    ),
  );
}
