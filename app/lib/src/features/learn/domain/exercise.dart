import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Represents a single exercise in the learning system
class Exercise {
  final String id;
  final ExerciseType type;
  final Map<String, dynamic> concept; // Original concept data
  final Map<String, dynamic>? exerciseData; // Type-specific data

  const Exercise({
    required this.id,
    required this.type,
    required this.concept,
    this.exerciseData,
  });

  /// Create a copy with updated fields
  Exercise copyWith({
    String? id,
    ExerciseType? type,
    Map<String, dynamic>? concept,
    Map<String, dynamic>? exerciseData,
  }) {
    return Exercise(
      id: id ?? this.id,
      type: type ?? this.type,
      concept: concept ?? this.concept,
      exerciseData: exerciseData ?? this.exerciseData,
    );
  }
}

