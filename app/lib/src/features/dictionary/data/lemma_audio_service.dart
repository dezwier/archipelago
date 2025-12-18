import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';

/// Service for generating and retrieving lemma audio recordings.
class LemmaAudioService {
  /// Generate audio for a lemma using TTS.
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'audioUrl': String? (if successful) - the audio URL path
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> generateAudio({
    required int lemmaId,
    String? term,
    String? description,
    String? languageCode,
  }) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/lemma-audio/generate');
    
    try {
      final body = <String, dynamic>{
        'lemma_id': lemmaId,
      };
      if (term != null) {
        body['term'] = term;
      }
      if (description != null) {
        body['description'] = description;
      }
      if (languageCode != null) {
        body['language_code'] = languageCode;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // The endpoint returns a FileResponse, but we need to extract the audio_url
        // from the lemma. We'll need to fetch the lemma again to get the updated audio_url
        // For now, we'll construct the expected URL based on the lemma_id
        final audioUrl = '/assets/audio/$lemmaId.mp3';
        return {
          'success': true,
          'audioUrl': audioUrl,
        };
      } else {
        // Try to parse error response as JSON
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'success': false,
            'message': error['detail'] as String? ?? 'Failed to generate audio',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Failed to generate audio: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error generating audio: ${e.toString()}',
      };
    }
  }

  /// Get the audio URL for a lemma.
  /// Returns the full URL if audio exists, null otherwise.
  static String? getAudioUrl(String? audioPath) {
    if (audioPath == null || audioPath.isEmpty) return null;
    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      return audioPath;
    }
    return '${ApiConfig.baseUrl}$audioPath';
  }
}

