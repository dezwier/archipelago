import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/shared/domain/filter_config.dart';

/// Service for querying and fetching dictionary data.
class DictionaryQueryService {
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
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getDictionary({
    int? userId,
    int page = 1,
    int pageSize = 20,
    String sortBy = 'alphabetical', // Options: 'alphabetical', 'recent'
    String? search,
    List<String> visibleLanguageCodes = const [],
    bool includeLemmas = true, // Include lemmas (is_phrase is false)
    bool includePhrases = true, // Include phrases (is_phrase is true)
    List<int>? topicIds, // Filter by topic IDs
    bool includeWithoutTopic = false, // Include concepts without a topic (topic_id is null)
    List<String>? levels, // Filter by CEFR levels (A1, A2, B1, B2, C1, C2)
    List<String>? partOfSpeech, // Filter by part of speech values
    int? hasImages, // 1 = include only concepts with images, 0 = include only concepts without images, null = include all
    int? hasAudio, // 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
    int? isComplete, // 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
  }) async {
    // Create FilterConfig from parameters
    final filterConfig = FilterConfig(
      userId: userId,
      visibleLanguages: visibleLanguageCodes.isNotEmpty ? visibleLanguageCodes.join(',') : null,
      includeLemmas: includeLemmas,
      includePhrases: includePhrases,
      topicIds: topicIds != null && topicIds.isNotEmpty ? topicIds.join(',') : null,
      includeWithoutTopic: includeWithoutTopic,
      levels: levels != null && levels.isNotEmpty ? levels.join(',') : null,
      partOfSpeech: partOfSpeech != null && partOfSpeech.isNotEmpty ? partOfSpeech.join(',') : null,
      hasImages: hasImages,
      hasAudio: hasAudio,
      isComplete: isComplete,
      search: search,
    );
    
    // Create request body
    final requestBody = {
      'filter_config': filterConfig.toJson(),
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
    };
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/dictionary');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
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

  /// Get the total count of concepts visible to the user.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'count': int (if successful) - total count of concepts visible to the user
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getConceptCountTotal({int? userId}) async {
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/count/total');
    final url = userId != null 
        ? uri.replace(queryParameters: {'user_id': userId.toString()})
        : uri;
    
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

  /// Get a single concept by ID with all its lemmas.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'item': Map<String, dynamic> (if successful) - paired dictionary item
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getConceptById({
    required int conceptId,
    List<String> visibleLanguageCodes = const [],
  }) async {
    // Fetch concept and lemmas separately and construct the PairedDictionaryItem
    return await _getConceptByIdFallback(conceptId, visibleLanguageCodes);
  }

  /// Get concept data only (for progressive loading)
  /// Returns: {'success': bool, 'data': Map<String, dynamic>?, 'message': String?}
  static Future<Map<String, dynamic>> getConceptDataOnly(int conceptId) async {
    try {
      final conceptData = await _fetchConceptData(conceptId);
      return {
        'success': true,
        'data': conceptData,
      };
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'message': e.toString(),
      };
    }
  }

  /// Get lemmas for a concept (for progressive loading)
  /// Returns: {'success': bool, 'data': List<dynamic>?, 'message': String?}
  static Future<Map<String, dynamic>> getLemmasOnly(
    int conceptId,
    List<String> visibleLanguageCodes,
  ) async {
    try {
      final lemmasData = await _fetchLemmas(conceptId, visibleLanguageCodes);
      return {
        'success': true,
        'data': lemmasData,
      };
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'message': e.toString(),
      };
    }
  }

  /// Get topic data (for progressive loading)
  /// Returns: {'success': bool, 'data': Map<String, dynamic>?, 'message': String?}
  static Future<Map<String, dynamic>> getTopicDataOnly(int? topicId) async {
    try {
      final topicData = await _fetchTopicData(topicId);
      return {
        'success': true,
        'data': topicData,
      };
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'message': e.toString(),
      };
    }
  }

  /// Fetch concept data by ID
  static Future<Map<String, dynamic>> _fetchConceptData(int conceptId) async {
    try {
      final conceptUrl = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/$conceptId');
      final conceptResponse = await http.get(
        conceptUrl,
        headers: {'Content-Type': 'application/json'},
      );

      if (conceptResponse.statusCode != 200) {
        try {
          final error = jsonDecode(conceptResponse.body) as Map<String, dynamic>;
          throw Exception(error['detail'] as String? ?? 'Failed to fetch concept');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Failed to fetch concept: ${conceptResponse.statusCode}');
        }
      }

      return jsonDecode(conceptResponse.body) as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch lemmas for a concept
  static Future<List<dynamic>> _fetchLemmas(int conceptId, List<String> visibleLanguageCodes) async {
    try {
      final lemmasUrl = Uri.parse('${ApiConfig.apiBaseUrl}/lemmas/concept/$conceptId');
      final lemmasResponse = await http.get(
        lemmasUrl,
        headers: {'Content-Type': 'application/json'},
      );

      if (lemmasResponse.statusCode != 200) {
        try {
          final error = jsonDecode(lemmasResponse.body) as Map<String, dynamic>;
          throw Exception(error['detail'] as String? ?? 'Failed to fetch lemmas');
        } catch (e) {
          if (e is Exception) rethrow;
          throw Exception('Failed to fetch lemmas: ${lemmasResponse.statusCode}');
        }
      }

      final lemmasData = jsonDecode(lemmasResponse.body) as List<dynamic>;
      
      // Filter lemmas by visible languages if provided
      if (visibleLanguageCodes.isNotEmpty) {
        return lemmasData.where((lemma) {
          final langCode = (lemma as Map<String, dynamic>)['language_code'] as String?;
          return langCode != null && visibleLanguageCodes.contains(langCode.toLowerCase());
        }).toList();
      }
      
      return lemmasData;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch topic data by ID
  static Future<Map<String, dynamic>?> _fetchTopicData(int? topicId) async {
    if (topicId == null) return null;
    
    try {
      final topicUrl = Uri.parse('${ApiConfig.apiBaseUrl}/topics/$topicId');
      final topicResponse = await http.get(
        topicUrl,
        headers: {'Content-Type': 'application/json'},
      );
      
      if (topicResponse.statusCode == 200) {
        return jsonDecode(topicResponse.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      // If topic fetch fails, return null (not critical)
      return null;
    }
  }

  /// Fallback method to get concept by ID by fetching concept and lemmas separately
  /// Now uses parallel API calls for better performance
  static Future<Map<String, dynamic>> _getConceptByIdFallback(
    int conceptId,
    List<String> visibleLanguageCodes,
  ) async {
    try {
      // Start all API calls in parallel
      final conceptFuture = _fetchConceptData(conceptId);
      final lemmasFuture = _fetchLemmas(conceptId, visibleLanguageCodes);
      
      // Wait for concept data first (needed to check for topic_id)
      final conceptData = await conceptFuture;
      final topicId = conceptData['topic_id'] as int?;
      
      // Start topic fetch if needed, otherwise use completed future
      final topicFuture = _fetchTopicData(topicId);
      
      // Wait for lemmas and topic in parallel
      final results = await Future.wait([
        lemmasFuture,
        topicFuture,
      ]);
      
      final lemmasData = results[0] as List<dynamic>;
      final topicData = results[1] as Map<String, dynamic>?;

      // Extract topic information
      String? topicName;
      String? topicDescription;
      String? topicIcon;
      if (topicData != null) {
        topicName = topicData['name'] as String?;
        topicDescription = topicData['description'] as String?;
        topicIcon = topicData['icon'] as String?;
      }

      // Construct PairedDictionaryItem format
      final item = <String, dynamic>{
        'concept_id': conceptId,
        'lemmas': lemmasData,
        'concept_term': conceptData['term'],
        'concept_description': conceptData['description'],
        'part_of_speech': conceptData['part_of_speech'],
        'concept_level': conceptData['level'],
        'image_url': conceptData['image_url'],
        'image_path_1': conceptData['image_path_1'],
        'topic_id': topicId,
        'topic_name': topicName,
        'topic_description': topicDescription,
        'topic_icon': topicIcon,
      };

      return {
        'success': true,
        'item': item,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching concept: ${e.toString()}',
      };
    }
  }
}

