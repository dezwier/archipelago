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
  scaffoldFromImage,
  closeExercise;

  /// Get display name for the exercise type
  String get displayName {
    switch (this) {
      case ExerciseType.discovery:
        return '0.1 Discovery';
      case ExerciseType.summary:
        return '0.2 Discovery Summary';
      case ExerciseType.matchInfoImage:
        return '1.1 Match Info to Image';
      case ExerciseType.matchImageInfo:
        return '1.2 Match Image to Info';
      case ExerciseType.matchAudioImage:
        return '1.3 Match Audio to Image';
      case ExerciseType.matchImageAudio:
        return '1.4 Match Image to Audio';
      case ExerciseType.matchDescriptionPhrase:
        return '1.5 Match Description to Phrase';
      case ExerciseType.matchPhraseDescription:
        return '1.6 Match Phrase to Description';
      case ExerciseType.scaffoldFromImage:
        return '2.1 Scaffold From Image';
      case ExerciseType.closeExercise:
        return '3.1 Close Exercise';
    }
  }
}
