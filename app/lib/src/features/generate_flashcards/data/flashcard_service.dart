import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../constants/api_config.dart';
import '../../profile/domain/user.dart';

class FlashcardService {
  /// Preview a concept with cards for multiple languages using LLM generation.
  /// This does NOT save to the database - use confirmConcept to save.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> previewConcept({
    required String term,
    int? topicId,
    String? partOfSpeech,
    String? coreMeaningEn,
    required List<String> languages,
    List<String>? excludedSenses,
  }) async {
    // Validate term is not empty
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return {
        'success': false,
        'message': 'Term cannot be empty',
      };
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/preview');
    
    try {
      final body = {
        'term': trimmedTerm,
        'languages': languages.map((lang) => lang.toLowerCase()).toList(),
      };
      
      // Only include part_of_speech if provided
      if (partOfSpeech != null && partOfSpeech.trim().isNotEmpty) {
        body['part_of_speech'] = partOfSpeech.trim();
      }
      
      // Only include topic_id if provided
      if (topicId != null) {
        body['topic_id'] = topicId;
      }
      
      // Only include core_meaning_en if provided
      if (coreMeaningEn != null && coreMeaningEn.trim().isNotEmpty) {
        body['core_meaning_en'] = coreMeaningEn.trim();
      }
      
      // Only include excluded_senses if provided
      if (excludedSenses != null && excludedSenses.isNotEmpty) {
        body['excluded_senses'] = excludedSenses.map((sense) => sense.trim()).toList();
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': 'Preview generated successfully',
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to generate preview',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Confirm and save a previewed concept to the database.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> confirmConcept({
    required String term,
    int? topicId,
    int? userId,
    String? partOfSpeech,
    required Map<String, dynamic> conceptData,
    required List<Map<String, dynamic>> cardsData,
  }) async {
    // Validate term is not empty
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return {
        'success': false,
        'message': 'Term cannot be empty',
      };
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/confirm');
    
    try {
      // Ensure conceptData only contains valid fields and types
      final cleanConceptData = <String, dynamic>{
        'description': conceptData['description'] is String 
            ? (conceptData['description'] as String).trim() 
            : conceptData['description']?.toString().trim() ?? '',
        'frequency_bucket': conceptData['frequency_bucket'] is String
            ? (conceptData['frequency_bucket'] as String).trim()
            : conceptData['frequency_bucket']?.toString().trim() ?? 'medium',
      };
      
      // Ensure cardsData only contains valid fields and types
      final cleanCardsData = cardsData.map((card) {
        final cleanCard = <String, dynamic>{};
        
        // Required fields
        cleanCard['language_code'] = card['language_code'] is String
            ? (card['language_code'] as String).trim()
            : card['language_code']?.toString().trim() ?? '';
        cleanCard['term'] = card['term'] is String
            ? (card['term'] as String).trim()
            : card['term']?.toString().trim() ?? '';
        
        // Optional fields - only include if they exist and are valid
        if (card.containsKey('ipa') && card['ipa'] != null) {
          cleanCard['ipa'] = card['ipa'] is String
              ? (card['ipa'] as String).trim()
              : card['ipa']?.toString().trim();
          if (cleanCard['ipa'] == '') cleanCard.remove('ipa');
        }
        if (card.containsKey('description') && card['description'] != null) {
          cleanCard['description'] = card['description'] is String
              ? (card['description'] as String).trim()
              : card['description']?.toString().trim();
          if (cleanCard['description'] == '') cleanCard.remove('description');
        }
        if (card.containsKey('gender') && card['gender'] != null) {
          cleanCard['gender'] = card['gender'] is String
              ? (card['gender'] as String).trim()
              : card['gender']?.toString().trim();
          if (cleanCard['gender'] == '') cleanCard.remove('gender');
        }
        if (card.containsKey('article') && card['article'] != null) {
          cleanCard['article'] = card['article'] is String
              ? (card['article'] as String).trim()
              : card['article']?.toString().trim();
          if (cleanCard['article'] == '') cleanCard.remove('article');
        }
        if (card.containsKey('plural_form') && card['plural_form'] != null) {
          cleanCard['plural_form'] = card['plural_form'] is String
              ? (card['plural_form'] as String).trim()
              : card['plural_form']?.toString().trim();
          if (cleanCard['plural_form'] == '') cleanCard.remove('plural_form');
        }
        if (card.containsKey('verb_type') && card['verb_type'] != null) {
          cleanCard['verb_type'] = card['verb_type'] is String
              ? (card['verb_type'] as String).trim()
              : card['verb_type']?.toString().trim();
          if (cleanCard['verb_type'] == '') cleanCard.remove('verb_type');
        }
        if (card.containsKey('auxiliary_verb') && card['auxiliary_verb'] != null) {
          cleanCard['auxiliary_verb'] = card['auxiliary_verb'] is String
              ? (card['auxiliary_verb'] as String).trim()
              : card['auxiliary_verb']?.toString().trim();
          if (cleanCard['auxiliary_verb'] == '') cleanCard.remove('auxiliary_verb');
        }
        if (card.containsKey('register') && card['register'] != null) {
          cleanCard['register'] = card['register'] is String
              ? (card['register'] as String).trim()
              : card['register']?.toString().trim();
          if (cleanCard['register'] == '') cleanCard.remove('register');
        }
        
        return cleanCard;
      }).toList();
      
      // Ensure term is not empty (double-check after trimming)
      if (trimmedTerm.isEmpty) {
        return {
          'success': false,
          'message': 'Term cannot be empty',
        };
      }
      
      final body = {
        'term': trimmedTerm,
        'concept': cleanConceptData,
        'cards': cleanCardsData,
      };
      
      // Only include part_of_speech if provided
      if (partOfSpeech != null && partOfSpeech.trim().isNotEmpty) {
        body['part_of_speech'] = partOfSpeech.trim();
      }
      
      // Only include topic_id if provided
      if (topicId != null) {
        body['topic_id'] = topicId;
      }
      
      // Only include user_id if provided
      if (userId != null) {
        body['user_id'] = userId;
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': 'Concept created successfully',
          'data': data,
        };
      } else {
        // Handle error response - detail might be a string or a list
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          String errorMessage = 'Failed to confirm concept';
          
          if (error.containsKey('detail')) {
            final detail = error['detail'];
            if (detail is String) {
              errorMessage = detail;
            } else if (detail is List) {
              // If detail is a list of validation errors, format them
              final errors = detail.map((e) {
                if (e is Map) {
                  final loc = e['loc'] as List?;
                  final msg = e['msg'] as String?;
                  if (loc != null && msg != null) {
                    return '${loc.join('.')}: $msg';
                  }
                }
                return e.toString();
              }).join(', ');
              errorMessage = 'Validation error: $errors';
            } else {
              errorMessage = detail.toString();
            }
          }
          
          return {
            'success': false,
            'message': errorMessage,
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to confirm concept: ${response.statusCode} - ${response.body}',
          };
        }
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Create a concept with cards for multiple languages using LLM generation.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> createConcept({
    required String term,
    int? topicId,
    int? userId,
    String? partOfSpeech,
    String? coreMeaningEn,
    required List<String> languages,
    List<String>? excludedSenses,
  }) async {
    // Validate term is not empty
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return {
        'success': false,
        'message': 'Term cannot be empty',
      };
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lemmas/generate');
    
    try {
      final body = {
        'term': trimmedTerm,
        'languages': languages.map((lang) => lang.toLowerCase()).toList(),
      };
      
      // Only include part_of_speech if provided
      if (partOfSpeech != null && partOfSpeech.trim().isNotEmpty) {
        body['part_of_speech'] = partOfSpeech.trim();
      }
      
      // Only include topic_id if provided
      if (topicId != null) {
        body['topic_id'] = topicId;
      }
      
      // Only include user_id if provided
      if (userId != null) {
        body['user_id'] = userId;
      }
      
      // Only include core_meaning_en if provided
      if (coreMeaningEn != null && coreMeaningEn.trim().isNotEmpty) {
        body['core_meaning_en'] = coreMeaningEn.trim();
      }
      
      // Only include excluded_senses if provided
      if (excludedSenses != null && excludedSenses.isNotEmpty) {
        body['excluded_senses'] = excludedSenses.map((sense) => sense.trim()).toList();
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': 'Concept created successfully',
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to create concept',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Create a concept record with term, description, and topic (if given).
  /// This does NOT create any lemmas - use generateCardsForConcepts to create lemmas.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> createConceptOnly({
    required String term,
    String? description,
    int? topicId,
    int? userId,
  }) async {
    // Validate term is not empty
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return {
        'success': false,
        'message': 'Term cannot be empty',
      };
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/generate-only');
    
    try {
      final body = <String, dynamic>{
        'term': trimmedTerm,
      };
      
      // Only include description if provided
      if (description != null && description.trim().isNotEmpty) {
        body['description'] = description.trim();
      }
      
      // Only include topic_id if provided
      if (topicId != null) {
        body['topic_id'] = topicId;
      }
      
      // Only include user_id if provided
      if (userId != null) {
        body['user_id'] = userId;
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': 'Concept created successfully',
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to create concept',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Get concepts that are missing cards for the given list of languages.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> getConceptsWithMissingLanguages({
    required List<String> languages,
    List<String>? levels,
    List<String>? partOfSpeech,
    List<int>? topicIds,
    bool includeWithoutTopic = false,
    bool includePublic = true,
    bool includePrivate = true,
    int? ownUserId,
    String? search,
  }) async {
    if (languages.isEmpty) {
      return {
        'success': false,
        'message': 'At least one language is required',
      };
    }
    
    // Load user ID if available
    int? userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        userId = user.id;
      }
    } catch (e) {
      // If loading user fails, continue without user_id
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/missing-languages');
    
    try {
      final body = <String, dynamic>{
        'languages': languages.map((lang) => lang.toLowerCase()).toList(),
      };
      
      // Only include user_id if available
      if (userId != null) {
        body['user_id'] = userId;
      }
      
      // Add levels filter if provided
      if (levels != null && levels.isNotEmpty) {
        body['levels'] = levels;
      }
      
      // Add part_of_speech filter if provided
      if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
        body['part_of_speech'] = partOfSpeech;
      }
      
      // Add topic_ids filter if provided
      if (topicIds != null && topicIds.isNotEmpty) {
        body['topic_ids'] = topicIds;
      }
      
      // Add include_without_topic filter
      if (includeWithoutTopic) {
        body['include_without_topic'] = true;
      }
      
      // Add include_public filter (only if false, true is default)
      if (!includePublic) {
        body['include_public'] = false;
      }
      
      // Add include_private filter (only if false, true is default)
      if (!includePrivate) {
        body['include_private'] = false;
      }
      
      // Add own_user_id for private filtering
      if (ownUserId != null) {
        body['own_user_id'] = ownUserId;
      }
      
      // Add search filter if provided
      if (search != null && search.trim().isNotEmpty) {
        body['search'] = search.trim();
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'message': 'Concepts retrieved successfully',
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to get concepts',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Generate a lemma for a term and target language using LLM.
  /// If conceptId is provided, the lemma will be saved as a lemma in the database.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful) - contains the lemma data
  static Future<Map<String, dynamic>> generateLemma({
    required String term,
    required String targetLanguage,
    String? description,
    String? partOfSpeech,
    int? conceptId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lemma/generate');
    
    try {
      final body = <String, dynamic>{
        'term': term.trim(),
        'target_language': targetLanguage.toLowerCase(),
      };
      
      // Only include description if provided
      if (description != null && description.trim().isNotEmpty) {
        body['description'] = description.trim();
      }
      
      // Only include part_of_speech if provided
      if (partOfSpeech != null && partOfSpeech.trim().isNotEmpty) {
        body['part_of_speech'] = partOfSpeech.trim();
      }
      
      // Only include concept_id if provided (will save lemma to database)
      if (conceptId != null) {
        body['concept_id'] = conceptId;
      }
      
      print('=== FLASHCARD SERVICE REQUEST (generateLemma) ===');
      print('URL: $url');
      print('Request body: ${jsonEncode(body)}');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('=== FLASHCARD SERVICE RESPONSE (generateLemma) ===');
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        print('Parsed data: $data');
        
        return {
          'success': true,
          'message': 'Lemma generated successfully',
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        print('Returning failure with status code error: ${error['detail']}');
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to generate lemma',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Generate lemmas for multiple languages using the batch endpoint.
  /// This is more efficient as it sends the system instruction once.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> generateLemmasBatch({
    required String term,
    required List<String> targetLanguages,
    String? description,
    String? partOfSpeech,
    int? conceptId,
  }) async {
    if (targetLanguages.isEmpty) {
      return {
        'success': false,
        'message': 'At least one language is required',
      };
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lemma/generate-batch');
    
    try {
      final body = <String, dynamic>{
        'term': term.trim(),
        'target_languages': targetLanguages.map((lang) => lang.toLowerCase()).toList(),
      };
      
      // Only include description if provided
      if (description != null && description.trim().isNotEmpty) {
        body['description'] = description.trim();
      }
      
      // Only include part_of_speech if provided
      if (partOfSpeech != null && partOfSpeech.trim().isNotEmpty) {
        body['part_of_speech'] = partOfSpeech.trim();
      }
      
      // Only include concept_id if provided (will save cards to database)
      if (conceptId != null) {
        body['concept_id'] = conceptId;
      }
      
      print('=== FLASHCARD SERVICE REQUEST (generateLemmasBatch) ===');
      print('URL: $url');
      print('Request body: ${jsonEncode(body)}');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('=== FLASHCARD SERVICE RESPONSE (generateLemmasBatch) ===');
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        print('Parsed data: $data');
        
        final lemmas = data['lemmas'] as List<dynamic>? ?? [];
        final totalTokenUsage = data['total_token_usage'] as Map<String, dynamic>?;
        
        return {
          'success': true,
          'message': 'Lemmas generated successfully',
          'data': {
            'lemmas': lemmas,
            'total_token_usage': totalTokenUsage,
            'lemmas_created': lemmas.length,
            'session_cost_usd': (totalTokenUsage?['cost_usd'] as num?)?.toDouble() ?? 0.0,
          },
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        print('Returning failure with status code error: ${error['detail']}');
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to generate lemmas',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Generate cards for a single concept using LLM.
  /// Uses the batch endpoint for multiple languages (more efficient).
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> generateCardsForConcept({
    required int conceptId,
    required List<String> languages,
  }) async {
    if (languages.isEmpty) {
      return {
        'success': false,
        'message': 'At least one language is required',
      };
    }
    
    // First, get the concept to get term, description, and part_of_speech
    final conceptUrl = Uri.parse('${ApiConfig.apiBaseUrl}/concepts/$conceptId');
    Map<String, dynamic>? conceptData;
    
    try {
      final conceptResponse = await http.get(conceptUrl);
      if (conceptResponse.statusCode == 200) {
        conceptData = jsonDecode(conceptResponse.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch concept data',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch concept: ${e.toString()}',
      };
    }
    
    if (conceptData == null) {
      return {
        'success': false,
        'message': 'Concept data is missing',
      };
    }
    
    final term = conceptData['term'] as String?;
    final description = conceptData['description'] as String?;
    final partOfSpeech = conceptData['part_of_speech'] as String?;
    
    if (term == null || term.isEmpty) {
      return {
        'success': false,
        'message': 'Concept term is missing',
      };
    }
    
    // Use batch endpoint for multiple languages (more efficient)
    return await generateLemmasBatch(
      term: term,
      targetLanguages: languages,
      description: description,
      partOfSpeech: partOfSpeech,
      conceptId: conceptId,
    );
  }

  /// Generate cards for concepts using LLM.
  /// Retrieves LLM output, validates it, and writes cards directly to the database.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> generateCardsForConcepts({
    required List<int> conceptIds,
    required List<String> languages,
  }) async {
    if (conceptIds.isEmpty) {
      return {
        'success': false,
        'message': 'At least one concept ID is required',
      };
    }
    
    if (languages.isEmpty) {
      return {
        'success': false,
        'message': 'At least one language is required',
      };
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lemmas/generate');
    
    try {
      final body = {
        'concept_ids': conceptIds,
        'languages': languages.map((lang) => lang.toLowerCase()).toList(),
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Check if there are any errors in the response
        final errors = data['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          // If there are errors, treat as failure
          final errorMessages = errors.map((e) => e.toString()).join('\n');
          return {
            'success': false,
            'message': errorMessages,
            'data': data,
          };
        }
        
        return {
          'success': true,
          'message': 'Lemmas generated successfully',
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to generate cards',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      // Provide more helpful error messages for common connection issues
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Upload an image for a concept.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  static Future<Map<String, dynamic>> uploadConceptImage({
    required int conceptId,
    required File imageFile,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concept-image/upload/$conceptId');
    
    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Image uploaded successfully',
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to upload image',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      final errorStr = e.toString();
      if (errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  /// Generate an image preview using Gemini without creating a concept.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': File? (if successful, contains the generated image file)
  static Future<Map<String, dynamic>> generateImagePreview({
    required String term,
    String? description,
    String? topicDescription,
  }) async {
    // Validate term is not empty
    final trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return {
        'success': false,
        'message': 'Term cannot be empty',
      };
    }
    
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/concept-image/generate-preview');
    
    try {
      final body = <String, dynamic>{
        'term': trimmedTerm,
      };
      
      if (description != null && description.trim().isNotEmpty) {
        body['description'] = description.trim();
      }
      
      if (topicDescription != null && topicDescription.trim().isNotEmpty) {
        body['topic_description'] = topicDescription.trim();
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Save the image bytes to a temporary file
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${tempDir.path}/generated_image_$timestamp.jpg');
        await tempFile.writeAsBytes(response.bodyBytes);
        
        return {
          'success': true,
          'message': 'Image generated successfully',
          'data': tempFile,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to generate image',
        };
      }
    } catch (e) {
      String errorMessage = 'Network error: ${e.toString()}';
      
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('SocketException')) {
        final baseUrl = ApiConfig.baseUrl;
        errorMessage = 'Cannot connect to server at $baseUrl.\n\n'
            'Please ensure:\n'
            '• The API server is running\n'
            '• You are using the correct API URL for your platform';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }
}

