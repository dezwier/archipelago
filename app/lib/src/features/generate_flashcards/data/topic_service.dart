import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../constants/api_config.dart';

class Topic {
  final int id;
  final String name;

  Topic({required this.id, required this.name});

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class TopicService {
  /// Get all topics.
  static Future<List<Topic>> getTopics() async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/topics');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final topicsList = data['topics'] as List<dynamic>;
        return topicsList
            .map((topic) => Topic.fromJson(topic as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Create a topic or get existing one if it already exists.
  static Future<Topic?> createTopic(String name) async {
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/topics');
    
    try {
      final body = {
        'name': name.trim(),
      };
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Topic.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

