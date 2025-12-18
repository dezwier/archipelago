import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/create/data/network_utils.dart';

class ImageService {
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
      String errorMessage = NetworkUtils.formatNetworkError(e);
      
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
        // Check if response actually contains image data
        if (response.bodyBytes.isEmpty) {
          return {
            'success': false,
            'message': 'Failed to generate image, no image in data response',
          };
        }
        
        // Check if response is JSON error instead of image
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('application/json')) {
          try {
            final error = jsonDecode(response.body) as Map<String, dynamic>;
            return {
              'success': false,
              'message': error['detail'] as String? ?? 'Failed to generate image',
            };
          } catch (_) {
            // If JSON decode fails, continue to treat as image
          }
        }
        
        // Validate that we have actual image data (at least some bytes)
        if (response.bodyBytes.length < 100) {
          // Very small response is likely not a valid image
          return {
            'success': false,
            'message': 'Failed to generate image, response too small to be valid image data',
          };
        }
        
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
        // Try to parse error response
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to generate image',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to generate image: ${response.statusCode} ${response.reasonPhrase}',
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
}

