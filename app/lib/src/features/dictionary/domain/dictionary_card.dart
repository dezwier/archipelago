class DictionaryCard {
  final int id;
  final int conceptId;
  final String languageCode;
  final String translation;
  final String? description;
  final String? ipa;
  final String? audioPath;
  final String? gender;
  final String? article;
  final String? pluralForm;
  final String? verbType;
  final String? auxiliaryVerb;
  final String? formalityRegister;
  final String? notes;

  DictionaryCard({
    required this.id,
    required this.conceptId,
    required this.languageCode,
    required this.translation,
    this.description,
    this.ipa,
    this.audioPath,
    this.gender,
    this.article,
    this.pluralForm,
    this.verbType,
    this.auxiliaryVerb,
    this.formalityRegister,
    this.notes,
  });

  factory DictionaryCard.fromJson(Map<String, dynamic> json) {
    return DictionaryCard(
      id: json['id'] as int,
      conceptId: json['concept_id'] as int,
      languageCode: json['language_code'] as String,
      translation: json['translation'] as String,
      description: json['description'] as String?,
      ipa: json['ipa'] as String?,
      audioPath: json['audio_path'] as String?,
      gender: json['gender'] as String?,
      article: json['article'] as String?,
      pluralForm: json['plural_form'] as String?,
      verbType: json['verb_type'] as String?,
      auxiliaryVerb: json['auxiliary_verb'] as String?,
      formalityRegister: json['formality_register'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

