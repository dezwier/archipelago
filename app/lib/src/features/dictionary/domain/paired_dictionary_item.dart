import 'dictionary_card.dart';

class PairedDictionaryItem {
  final int conceptId;
  final List<DictionaryCard> cards;
  final DictionaryCard? sourceCard;
  final DictionaryCard? targetCard;
  final String? imagePath1;
  final String? imageUrl; // Direct image URL from API
  final String? partOfSpeech;
  final String? conceptTerm;
  final String? conceptDescription;
  final String? conceptLevel;
  final String? topicName;
  final int? topicId; // Topic ID for image generation (deprecated, use topics)
  final String? topicDescription; // Topic description for image generation
  final String? topicIcon; // Topic icon (emoji, deprecated, use topics)
  final List<Map<String, dynamic>> topics; // List of all topics with id, name, icon

  PairedDictionaryItem({
    required this.conceptId,
    List<DictionaryCard>? cards,
    this.sourceCard,
    this.targetCard,
    this.imagePath1,
    this.imageUrl,
    this.partOfSpeech,
    this.conceptTerm,
    this.conceptDescription,
    this.conceptLevel,
    this.topicName,
    this.topicId,
    this.topicDescription,
    this.topicIcon,
    List<Map<String, dynamic>>? topics,
  }) : cards = cards ?? [],
       topics = topics ?? [];

  /// Get the first available image URL, or null if no images are available
  String? get firstImageUrl {
    return imageUrl ?? imagePath1;
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
      imageUrl: json['image_url'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      conceptTerm: json['concept_term'] as String?,
      conceptDescription: json['concept_description'] as String?,
      conceptLevel: json['concept_level'] as String?,
      topicName: json['topic_name'] as String?,
      topicId: json['topic_id'] as int?,
      topicDescription: json['topic_description'] as String?,
      topicIcon: json['topic_icon'] as String?,
      topics: json['topics'] != null
          ? (json['topics'] as List<dynamic>)
              .map((t) => t as Map<String, dynamic>)
              .toList()
          : [],
    );
  }
}

