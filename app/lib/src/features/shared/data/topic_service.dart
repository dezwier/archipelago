import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';

class TopicService {
  /// Get topics for a user, sorted by created_at descending (most recent first).
  static Future<List<Topic>> getTopics({int? userId}) async {
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/topics');
    final url = userId != null 
        ? uri.replace(queryParameters: {'user_id': userId.toString()})
        : uri;
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final topicsList = data['topics'] as List<dynamic>;
        return topicsList
            .map((topic) => Topic.fromJson(topic as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Create a topic or get existing one if it already exists.
  /// Returns a map with 'success' boolean and either 'topic' or 'error' message.
  static Future<Map<String, dynamic>> createTopic(String name, {required int userId, String? description, String? icon}) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/topics');
    
    try {
      final body = {
        'name': name.trim(),
        'user_id': userId,
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        if (icon != null && icon.trim().isNotEmpty) 'icon': icon.trim(),
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'topic': Topic.fromJson(data),
        };
      } else {
        // Try to parse error message
        String errorMessage = 'Failed to create topic';
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = errorData['detail'] as String? ?? errorMessage;
        } catch (_) {
          errorMessage = 'Server returned status ${response.statusCode}';
        }
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Update a topic.
  /// Returns a map with 'success' boolean and either 'topic' or 'error' message.
  static Future<Map<String, dynamic>> updateTopic(
    int topicId, {
    String? name,
    String? description,
    String? icon,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/topics/$topicId');
    
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name.trim();
      if (description != null) body['description'] = description.trim().isNotEmpty ? description.trim() : null;
      if (icon != null) body['icon'] = icon.trim().isNotEmpty ? icon.trim() : null;
      
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'topic': Topic.fromJson(data),
        };
      } else {
        // Try to parse error message
        String errorMessage = 'Failed to update topic';
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = errorData['detail'] as String? ?? errorMessage;
        } catch (_) {
          errorMessage = 'Server returned status ${response.statusCode}';
        }
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }
}

