import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';

/// Service for updating and deleting dictionary data.
class DictionaryMutationService {
  /// Update a lemma's translation and/or description.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'card': Map<String, dynamic> (if successful) - updated lemma data
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> updateCard({
    required int cardId,
    String? translation,
    String? description,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lemmas/$cardId');
    
    try {
      final body = <String, dynamic>{};
      if (translation != null) {
        body['translation'] = translation;
      }
      if (description != null) {
        body['description'] = description;
      }

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> card = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'card': card,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to update lemma',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to update lemma: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating lemma: ${e.toString()}',
      };
    }
  }

  /// Delete a concept and all its associated lemmas.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> deleteConcept({
    required int conceptId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/$conceptId');
    
    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 204) {
        return {
          'success': true,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to delete concept',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to delete concept: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting concept: ${e.toString()}',
      };
    }
  }

  /// Update a concept's term, description, and/or topic.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'concept': Map<String, dynamic> (if successful) - updated concept data
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> updateConcept({
    required int conceptId,
    String? term,
    String? description,
    int? topicId, // Deprecated, use topicIds instead
    List<int>? topicIds,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/$conceptId');
    
    try {
      final body = <String, dynamic>{};
      // Always send term if provided (it's required for the update)
      // The term should already be trimmed by the caller, but we trim again for safety
      if (term != null) {
        body['term'] = term.trim();
      }
      if (description != null) {
        body['description'] = description;
      }
      // Send topic_ids if provided (preferred over topicId)
      if (topicIds != null) {
        body['topic_ids'] = topicIds;
      } else if (topicId != null) {
        // Backward compatibility: if topicId is provided, use it as a single-item list
        body['topic_ids'] = [topicId];
      }

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> concept = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'concept': concept,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to update concept',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to update concept: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating concept: ${e.toString()}',
      };
    }
  }
}

