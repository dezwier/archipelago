import 'package:flutter/material.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../domain/paired_vocabulary_item.dart';
import '../../domain/vocabulary_card.dart';
import '../../data/vocabulary_service.dart';
import '../../../generate_flashcards/data/flashcard_service.dart';
import '../../../profile/data/language_service.dart';
import 'language_lemma_widget.dart';
import 'vocabulary_image_section.dart';
import 'vocabulary_action_buttons.dart';
import 'concept_info_widget.dart';
import 'regenerate_language_dialog.dart';

class VocabularyDetailDrawer extends StatefulWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final Map<String, bool> languageVisibility;
  final List<String> languagesToShow;
  final VoidCallback? onEdit;
  final VoidCallback? onRandomCard;
  final VoidCallback? onRefreshImages;
  final Function(PairedVocabularyItem)? onItemUpdated;

  const VocabularyDetailDrawer({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    required this.languageVisibility,
    required this.languagesToShow,
    this.onEdit,
    this.onRandomCard,
    this.onRefreshImages,
    this.onItemUpdated,
  });

  @override
  State<VocabularyDetailDrawer> createState() => _VocabularyDetailDrawerState();
}

class _VocabularyDetailDrawerState extends State<VocabularyDetailDrawer> {
  bool _isEditing = false;
  late TextEditingController _sourceTranslationController;
  late TextEditingController _targetTranslationController;

  @override
  void initState() {
    super.initState();
    _sourceTranslationController = TextEditingController(
      text: widget.item.sourceCard?.translation ?? '',
    );
    _targetTranslationController = TextEditingController(
      text: widget.item.targetCard?.translation ?? '',
    );
  }


  Future<void> _handleSave() async {
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      bool hasChanges = false;

      // Update source card if it exists and translation changed
      if (widget.item.sourceCard != null) {
        final newTranslation = _sourceTranslationController.text.trim();
        if (newTranslation.isNotEmpty && newTranslation != widget.item.sourceCard!.translation) {
          final result = await VocabularyService.updateCard(
            cardId: widget.item.sourceCard!.id,
            translation: newTranslation,
          );
          
          if (result['success'] != true) {
            if (!mounted) return;
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] as String? ?? 'Failed to update source card'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }
          hasChanges = true;
        }
      }

      // Update target card if it exists and translation changed
      if (widget.item.targetCard != null) {
        final newTranslation = _targetTranslationController.text.trim();
        if (newTranslation.isNotEmpty && newTranslation != widget.item.targetCard!.translation) {
          final result = await VocabularyService.updateCard(
            cardId: widget.item.targetCard!.id,
            translation: newTranslation,
          );
          
          if (result['success'] != true) {
            if (!mounted) return;
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] as String? ?? 'Failed to update target card'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }
          hasChanges = true;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (hasChanges) {
        // Notify parent to refresh the item
        widget.onItemUpdated?.call(widget.item);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }

      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _handleCancel() {
    setState(() {
      _isEditing = false;
      // Reset controllers to original values
      _sourceTranslationController.text = widget.item.sourceCard?.translation ?? '';
      _targetTranslationController.text = widget.item.targetCard?.translation ?? '';
    });
  }

  Future<void> _handleRegenerate() async {
    // Load available languages
    final languages = await LanguageService.getLanguages();
    if (languages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No languages available')),
      );
      return;
    }

    // Show language selection dialog
    if (!mounted) return;
    final selectedLanguages = await RegenerateLanguageDialog.show(context, languages);
    
    if (selectedLanguages == null || selectedLanguages.isEmpty) {
      return; // User cancelled or didn't select any languages
    }

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await FlashcardService.generateCardsForConcept(
        conceptId: widget.item.conceptId,
        languages: selectedLanguages,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        // Notify parent to refresh the item
        widget.onItemUpdated?.call(widget.item);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cards regenerated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Failed to regenerate cards'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error regenerating cards: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sourceTranslationController.dispose();
    _targetTranslationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85; // 85% of screen height
    
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: Container(
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
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
                            setState(() {
                              _isEditing = true;
                              _sourceTranslationController.text = widget.item.sourceCard?.translation ?? '';
                              _targetTranslationController.text = widget.item.targetCard?.translation ?? '';
                            });
                          },
                          onSave: _handleSave,
                          onCancel: _handleCancel,
                          onRefreshImages: widget.onRefreshImages,
                          onRandomCard: () {
                            Navigator.of(context).pop();
                            widget.onRandomCard?.call();
                          },
                          onRegenerate: _handleRegenerate,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image on left
                        VocabularyImageSection(
                          item: widget.item,
                          isEditing: _isEditing,
                          onItemUpdated: widget.onItemUpdated,
                        ),
                        const SizedBox(width: 12),
                        // Action buttons on right
                        VocabularyActionButtons(
                          isEditing: _isEditing,
                          onEdit: () {
                            setState(() {
                              _isEditing = true;
                              _sourceTranslationController.text = widget.item.sourceCard?.translation ?? '';
                              _targetTranslationController.text = widget.item.targetCard?.translation ?? '';
                            });
                          },
                          onSave: _handleSave,
                          onCancel: _handleCancel,
                          onRefreshImages: widget.onRefreshImages,
                          onRandomCard: () {
                            Navigator.of(context).pop();
                            widget.onRandomCard?.call();
                          },
                          onRegenerate: _handleRegenerate,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildLanguageSections(context),
                    if (widget.item.conceptTerm != null || 
                        widget.item.conceptDescription != null) ...[
                      const SizedBox(height: 24),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 12),
                      ConceptInfoWidget(item: widget.item),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }


  List<Widget> _buildLanguageSections(BuildContext context) {
    // Filter visible cards and sort by the languagesToShow order
    final visibleCards = widget.item.cards
        .where((card) => widget.languageVisibility[card.languageCode] ?? true)
        .toList();
    
    // Sort cards according to the languagesToShow list order
    visibleCards.sort((a, b) {
      final indexA = widget.languagesToShow.indexOf(a.languageCode);
      final indexB = widget.languagesToShow.indexOf(b.languageCode);
      
      // If both are in the list, sort by their position
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      // If only one is in the list, prioritize it (shouldn't happen if visibility is synced)
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      // If neither is in the list, maintain original order (fallback)
      return 0;
    });
    
    final widgets = <Widget>[];
    for (int i = 0; i < visibleCards.length; i++) {
      final card = visibleCards[i];
      
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
      
      widgets.add(
        _buildLanguageSection(
          context,
          card: card,
          languageCode: card.languageCode,
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildLanguageSection(
    BuildContext context, {
    required VocabularyCard card,
    required String languageCode,
  }) {
    // Check if this card is the source or target card (only these can be edited)
    final isSourceCard = widget.item.sourceCard?.id == card.id;
    final isTargetCard = widget.item.targetCard?.id == card.id;
    final isEditableCard = isSourceCard || isTargetCard;
    
    // Get the appropriate controller for editing
    final controller = isSourceCard ? _sourceTranslationController : 
                      (isTargetCard ? _targetTranslationController : null);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LanguageLemmaWidget(
          card: card,
          languageCode: languageCode,
          showDescription: true,
          translationController: _isEditing && isEditableCard ? controller : null,
          isEditing: _isEditing && isEditableCard,
          partOfSpeech: widget.item.partOfSpeech,
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

}
