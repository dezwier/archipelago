/// Enum representing different types of exercises
enum ExerciseType {
  discovery,
  summary,
  match,
  matchReverse,
  scaffold,
  produce;

  /// Get display name for the exercise type
  String get displayName {
    switch (this) {
      case ExerciseType.discovery:
        return 'Discovery';
      case ExerciseType.summary:
        return 'Summary';
      case ExerciseType.match:
        return 'Match';
      case ExerciseType.matchReverse:
        return 'Match Reverse';
      case ExerciseType.scaffold:
        return 'Scaffold';
      case ExerciseType.produce:
        return 'Produce';
    }
  }
}

