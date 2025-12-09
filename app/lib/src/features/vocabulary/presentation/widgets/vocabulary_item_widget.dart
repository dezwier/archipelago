import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../domain/paired_vocabulary_item.dart';
import '../../domain/vocabulary_card.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../../../utils/language_emoji.dart';
import 'language_lemma_widget.dart';

class VocabularyItemWidget extends StatelessWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final Map<String, bool> languageVisibility;
  final List<String> languagesToShow;
  final bool showDescription;
  final bool showExtraInfo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<PairedVocabularyItem> allItems;
  final VoidCallback onRandomCard;
  final VoidCallback onTap;

  const VocabularyItemWidget({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    required this.languageVisibility,
    required this.languagesToShow,
    this.showDescription = true,
    this.showExtraInfo = true,
    required this.onEdit,
    required this.onDelete,
    required this.allItems,
    required this.onRandomCard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: const Color(0xFFFFD4A3), // Pastel orange
              foregroundColor: const Color(0xFF8B4513), // Dark brown for contrast
              icon: Icons.edit,
              label: 'Edit',
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFFFFB3B3), // Pastel red
              foregroundColor: const Color(0xFF8B0000), // Dark red for contrast
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
              child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildLanguageSections(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLanguageSections(BuildContext context) {
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
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        );
      }
      
      // Check if card exists for this language
      final card = item.getCardByLanguage(languageCode);
      
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LanguageLemmaWidget(
          card: card,
          languageCode: languageCode,
          showDescription: showDescription,
          showExtraInfo: showExtraInfo,
          partOfSpeech: item.partOfSpeech,
        ),
        // Notes
        if (card.notes != null && card.notes!.isNotEmpty) ...[
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5.0),
                child: Text(
                  'Lemma to be retrieved',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

