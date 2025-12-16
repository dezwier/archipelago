import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class FlashcardExportService {
  /// Export flashcards as PDF
  /// 
  /// Returns a map with:
  /// - 'success': bool
  /// - 'message': String (if error)
  static Future<Map<String, dynamic>> exportFlashcardsPdf({
    required List<int> conceptIds,
    required List<String> languagesFront,
    required List<String> languagesBack,
    bool includeImageFront = true,
    bool includePhraseFront = true,
    bool includeIpaFront = true,
    bool includeDescriptionFront = true,
    bool includeImageBack = true,
    bool includePhraseBack = true,
    bool includeIpaBack = true,
    bool includeDescriptionBack = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.apiBaseUrl}/flashcard-export/pdf');
      
      final requestBody = {
        'concept_ids': conceptIds,
        'languages_front': languagesFront,
        'languages_back': languagesBack,
        'include_image_front': includeImageFront,
        'include_text_front': includePhraseFront, // Phrase is the term/title
        'include_ipa_front': includeIpaFront,
        'include_description_front': includeDescriptionFront,
        'include_image_back': includeImageBack,
        'include_text_back': includePhraseBack, // Phrase is the term/title
        'include_ipa_back': includeIpaBack,
        'include_description_back': includeDescriptionBack,
      };
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        // Save PDF to temporary file and share it
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/flashcards.pdf');
        await file.writeAsBytes(bytes);
        
        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Flashcards PDF',
        );
        
        return {
          'success': true,
        };
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': errorBody['detail'] as String? ?? 'Failed to export flashcards',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error exporting flashcards: ${e.toString()}',
      };
    }
  }
}

