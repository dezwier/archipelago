import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';

/// Service for learning feature - retrieving new cards for learning
class LearnService {
  /// Get new cards (lemmas without cards for the user) from the given lemma IDs.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'concepts': List<Map<String, dynamic>> (if successful) - list of concepts, each with learning_lemma and native_lemma
  /// - 'native_language': String (if successful) - user's native language code
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getNewCards({
    required int userId,
    required String language, // Learning language
    String? nativeLanguage, // Native language (optional)
    required List<int> lemmaIds,
    int? maxN,
  }) async {
    if (lemmaIds.isEmpty) {
      return {
        'success': false,
        'message': 'lemma_ids cannot be empty',
      };
    }
    
    final uri = Uri.parse('${ApiConfig.apiBaseUrl}/lemmas/new-cards');
    final queryParams = <String, String>{
      'user_id': userId.toString(),
      'language': language,
      'lemma_ids': lemmaIds.join(','),
    };
    
    // Add native_language if provided
    if (nativeLanguage != null && nativeLanguage.isNotEmpty) {
      queryParams['native_language'] = nativeLanguage;
    }
    
    // Add max_n if provided
    if (maxN != null) {
      queryParams['max_n'] = maxN.toString();
    }
    
    final url = uri.replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final conceptsList = responseData['concepts'] as List<dynamic>;
        final nativeLanguage = responseData['native_language'] as String?;
        return {
          'success': true,
          'concepts': conceptsList.map((concept) => concept as Map<String, dynamic>).toList(),
          'native_language': nativeLanguage,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to get new cards',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting new cards: ${e.toString()}',
      };
    }
  }
}

