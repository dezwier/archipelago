import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/dictionary/domain/dictionary_card.dart';
import 'package:archipelago/src/utils/html_entity_decoder.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/language_lemma_widget.dart';

class DictionaryItemWidget extends StatelessWidget {
  final PairedDictionaryItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final Map<String, bool> languageVisibility;
  final List<String> languagesToShow;
  final bool showDescription;
  final bool showExtraInfo;
  final List<PairedDictionaryItem> allItems;
  final VoidCallback onTap;

  const DictionaryItemWidget({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    required this.languageVisibility,
    required this.languagesToShow,
    this.showDescription = true,
    this.showExtraInfo = true,
    required this.allItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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
    );
  }

  List<Widget> _buildLanguageSections(BuildContext context) {
    // Build sections for all visible languages in order
    // Show placeholders for missing cards
    final widgets = <Widget>[];
    
    // If languagesToShow is empty, fall back to showing all languages from the item's cards
    final languagesToDisplay = languagesToShow.isNotEmpty 
        ? languagesToShow 
        : item.cards.map((c) => c.languageCode).toList();
    
    for (int i = 0; i < languagesToDisplay.length; i++) {
      final languageCode = languagesToDisplay[i];
      
      // Skip if language is not visible (only check if languageVisibility is not empty)
      if (languageVisibility.isNotEmpty && languageVisibility[languageCode] != true) {
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
      
      // Check if lemma exists for this language
      final card = item.getCardByLanguage(languageCode);
      
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

