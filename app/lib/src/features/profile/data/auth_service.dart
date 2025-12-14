import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/auth/login');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'user': User.fromJson(data['user'] as Map<String, dynamic>),
          'message': data['message'] as String,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Login failed',
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
            '• You are using the correct API URL for your platform\n'
            '• For physical devices, set hostIp in api_config.dart';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String nativeLanguage,
    String? learningLanguage,
  ) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/auth/register');
    
    try {
      final body = {
        'username': username,
        'email': email,
        'password': password,
        'native_language': nativeLanguage,
      };
      if (learningLanguage != null && learningLanguage.isNotEmpty) {
        body['learning_language'] = learningLanguage;
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
          'user': User.fromJson(data['user'] as Map<String, dynamic>),
          'message': data['message'] as String,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Registration failed',
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
            '• You are using the correct API URL for your platform\n'
            '• For physical devices, set hostIp in api_config.dart';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> updateUserLanguages(
    int userId,
    String? langNative,
    String? langLearning,
  ) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/auth/update-languages?user_id=$userId');
    
    try {
      final body = <String, dynamic>{};
      if (langNative != null) {
        body['lang_native'] = langNative;
      }
      if (langLearning != null) {
        body['lang_learning'] = langLearning;
      }

      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'user': User.fromJson(data['user'] as Map<String, dynamic>),
          'message': data['message'] as String,
        };
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'message': error['detail'] as String? ?? 'Update failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}

