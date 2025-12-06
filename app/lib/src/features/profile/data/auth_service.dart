import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';
import '../domain/user.dart';

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
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String nativeLanguage,
  ) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/auth/register');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'native_language': nativeLanguage,
        }),
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
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}

