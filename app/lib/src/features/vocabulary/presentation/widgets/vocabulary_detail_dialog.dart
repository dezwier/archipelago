import 'package:flutter/material.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../../../utils/language_emoji.dart';
import '../../domain/paired_vocabulary_item.dart';
import '../../domain/vocabulary_card.dart';
import '../../../generate_flashcards/data/flashcard_service.dart';
import '../../../profile/data/language_service.dart';
import 'language_lemma_widget.dart';
import 'vocabulary_image_section.dart';
import 'vocabulary_action_buttons.dart';
import 'concept_info_widget.dart';

class VocabularyDetailDrawer extends StatefulWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final Map<String, bool> languageVisibility;
  final List<String> languagesToShow;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(PairedVocabularyItem)? onItemUpdated;

  const VocabularyDetailDrawer({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    required this.languageVisibility,
    required this.languagesToShow,
    this.onEdit,
    this.onDelete,
    this.onItemUpdated,
  });

  @override
  State<VocabularyDetailDrawer> createState() => _VocabularyDetailDrawerState();
}

class _VocabularyDetailDrawerState extends State<VocabularyDetailDrawer> {
  bool _isEditing = false;
  final Set<String> _retrievingLanguages = {}; // Track which languages are being retrieved


  void _handleSave() {
    // Edit mode is only for images, so we just exit edit mode
    // Image changes are handled directly by VocabularyImageSection
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
  void dispose() {
    super.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Close button
                  const SizedBox(height: 20),
          // Images and buttons layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _isEditing
                ? Column(
                    children: [
                      // Images on top
                      VocabularyImageSection(
                        item: widget.item,
                        isEditing: _isEditing,
                        onItemUpdated: widget.onItemUpdated,
                      ),
                      const SizedBox(height: 12),
                      // Action buttons horizontally below
                      VocabularyActionButtons(
                        isEditing: _isEditing,
                        onEdit: () {
                          // Keep screen as is - no functionality yet
                        },
                        onSave: _handleSave,
                        onCancel: _handleCancel,
                        onRegenerate: null, // Removed generate all button
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
                        child: VocabularyImageSection(
                          item: widget.item,
                          isEditing: _isEditing,
                          onItemUpdated: widget.onItemUpdated,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Concept info and buttons on right - 50% width
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Concept info on top
                            if (widget.item.conceptTerm != null || 
                                widget.item.conceptDescription != null)
                              ConceptInfoWidget(item: widget.item),
                            if (widget.item.conceptTerm != null || 
                                widget.item.conceptDescription != null)
                              const SizedBox(height: 12),
                            // Action buttons below
                            VocabularyActionButtons(
                              isEditing: _isEditing,
                              onEdit: () {
                                // Keep screen as is - no functionality yet
                              },
                              onSave: _handleSave,
                              onCancel: _handleCancel,
                              onRegenerate: null, // Removed generate all button
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
            child: SingleChildScrollView(
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
    // Build sections for all visible languages in order
    // Show placeholders for missing cards
    final widgets = <Widget>[];
    
    for (int i = 0; i < widget.languagesToShow.length; i++) {
      final languageCode = widget.languagesToShow[i];
      
      // Skip if language is not visible
      if (widget.languageVisibility[languageCode] != true) {
        continue;
      }
      
      if (i > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        );
      }
      
      // Check if card exists for this language
      final card = widget.item.getCardByLanguage(languageCode);
      
      if (card != null) {
        // Show card normally
        widgets.add(
          _buildLanguageSection(
            context,
            card: card,
            languageCode: languageCode,
          ),
        );
      } else {
        // Show placeholder for missing card
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
    required VocabularyCard card,
    required String languageCode,
  }) {
    // Edit mode is only for images, not for terms
    // Always pass null for translationController and false for isEditing
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
                partOfSpeech: widget.item.partOfSpeech,
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
                          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        if (card.notes != null && card.notes!.isNotEmpty && !_isEditing) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    HtmlEntityDecoder.decode(card.notes!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    if (!mounted) return;
    
    // Set loading state
    setState(() {
      _retrievingLanguages.add(languageCode);
    });

    try {
      // Get concept term, description, and part_of_speech
      final term = widget.item.conceptTerm ?? widget.item.sourceCard?.translation ?? '';
      final description = widget.item.conceptDescription;
      final partOfSpeech = widget.item.partOfSpeech;
      
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
        conceptId: widget.item.conceptId,
      );

      if (!mounted) return;
      
      // Clear loading state
      setState(() {
        _retrievingLanguages.remove(languageCode);
      });

      if (result['success'] == true) {
        // Refresh the item by calling onItemUpdated
        // This will refresh the vocabulary list and reopen the dialog with updated data
        widget.onItemUpdated?.call(widget.item);
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
