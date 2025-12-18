import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';

/// Service for generating descriptions for dictionary concepts.
class DictionaryGenerationService {
  /// Start generating descriptions for cards that don't have descriptions.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'task_id': String (if successful) - task ID for tracking progress
  /// - 'total_concepts': int (if successful) - total concepts that need descriptions
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> startGenerateDescriptions({
    int? userId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/generate-descriptions${userId != null ? '?user_id=$userId' : ''}');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 202) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'task_id': data['task_id'] as String,
          'total_concepts': data['total_concepts'] as int,
          'message': data['message'] as String?,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to start description generation',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to start description generation: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error starting description generation: ${e.toString()}',
      };
    }
  }

  /// Get the status of a description generation task.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'task_id': String (if successful)
  /// - 'status': String (if successful) - 'running', 'completed', 'cancelled', 'failed', 'cancelling'
  /// - 'progress': Map<String, dynamic> (if successful) - progress information
  /// - 'message': String (if error or status message)
  static Future<Map<String, dynamic>> getDescriptionGenerationStatus({
    required String taskId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/generate-descriptions/$taskId/status');
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'task_id': data['task_id'] as String,
          'status': data['status'] as String,
          'progress': data['progress'] as Map<String, dynamic>,
          'message': data['message'] as String?,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to get task status',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to get task status: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting task status: ${e.toString()}',
      };
    }
  }
}

