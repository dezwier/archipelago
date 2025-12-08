class VocabularyCard {
  final int id;
  final int conceptId;
  final String languageCode;
  final String translation;
  final String? description;
  final String? ipa;
  final String? audioPath;
  final String? gender;
  final String? notes;

  VocabularyCard({
    required this.id,
    required this.conceptId,
    required this.languageCode,
    required this.translation,
    this.description,
    this.ipa,
    this.audioPath,
    this.gender,
    this.notes,
  });

  factory VocabularyCard.fromJson(Map<String, dynamic> json) {
    return VocabularyCard(
      id: json['id'] as int,
      conceptId: json['concept_id'] as int,
      languageCode: json['language_code'] as String,
      translation: json['translation'] as String,
      description: json['description'] as String?,
      ipa: json['ipa'] as String?,
      audioPath: json['audio_path'] as String?,
      gender: json['gender'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

