import 'vocabulary_card.dart';

class PairedVocabularyItem {
  final int conceptId;
  final List<VocabularyCard> cards;
  final VocabularyCard? sourceCard;
  final VocabularyCard? targetCard;
  final String? imagePath1;
  final String? imagePath2;
  final String? imagePath3;
  final String? imagePath4;
  final List<Map<String, dynamic>>? images; // Images array from API
  final String? partOfSpeech;
  final String? conceptTerm;
  final String? conceptDescription;
  final String? conceptLevel;
  final String? topicName;
  final int? topicId; // Topic ID for image generation
  final String? topicDescription; // Topic description for image generation

  PairedVocabularyItem({
    required this.conceptId,
    List<VocabularyCard>? cards,
    this.sourceCard,
    this.targetCard,
    this.imagePath1,
    this.imagePath2,
    this.imagePath3,
    this.imagePath4,
    this.images,
    this.partOfSpeech,
    this.conceptTerm,
    this.conceptDescription,
    this.conceptLevel,
    this.topicName,
    this.topicId,
    this.topicDescription,
  }) : cards = cards ?? [];

  /// Get the first available image URL, or null if no images are available
  String? get firstImageUrl {
    return imagePath1 ?? imagePath2 ?? imagePath3 ?? imagePath4;
  }

  /// Get a card by language code
  VocabularyCard? getCardByLanguage(String languageCode) {
    try {
      return cards.firstWhere(
        (card) => card.languageCode == languageCode,
      );
    } catch (e) {
      return null;
    }
  }

  factory PairedVocabularyItem.fromJson(Map<String, dynamic> json) {
    // Parse cards list if available
    List<VocabularyCard> cardsList = [];
    if (json['cards'] != null) {
      final cardsData = json['cards'] as List<dynamic>;
      cardsList = cardsData
          .map((cardJson) => VocabularyCard.fromJson(cardJson as Map<String, dynamic>))
          .toList();
    }
    
    // Parse images array if available
    List<Map<String, dynamic>>? imagesList;
    if (json['images'] != null) {
      final imagesData = json['images'] as List<dynamic>;
      imagesList = imagesData
          .map((imgJson) => imgJson as Map<String, dynamic>)
          .toList();
    }
    
    return PairedVocabularyItem(
      conceptId: json['concept_id'] as int,
      cards: cardsList,
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
      images: imagesList,
      partOfSpeech: json['part_of_speech'] as String?,
      conceptTerm: json['concept_term'] as String?,
      conceptDescription: json['concept_description'] as String?,
      conceptLevel: json['concept_level'] as String?,
      topicName: json['topic_name'] as String?,
      topicId: json['topic_id'] as int?,
      topicDescription: json['topic_description'] as String?,
    );
  }
}

