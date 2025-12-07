import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';

class VocabularyService {
  /// Get all vocabulary cards for a user's source and target languages, paired by concept_id.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'items': List<Map<String, dynamic>> (if successful) - paired vocabulary items
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> getVocabulary({
    required int userId,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/vocabulary?user_id=$userId');
    
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
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to fetch vocabulary',
        };
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
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to update card',
        };
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
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to delete concept',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting concept: ${e.toString()}',
      };
    }
  }
}

