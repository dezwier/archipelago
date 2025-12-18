import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:archipelago/src/features/create/data/network_utils.dart';

class ConceptService {
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
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
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
          return {
            'success': false,
            'message': NetworkUtils.parseErrorResponse(error),
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to confirm concept: ${response.statusCode} - ${response.body}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
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
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
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
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
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
    bool includeLemmas = true,
    bool includePhrases = true,
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
      
      // Add include_lemmas filter
      if (!includeLemmas) {
        body['include_lemmas'] = false;
      }
      
      // Add include_phrases filter
      if (!includePhrases) {
        body['include_phrases'] = false;
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
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
      };
    }
  }
}

