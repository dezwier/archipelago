import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';

class DictionaryService {
  /// Get dictionary cards for a user's source and target languages, paired by concept_id.
  /// If userId is null, returns English-only dictionary for logged-out users.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'items': List<Map<String, dynamic>> (if successful) - paired dictionary items
  /// - 'total': int (if successful) - total number of items
  /// - 'page': int (if successful) - current page number
  /// - 'page_size': int (if successful) - items per page
  /// - 'has_next': bool (if successful) - whether there are more pages
  /// - 'has_previous': bool (if successful) - whether there are previous pages
  /// - 'concepts_with_all_visible_languages': int? (if successful) - count of concepts with cards for all visible languages
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getDictionary({
    int? userId,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'alphabetical', // Options: 'alphabetical', 'recent'
    String? search,
    List<String> visibleLanguageCodes = const [],
    int? ownUserId, // Filter for own user id cards (deprecated, use includePublic/includePrivate)
    bool includePublic = true, // Include public concepts (user_id is null)
    bool includePrivate = true, // Include private concepts (user_id == logged in user)
    List<int>? topicIds, // Filter by topic IDs
    bool includeWithoutTopic = false, // Include concepts without a topic (topic_id is null)
    List<String>? levels, // Filter by CEFR levels (A1, A2, B1, B2, C1, C2)
    List<String>? partOfSpeech, // Filter by part of speech values
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort_by': sortBy,
    };
    
    // Only include user_id if provided
    if (userId != null) {
      queryParams['user_id'] = userId.toString();
    }
    
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    
    // Add visible_languages parameter - filters cards to these languages only
    // If empty, don't pass it (API will return cards for all languages)
    if (visibleLanguageCodes.isNotEmpty) {
      queryParams['visible_languages'] = visibleLanguageCodes.join(',');
    }
    
    // Add own_user_id parameter - filters to concepts created by this user (legacy support)
    if (ownUserId != null) {
      queryParams['own_user_id'] = ownUserId.toString();
    }
    
    // Add include_public parameter - include public concepts (user_id is null)
    if (!includePublic) {
      queryParams['include_public'] = 'false';
    }
    
    // Add include_private parameter - include private concepts (user_id == logged in user)
    if (!includePrivate) {
      queryParams['include_private'] = 'false';
    }
    
    // Add topic_ids parameter - filters to concepts with these topic IDs
    if (topicIds != null && topicIds.isNotEmpty) {
      queryParams['topic_ids'] = topicIds.join(',');
    }
    
    // Add include_without_topic parameter - include concepts without a topic
    if (includeWithoutTopic) {
      queryParams['include_without_topic'] = 'true';
    }
    
    // Add levels parameter - filters to concepts with these CEFR levels
    if (levels != null && levels.isNotEmpty) {
      queryParams['levels'] = levels.join(',');
    }
    
    // Add part_of_speech parameter - filters to concepts with these part of speech values
    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      queryParams['part_of_speech'] = partOfSpeech.join(',');
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/dictionary').replace(
      queryParameters: queryParams,
    );
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> items = data['items'] as List<dynamic>;
        return {
          'success': true,
          'items': items,
          'total': data['total'] as int,
          'page': data['page'] as int,
          'page_size': data['page_size'] as int,
          'has_next': data['has_next'] as bool,
          'has_previous': data['has_previous'] as bool,
          'concepts_with_all_visible_languages': data['concepts_with_all_visible_languages'] as int?,
          'total_concepts_with_term': data['total_concepts_with_term'] as int?,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to fetch dictionary',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to fetch dictionary: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching dictionary: ${e.toString()}',
      };
    }
  }

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


  /// Get the total count of all concepts.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'count': int (if successful) - total count of concepts
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getConceptCountTotal() async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/count/total');
    
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'count': data['count'] as int,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to get concept count',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to get concept count: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting concept count: ${e.toString()}',
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
    int? topicId,
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
      // Send topic_id if provided (null means don't change, explicit null would clear it)
      if (topicId != null) {
        body['topic_id'] = topicId;
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

