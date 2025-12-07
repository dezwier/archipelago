import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';

class FlashcardService {
  /// Generate a flashcard by creating concept and cards for source and target languages.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String
  /// - 'data': Map<String, dynamic> (if successful)
  static Future<Map<String, dynamic>> generateFlashcard({
    required String concept,
    required String sourceLanguage,
    required String targetLanguage,
    String? topic,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcards/generate');
    
    try {
      // Convert all text to lowercase before sending
      final body = {
        'concept': concept.toLowerCase().trim(),
        'source_language': sourceLanguage.toLowerCase(),
        'target_language': targetLanguage.toLowerCase(),
      };
      
      // Only include topic if provided
      if (topic != null && topic.trim().isNotEmpty) {
        body['topic'] = topic.toLowerCase().trim();
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
          'message': data['message'] as String? ?? 'Flashcard generated successfully',
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Failed to generate flashcard',
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
}

