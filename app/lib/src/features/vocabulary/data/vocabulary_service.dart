import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';

class VocabularyService {
  /// Get vocabulary cards for a user's source and target languages, paired by concept_id.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'items': List<Map<String, dynamic>> (if successful) - paired vocabulary items
  /// - 'total': int (if successful) - total number of items
  /// - 'page': int (if successful) - current page number
  /// - 'page_size': int (if successful) - items per page
  /// - 'has_next': bool (if successful) - whether there are more pages
  /// - 'has_previous': bool (if successful) - whether there are previous pages
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getVocabulary({
    required int userId,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'alphabetical', // Options: 'alphabetical', 'recent'
    String? search,
    List<String> searchLanguageCodes = const [],
  }) async {
    final queryParams = <String, String>{
      'user_id': userId.toString(),
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort_by': sortBy,
    };
    
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
      if (searchLanguageCodes.isNotEmpty) {
        queryParams['search_languages'] = searchLanguageCodes.join(',');
      }
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/vocabulary').replace(
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
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to fetch vocabulary',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to fetch vocabulary: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching vocabulary: ${e.toString()}',
      };
    }
  }

  /// Update a card's translation and/or description.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'card': Map<String, dynamic> (if successful) - updated card data
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> updateCard({
    required int cardId,
    String? translation,
    String? description,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/cards/$cardId');
    
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
            'message': error['detail'] as String? ?? 'Failed to update card',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to update card: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating card: ${e.toString()}',
      };
    }
  }

  /// Delete a concept and all its associated cards.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> deleteConcept({
    required int conceptId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/concepts/$conceptId');
    
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

  /// Cancel a running description generation task.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'task_id': String (if successful)
  /// - 'status': String (if successful) - updated status
  /// - 'progress': Map<String, dynamic> (if successful) - progress information
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> cancelDescriptionGeneration({
    required String taskId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/generate-descriptions/$taskId/cancel');
    
    try {
      final response = await http.post(
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
            'message': error['detail'] as String? ?? 'Failed to cancel task',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to cancel task: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error canceling task: ${e.toString()}',
      };
    }
  }

  /// Start generating images for concepts that don't have images.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'task_id': String (if successful) - task ID for tracking progress
  /// - 'total_concepts': int (if successful) - total concepts that need images
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> startGenerateImages({
    int? userId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/generate-images${userId != null ? '?user_id=$userId' : ''}');
    
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
            'message': error['detail'] as String? ?? 'Failed to start image generation',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to start image generation: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error starting image generation: ${e.toString()}',
      };
    }
  }

  /// Get the status of an image generation task.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'task_id': String (if successful)
  /// - 'status': String (if successful) - 'running', 'completed', 'cancelled', 'failed', 'cancelling'
  /// - 'progress': Map<String, dynamic> (if successful) - progress information
  /// - 'message': String (if error or status message)
  static Future<Map<String, dynamic>> getImageGenerationStatus({
    required String taskId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/generate-images/$taskId/status');
    
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

  /// Cancel a running image generation task.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'task_id': String (if successful)
  /// - 'status': String (if successful) - updated status
  /// - 'progress': Map<String, dynamic> (if successful) - progress information
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> cancelImageGeneration({
    required String taskId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/generate-images/$taskId/cancel');
    
    try {
      final response = await http.post(
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
            'message': error['detail'] as String? ?? 'Failed to cancel task',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to cancel task: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error canceling task: ${e.toString()}',
      };
    }
  }

  /// Refresh/regenerate images for a specific concept.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'images_retrieved': int (if successful) - number of images retrieved
  /// - 'message': String (if successful or error)
  static Future<Map<String, dynamic>> refreshImagesForConcept({
    required int conceptId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/concepts/$conceptId/refresh-images');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'images_retrieved': data['images_retrieved'] as int,
          'message': data['message'] as String?,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to refresh images',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to refresh images: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error refreshing images: ${e.toString()}',
      };
    }
  }

  /// Update the first image (image_path_1) for a concept.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'image_path_1': String? (if successful) - updated image URL
  /// - 'message': String (if successful or error)
  static Future<Map<String, dynamic>> updateConceptImage1({
    required int conceptId,
    required String imageUrl, // Can be empty string to clear
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/concepts/$conceptId/images/1');
    
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'image_path_1': data['image_path_1'] as String?,
          'message': data['message'] as String?,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to update image',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to update image: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating image: ${e.toString()}',
      };
    }
  }

  /// Update a specific image for a concept by index.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'image_path': String? (if successful) - updated image URL
  /// - 'message': String (if successful or error)
  static Future<Map<String, dynamic>> updateConceptImage({
    required int conceptId,
    required int imageIndex, // 1-4
    required String imageUrl, // Can be empty string to clear
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/concepts/$conceptId/images/$imageIndex');
    
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_url': imageUrl}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'image_path': data['image_path_$imageIndex'] as String?,
          'message': data['message'] as String?,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to update image',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to update image: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating image: ${e.toString()}',
      };
    }
  }

  /// Delete a specific image from a concept.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String (if successful or error)
  static Future<Map<String, dynamic>> deleteConceptImage({
    required int conceptId,
    required int imageIndex, // 1-4
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/concepts/$conceptId/images/$imageIndex');
    
    try {
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': data['message'] as String?,
        };
      } else {
        // Try to parse error response as JSON, but handle non-JSON responses
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to delete image',
          };
        } catch (_) {
          // Response is not JSON (might be HTML error page)
          return {
            'success': false,
            'message': 'Failed to delete image: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting image: ${e.toString()}',
      };
    }
  }
}

