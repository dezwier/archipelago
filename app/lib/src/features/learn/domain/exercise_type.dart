/// Enum representing different types of exercises
enum ExerciseType {
  discovery,
  summary,
  matchInfoImage,
  matchAudioImage,
  matchImageInfo,
  matchImageAudio,
  matchDescriptionPhrase,
  matchPhraseDescription,
  scaffold,
  produce;

  /// Get display name for the exercise type
  String get displayName {
    switch (this) {
      case ExerciseType.discovery:
        return '1. Discovery';
      case ExerciseType.summary:
        return '2. Discovery Summary';
      case ExerciseType.matchInfoImage:
        return '3.1 Match Info to Image';
      case ExerciseType.matchImageInfo:
        return '3.2 Match Image to Info';
      case ExerciseType.matchAudioImage:
        return '3.3 Match Audio to Image';
      case ExerciseType.matchImageAudio:
        return '3.4 Match Image to Audio';
      case ExerciseType.matchDescriptionPhrase:
        return '3.5 Match Description to Phrase';
      case ExerciseType.matchPhraseDescription:
        return '3.6 Match Phrase to Description';
      case ExerciseType.scaffold:
        return 'Scaffold';
      case ExerciseType.produce:
        return 'Produce';
    }
  }
}

