import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';

class EditConceptController extends ChangeNotifier {
  final PairedDictionaryItem item;
  final TextEditingController termController;
  final TextEditingController descriptionController;
  int? selectedTopicId;
  List<Topic> topics = [];
  bool isLoading = false;
  bool isLoadingTopics = false;
  String? errorMessage;

  EditConceptController({
    required this.item,
  }) : termController = TextEditingController(text: item.conceptTerm ?? ''),
        descriptionController = TextEditingController(text: item.conceptDescription ?? ''),
        selectedTopicId = item.topicId {
    _loadTopics();
  }

  void setSelectedTopicId(int? topicId) {
    if (selectedTopicId != topicId) {
      selectedTopicId = topicId;
      notifyListeners();
    }
  }

  Future<void> _loadTopics() async {
    isLoadingTopics = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      int? userId;
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        userId = user.id;
      }

      topics = await TopicService.getTopics(userId: userId);
      isLoadingTopics = false;
      notifyListeners();
    } catch (e) {
      isLoadingTopics = false;
      errorMessage = 'Error loading topics: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<bool> updateConcept() async {
    if (termController.text.trim().isEmpty) {
      errorMessage = 'Term cannot be empty';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await DictionaryService.updateConcept(
        conceptId: item.conceptId,
        term: termController.text.trim(),
        description: descriptionController.text.trim().isEmpty 
            ? null 
            : descriptionController.text.trim(),
        topicId: selectedTopicId,
      );

      isLoading = false;

      if (result['success'] == true) {
        notifyListeners();
        return true;
      } else {
        errorMessage = result['message'] as String? ?? 'Failed to update concept';
        notifyListeners();
        return false;
      }
    } catch (e) {
      isLoading = false;
      errorMessage = 'Error updating concept: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    termController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}

