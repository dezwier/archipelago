/// Enum representing different types of exercises
enum ExerciseType {
  discovery,
  match,
  scaffold,
  produce;

  /// Get display name for the exercise type
  String get displayName {
    switch (this) {
      case ExerciseType.discovery:
        return 'Discovery';
      case ExerciseType.match:
        return 'Match';
      case ExerciseType.scaffold:
        return 'Scaffold';
      case ExerciseType.produce:
        return 'Produce';
    }
  }
}

