import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/create/data/network_utils.dart';

class LemmaService {
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
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
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
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
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
      return {
        'success': false,
        'message': NetworkUtils.formatNetworkError(e),
      };
    }
  }
}

