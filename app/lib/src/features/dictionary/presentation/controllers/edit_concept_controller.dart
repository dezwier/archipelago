import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';

class EditConceptController extends ChangeNotifier {
  final PairedDictionaryItem item;
  final TopicsProvider topicsProvider;
  final TextEditingController termController;
  final TextEditingController descriptionController;
  List<Topic> selectedTopics = [];
  bool isLoading = false;
  String? errorMessage;

  EditConceptController({
    required this.item,
    required this.topicsProvider,
  }) : termController = TextEditingController(text: item.conceptTerm ?? ''),
        descriptionController = TextEditingController(text: item.conceptDescription ?? '') {
    // Initialize selected topics from item.topics
    _initializeSelectedTopics();
    topicsProvider.addListener(_onTopicsChanged);
    _updateTopics();
  }
  
  void _initializeSelectedTopics() {
    // Get topic IDs from item.topics (list of maps with id, name, icon)
    final topicIds = item.topics.map((topicMap) => topicMap['id'] as int).toList();
    // Find matching topics from topicsProvider
    selectedTopics = topicsProvider.topics.where((topic) => topicIds.contains(topic.id)).toList();
  }
  
  List<Topic> get topics => topicsProvider.topics;
  bool get isLoadingTopics => topicsProvider.isLoading;
  
  void _onTopicsChanged() {
    _updateTopics();
  }
  
  void _updateTopics() {
    notifyListeners();
  }

  void setSelectedTopics(List<Topic> topics) {
    if (selectedTopics != topics) {
      selectedTopics = List<Topic>.from(topics);
      notifyListeners();
    }
  }

  void toggleTopic(Topic topic) {
    final index = selectedTopics.indexWhere((t) => t.id == topic.id);
    if (index >= 0) {
      selectedTopics.removeAt(index);
    } else {
      selectedTopics.add(topic);
    }
    notifyListeners();
  }

  void removeSelectedTopic(Topic topic) {
    selectedTopics.removeWhere((t) => t.id == topic.id);
    notifyListeners();
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
        topicIds: selectedTopics.map((t) => t.id).toList(),
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

