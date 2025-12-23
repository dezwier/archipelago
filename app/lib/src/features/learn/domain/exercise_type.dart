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

  /// Get API value (snake_case) for the exercise type
  String get apiValue {
    switch (this) {
      case ExerciseType.discovery:
        return 'discovery';
      case ExerciseType.summary:
        return 'summary';
      case ExerciseType.matchInfoImage:
        return 'match_info_image';
      case ExerciseType.matchAudioImage:
        return 'match_audio_image';
      case ExerciseType.matchImageInfo:
        return 'match_image_info';
      case ExerciseType.matchImageAudio:
        return 'match_image_audio';
      case ExerciseType.matchDescriptionPhrase:
        return 'match_description_phrase';
      case ExerciseType.matchPhraseDescription:
        return 'match_phrase_description';
      case ExerciseType.scaffoldFromImage:
        return 'scaffold_from_image';
      case ExerciseType.closeExercise:
        return 'close_exercise';
    }
  }
}
