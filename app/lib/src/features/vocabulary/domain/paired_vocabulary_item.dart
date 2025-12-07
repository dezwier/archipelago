import 'vocabulary_card.dart';

class PairedVocabularyItem {
  final int conceptId;
  final VocabularyCard? sourceCard;
  final VocabularyCard? targetCard;

  PairedVocabularyItem({
    required this.conceptId,
    this.sourceCard,
    this.targetCard,
  });

  factory PairedVocabularyItem.fromJson(Map<String, dynamic> json) {
    return PairedVocabularyItem(
      conceptId: json['concept_id'] as int,
      sourceCard: json['source_card'] != null
          ? VocabularyCard.fromJson(json['source_card'] as Map<String, dynamic>)
          : null,
      targetCard: json['target_card'] != null
          ? VocabularyCard.fromJson(json['target_card'] as Map<String, dynamic>)
          : null,
    );
  }
}

