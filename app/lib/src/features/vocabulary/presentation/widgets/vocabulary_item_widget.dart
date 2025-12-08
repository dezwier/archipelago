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
  final bool showSource;
  final bool showTarget;
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
    this.showSource = true,
    this.showTarget = true,
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
                      children: [
                        // Source language section
                        if (item.sourceCard != null && sourceLanguageCode != null && showSource)
                          _buildLanguageSection(
                            context,
                            card: item.sourceCard!,
                            languageCode: sourceLanguageCode!,
                            isSource: true,
                          ),
                        // Divider between languages
                        if (item.sourceCard != null && 
                            sourceLanguageCode != null && 
                            showSource &&
                            item.targetCard != null && 
                            targetLanguageCode != null && 
                            showTarget)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                        // Target language section
                        if (item.targetCard != null && targetLanguageCode != null && showTarget)
                          _buildLanguageSection(
                            context,
                            card: item.targetCard!,
                            languageCode: targetLanguageCode!,
                            isSource: false,
                          ),
                      ],
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

  Widget _buildLanguageSection(
    BuildContext context, {
    required VocabularyCard card,
    required String languageCode,
    required bool isSource,
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
                            fontWeight: isSource ? FontWeight.w500 : FontWeight.w700,
                            color: isSource 
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (card.gender != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSource
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            card.gender!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSource
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSecondaryContainer,
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(
                          alpha: isSource ? 0.5 : 0.7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        // Description
        if (card.description.isNotEmpty && showDescription) ...[
          const SizedBox(height: 8),
          Text(
            HtmlEntityDecoder.decode(card.description),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: isSource ? 0.6 : 0.8,
              ),
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
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: isSource ? 0.5 : 0.7,
                      ),
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

