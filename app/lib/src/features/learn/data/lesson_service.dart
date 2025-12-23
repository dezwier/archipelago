import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/learn/domain/exercise_performance.dart';
import 'package:archipelago/src/features/learn/domain/exercise_type.dart';

/// Service for lesson completion - syncing exercises and user lemma progress to backend
class LessonService {
  /// Complete a lesson by syncing exercises and user lemma updates to the backend.
  /// 
  /// Args:
  ///   userId: User ID
  ///   kind: Lesson kind ('new', 'learned', or 'all')
  ///   performances: List of ExercisePerformance objects from the lesson
  /// 
  /// Returns a map with:
  ///   - 'success': bool
  ///   - 'message': String (if error)
  ///   - 'created_exercises_count': int (if successful)
  ///   - 'updated_user_lemmas_count': int (if successful)
  static Future<Map<String, dynamic>> completeLesson({
    required int userId,
    required String kind,
    required List<ExercisePerformance> performances,
  }) async {
    // Filter out discovery and summary exercises
    final validPerformances = performances.where((p) => 
      p.exerciseType != ExerciseType.discovery && 
      p.exerciseType != ExerciseType.summary
    ).toList();

    if (validPerformances.isEmpty) {
      return {
        'success': true,
        'message': 'No exercises to sync (only discovery/summary exercises)',
        'created_exercises_count': 0,
        'updated_user_lemmas_count': 0,
      };
    }

    // Build exercises list
    final exercises = validPerformances.map((p) {
      // Convert ExerciseOutcome to result string
      String result;
      switch (p.outcome) {
        case ExerciseOutcome.succeeded:
          result = 'success';
          break;
        case ExerciseOutcome.neededHints:
          result = 'hint';
          break;
        case ExerciseOutcome.failed:
          result = 'fail';
          break;
      }

      return {
        'lemma_id': p.learningLemmaId,
        'exercise_type': p.exerciseType.apiValue,
        'result': result,
        'start_time': p.startTime.toUtc().toIso8601String(),
        'end_time': p.endTime.toUtc().toIso8601String(),
      };
    }).toList();

    // Group exercises by lemma_id to calculate user_lemma updates
    final Map<int, List<Map<String, dynamic>>> exercisesByLemma = {};
    final Map<int, DateTime?> lastSuccessTimes = {};

    for (final exercise in exercises) {
      final lemmaId = exercise['lemma_id'] as int;
      
      if (!exercisesByLemma.containsKey(lemmaId)) {
        exercisesByLemma[lemmaId] = [];
        lastSuccessTimes[lemmaId] = null;
      }
      
      exercisesByLemma[lemmaId]!.add(exercise);
      
      // Track last success time
      if (exercise['result'] == 'success') {
        final endTime = DateTime.parse(exercise['end_time'] as String);
        final currentLastSuccess = lastSuccessTimes[lemmaId];
        if (currentLastSuccess == null || endTime.isAfter(currentLastSuccess)) {
          lastSuccessTimes[lemmaId] = endTime;
        }
      }
    }

    // Calculate SRS updates for each lemma
    // Simple Leitner system: count successes vs failures
    final userLemmas = exercisesByLemma.entries.map((entry) {
      final lemmaId = entry.key;
      final lemmaExercises = entry.value;
      
      // Count results
      int successCount = 0;
      for (final ex in lemmaExercises) {
        if (ex['result'] == 'success') {
          successCount++;
        }
      }
      
      // Determine overall result for bin update
      // If any success, treat as success; otherwise use last result
      String overallResult;
      if (successCount > 0) {
        overallResult = 'success';
      } else {
        overallResult = lemmaExercises.last['result'] as String;
      }
      
      // Calculate bin (simplified - actual calculation done on backend)
      // We'll send a placeholder, backend will recalculate
      int leitnerBin = 0; // Placeholder, backend will calculate
      
      // Calculate next review (simplified - actual calculation done on backend)
      DateTime nextReviewAt;
      if (overallResult == 'success') {
        // Success: move up bin, review in 2 days (bin 1)
        nextReviewAt = DateTime.now().add(const Duration(days: 2));
      } else if (overallResult == 'fail') {
        // Fail: move down bin, review in 1 day (bin 0)
        nextReviewAt = DateTime.now().add(const Duration(days: 1));
      } else {
        // Hint: stay same, review in 1 day (bin 0)
        nextReviewAt = DateTime.now().add(const Duration(days: 1));
      }
      
      return {
        'lemma_id': lemmaId,
        'last_success_time': lastSuccessTimes[lemmaId]?.toUtc().toIso8601String(),
        'leitner_bin': leitnerBin,
        'next_review_at': nextReviewAt.toUtc().toIso8601String(),
      };
    }).toList();

    // Build request payload
    final requestBody = {
      'user_id': userId,
      'kind': kind,
      'exercises': exercises,
      'user_lemmas': userLemmas,
    };

    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lessons/complete');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': (responseData['message'] as String?) ?? 'Lesson completed successfully',
          'created_exercises_count': responseData['created_exercises_count'] as int? ?? 0,
          'updated_user_lemmas_count': responseData['updated_user_lemmas_count'] as int? ?? 0,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to complete lesson',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error completing lesson: ${e.toString()}',
      };
    }
  }
}

