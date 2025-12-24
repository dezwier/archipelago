/// Filter configuration for concept queries.
/// 
/// This config groups all filter parameters used across dictionary,
/// lesson generation, and statistics endpoints.
class FilterConfig {
  final int? userId;
  final String? visibleLanguages; // Comma-separated list of visible language codes
  final bool includeLemmas; // Include lemmas (concept.is_phrase is False)
  final bool includePhrases; // Include phrases (concept.is_phrase is True)
  final String? topicIds; // Comma-separated list of topic IDs to filter by
  final bool includeWithoutTopic; // Include concepts without a topic (topic_id is null)
  final String? levels; // Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
  final String? partOfSpeech; // Comma-separated list of part of speech values to filter by
  final int? hasImages; // 1 = include only concepts with images, 0 = include only concepts without images, null = include all
  final int? hasAudio; // 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
  final int? isComplete; // 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
  final String? search; // Optional search query for concept.term and lemma.term

  const FilterConfig({
    this.userId,
    this.visibleLanguages,
    this.includeLemmas = true,
    this.includePhrases = true,
    this.topicIds,
    this.includeWithoutTopic = true,
    this.levels,
    this.partOfSpeech,
    this.hasImages,
    this.hasAudio,
    this.isComplete,
    this.search,
  });

  /// Create FilterConfig from JSON
  factory FilterConfig.fromJson(Map<String, dynamic> json) {
    return FilterConfig(
      userId: json['user_id'] as int?,
      visibleLanguages: json['visible_languages'] as String?,
      includeLemmas: json['include_lemmas'] as bool? ?? true,
      includePhrases: json['include_phrases'] as bool? ?? true,
      topicIds: json['topic_ids'] as String?,
      includeWithoutTopic: json['include_without_topic'] as bool? ?? true,
      levels: json['levels'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      hasImages: json['has_images'] as int?,
      hasAudio: json['has_audio'] as int?,
      isComplete: json['is_complete'] as int?,
      search: json['search'] as String?,
    );
  }

  /// Convert FilterConfig to JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (userId != null) json['user_id'] = userId;
    if (visibleLanguages != null) json['visible_languages'] = visibleLanguages;
    json['include_lemmas'] = includeLemmas;
    json['include_phrases'] = includePhrases;
    if (topicIds != null) json['topic_ids'] = topicIds;
    json['include_without_topic'] = includeWithoutTopic;
    if (levels != null) json['levels'] = levels;
    if (partOfSpeech != null) json['part_of_speech'] = partOfSpeech;
    if (hasImages != null) json['has_images'] = hasImages;
    if (hasAudio != null) json['has_audio'] = hasAudio;
    if (isComplete != null) json['is_complete'] = isComplete;
    if (search != null) json['search'] = search;
    return json;
  }

  /// Create a copy of FilterConfig with updated fields
  FilterConfig copyWith({
    int? userId,
    String? visibleLanguages,
    bool? includeLemmas,
    bool? includePhrases,
    String? topicIds,
    bool? includeWithoutTopic,
    String? levels,
    String? partOfSpeech,
    int? hasImages,
    int? hasAudio,
    int? isComplete,
    String? search,
  }) {
    return FilterConfig(
      userId: userId ?? this.userId,
      visibleLanguages: visibleLanguages ?? this.visibleLanguages,
      includeLemmas: includeLemmas ?? this.includeLemmas,
      includePhrases: includePhrases ?? this.includePhrases,
      topicIds: topicIds ?? this.topicIds,
      includeWithoutTopic: includeWithoutTopic ?? this.includeWithoutTopic,
      levels: levels ?? this.levels,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      hasImages: hasImages ?? this.hasImages,
      hasAudio: hasAudio ?? this.hasAudio,
      isComplete: isComplete ?? this.isComplete,
      search: search ?? this.search,
    );
  }
}

