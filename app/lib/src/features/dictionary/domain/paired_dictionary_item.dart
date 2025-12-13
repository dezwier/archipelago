import 'dictionary_card.dart';

class PairedDictionaryItem {
  final int conceptId;
  final List<DictionaryCard> cards;
  final DictionaryCard? sourceCard;
  final DictionaryCard? targetCard;
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

  PairedDictionaryItem({
    required this.conceptId,
    List<DictionaryCard>? cards,
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

  /// Get a lemma by language code
  DictionaryCard? getCardByLanguage(String languageCode) {
    try {
      return cards.firstWhere(
        (card) => card.languageCode == languageCode,
      );
    } catch (e) {
      return null;
    }
  }

  factory PairedDictionaryItem.fromJson(Map<String, dynamic> json) {
    // Parse lemmas list if available
    List<DictionaryCard> cardsList = [];
    if (json['lemmas'] != null) {
      final lemmasData = json['lemmas'] as List<dynamic>;
      cardsList = lemmasData
          .map((lemmaJson) => DictionaryCard.fromJson(lemmaJson as Map<String, dynamic>))
          .toList();
    }
    // Fallback to 'cards' for backward compatibility
    else if (json['cards'] != null) {
      final cardsData = json['cards'] as List<dynamic>;
      cardsList = cardsData
          .map((cardJson) => DictionaryCard.fromJson(cardJson as Map<String, dynamic>))
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
    
    return PairedDictionaryItem(
      conceptId: json['concept_id'] as int,
      cards: cardsList,
      sourceCard: json['source_lemma'] != null
          ? DictionaryCard.fromJson(json['source_lemma'] as Map<String, dynamic>)
          : json['source_card'] != null
              ? DictionaryCard.fromJson(json['source_card'] as Map<String, dynamic>)
              : null,
      targetCard: json['target_lemma'] != null
          ? DictionaryCard.fromJson(json['target_lemma'] as Map<String, dynamic>)
          : json['target_card'] != null
              ? DictionaryCard.fromJson(json['target_card'] as Map<String, dynamic>)
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

