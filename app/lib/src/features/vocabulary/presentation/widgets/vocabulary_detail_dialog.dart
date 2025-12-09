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
      print('=== REGENERATE CARDS REQUEST ===');
      print('Concept ID: ${widget.item.conceptId}');
      print('Selected Languages: $selectedLanguages');
      
      final result = await FlashcardService.generateCardsForConcept(
        conceptId: widget.item.conceptId,
        languages: selectedLanguages,
      );

      print('=== REGENERATE CARDS RESPONSE ===');
      print('Result: $result');
      print('Success: ${result['success']}');
      print('Message: ${result['message']}');

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        // Notify parent to refresh the item
        widget.onItemUpdated?.call(widget.item);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cards regenerated successfully')),
        );
      } else {
        final errorMessage = result['message'] as String? ?? 'Failed to regenerate cards';
        print('Error message: $errorMessage');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5), // Show error longer
          ),
        );
      }
    } catch (e, stackTrace) {
      print('=== REGENERATE CARDS EXCEPTION ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error regenerating cards: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5), // Show error longer
        ),
      );
    }
  }

  @override
  void dispose() {
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
                        // Action buttons stacked vertically on right
                        VocabularyActionButtons(
                          isEditing: _isEditing,
                          onEdit: () {
                            setState(() {
                              _isEditing = true;
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
                      const SizedBox(height: 24),
                    ..._buildLanguageSections(context),
                    if (widget.item.conceptTerm != null || 
                        widget.item.conceptDescription != null) ...[
                      const SizedBox(height: 34),
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
      final result = await FlashcardService.generateCardsForConcept(
        conceptId: widget.item.conceptId,
        languages: [languageCode],
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
