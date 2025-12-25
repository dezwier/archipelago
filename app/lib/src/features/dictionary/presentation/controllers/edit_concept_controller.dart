import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/shared/domain/user.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';

class EditConceptController extends ChangeNotifier {
  final PairedDictionaryItem item;
  final TopicsProvider topicsProvider;
  final TextEditingController termController;
  final TextEditingController descriptionController;
  int? selectedTopicId;
  bool isLoading = false;
  String? errorMessage;

  EditConceptController({
    required this.item,
    required this.topicsProvider,
  }) : termController = TextEditingController(text: item.conceptTerm ?? ''),
        descriptionController = TextEditingController(text: item.conceptDescription ?? ''),
        selectedTopicId = item.topicId {
    topicsProvider.addListener(_onTopicsChanged);
    _updateTopics();
  }
  
  List<Topic> get topics => topicsProvider.topics;
  bool get isLoadingTopics => topicsProvider.isLoading;
  
  void _onTopicsChanged() {
    _updateTopics();
  }
  
  void _updateTopics() {
    notifyListeners();
  }

  void setSelectedTopicId(int? topicId) {
    if (selectedTopicId != topicId) {
      selectedTopicId = topicId;
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
    topicsProvider.removeListener(_onTopicsChanged);
    termController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}

