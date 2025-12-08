import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../domain/paired_vocabulary_item.dart';
import '../../domain/vocabulary_card.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../../../utils/language_emoji.dart';

class VocabularyItemWidget extends StatelessWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final Map<String, bool> languageVisibility;
  final List<String> languagesToShow;
  final bool showDescription;
  final bool showImages;
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
    this.showImages = true,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dictionary content column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildLanguageSections(context),
                    ),
                  ),
                  // Image on the right side
                  if (showImages && item.firstImageUrl != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        item.firstImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              size: 32,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLanguageSections(BuildContext context) {
    // Filter visible cards and sort by the languagesToShow order
    final visibleCards = item.cards
        .where((card) => languageVisibility[card.languageCode] ?? true)
        .toList();
    
    // Sort cards according to the languagesToShow list order
    visibleCards.sort((a, b) {
      final indexA = languagesToShow.indexOf(a.languageCode);
      final indexB = languagesToShow.indexOf(b.languageCode);
      
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language header with term
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language emoji
            Text(
              LanguageEmoji.getEmoji(languageCode),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            // Term and gender
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          HtmlEntityDecoder.decode(card.translation),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (card.gender != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            card.gender!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // IPA pronunciation
                  if (card.ipa != null && card.ipa!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '/${card.ipa}/',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // Description
        if ((card.description?.isNotEmpty ?? false) && showDescription) ...[
          const SizedBox(height: 8),
          Text(
            HtmlEntityDecoder.decode(card.description!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
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
}

