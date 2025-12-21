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
        return '1.1 Discovery';
      case ExerciseType.summary:
        return '1.2 Discovery Summary';
      case ExerciseType.matchInfoImage:
        return '2.1 Match Info to Image';
      case ExerciseType.matchImageInfo:
        return '2.2 Match Image to Info';
      case ExerciseType.matchAudioImage:
        return '2.3 Match Audio to Image';
      case ExerciseType.matchImageAudio:
        return '2.4 Match Image to Audio';
      case ExerciseType.matchDescriptionPhrase:
        return '2.5 Match Description to Phrase';
      case ExerciseType.matchPhraseDescription:
        return '2.6 Match Phrase to Description';
      case ExerciseType.scaffoldFromImage:
        return '3.1 Scaffold From Image';
      case ExerciseType.closeExercise:
        return '4.1 Close Exercise';
    }
  }
}

