import 'vocabulary_card.dart';

class PairedVocabularyItem {
  final int conceptId;
  final VocabularyCard? sourceCard;
  final VocabularyCard? targetCard;
  final String? imagePath1;
  final String? imagePath2;
  final String? imagePath3;
  final String? imagePath4;

  PairedVocabularyItem({
    required this.conceptId,
    this.sourceCard,
    this.targetCard,
    this.imagePath1,
    this.imagePath2,
    this.imagePath3,
    this.imagePath4,
  });

  /// Get the first available image URL, or null if no images are available
  String? get firstImageUrl {
    return imagePath1 ?? imagePath2 ?? imagePath3 ?? imagePath4;
  }

  factory PairedVocabularyItem.fromJson(Map<String, dynamic> json) {
    return PairedVocabularyItem(
      conceptId: json['concept_id'] as int,
      sourceCard: json['source_card'] != null
          ? VocabularyCard.fromJson(json['source_card'] as Map<String, dynamic>)
          : null,
      targetCard: json['target_card'] != null
          ? VocabularyCard.fromJson(json['target_card'] as Map<String, dynamic>)
          : null,
      imagePath1: json['image_path_1'] as String?,
      imagePath2: json['image_path_2'] as String?,
      imagePath3: json['image_path_3'] as String?,
      imagePath4: json['image_path_4'] as String?,
    );
  }
}

