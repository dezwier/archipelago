import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../domain/paired_vocabulary_item.dart';
import 'vocabulary_card_widget.dart';

class VocabularyItemWidget extends StatelessWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final bool showSource;
  final bool showTarget;
  final bool showDescription;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VocabularyItemWidget({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    this.showSource = true,
    this.showTarget = true,
    this.showDescription = true,
    required this.onEdit,
    required this.onDelete,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Source card (if available and enabled)
              if (item.sourceCard != null && sourceLanguageCode != null && showSource)
                VocabularyCardWidget(
                  card: item.sourceCard!,
                  languageCode: sourceLanguageCode!,
                  isSource: true,
                  showDescription: showDescription,
                  isFirst: true,
                  isLast: !(item.targetCard != null && targetLanguageCode != null && showTarget),
                ),
              // Target card (if available and enabled)
              if (item.targetCard != null && targetLanguageCode != null && showTarget)
                VocabularyCardWidget(
                  card: item.targetCard!,
                  languageCode: targetLanguageCode!,
                  isSource: false,
                  showDescription: showDescription,
                  isFirst: !(item.sourceCard != null && sourceLanguageCode != null && showSource),
                  isLast: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

