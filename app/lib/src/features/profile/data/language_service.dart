import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';
import '../domain/language.dart';

class LanguageService {
  static Future<List<Language>> getLanguages() async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/languages');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final languagesList = data['languages'] as List<dynamic>;
        return languagesList
            .map((lang) => Language.fromJson(lang as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}

