import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/profile/data/language_service.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Mixin for data loading functionality in DictionaryScreen
mixin DictionaryScreenData<T extends StatefulWidget> on State<T> {
  DictionaryController get controller;
  LanguageVisibilityManager get languageVisibilityManager;
  List<Language> get allLanguages;
  List<Topic> get allTopics;
  bool get isLoadingTopics;
  
  void setAllLanguages(List<Language> value);
  void setAllTopics(List<Topic> value);
  void setIsLoadingTopics(bool value);
  void onControllerChanged();

  Future<void> loadLanguages() async {
    final languages = await LanguageService.getLanguages();
    
    setState(() {
      setAllLanguages(languages);
      // Initialize visibility - default to English if logged out
      if (controller.currentUser == null) {
        languageVisibilityManager.initializeForLoggedOutUser(languages);
      }
    });
    
    // Update defaults based on user state
    onControllerChanged();
    
    // Set language filter after visibility is initialized (for search only)
    if (languageVisibilityManager.languagesToShow.isNotEmpty) {
      controller.setLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
      // Set visible languages for count calculation
      controller.setVisibleLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
    }
  }
  
  Future<void> loadTopics() async {
    setState(() {
      setIsLoadingTopics(true);
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      int? userId;
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        userId = user.id;
      }
      
      final topics = await TopicService.getTopics(userId: userId);
      
      setState(() {
        setAllTopics(topics);
        setIsLoadingTopics(false);
        // Set all available topic IDs in controller first
        final topicIds = topics.map((t) => t.id).toSet();
        controller.setAllAvailableTopicIds(topicIds);
        
        // Remove any selected topic IDs that are no longer available (e.g., private topics after logout)
        final validSelectedIds = controller.selectedTopicIds.intersection(topicIds);
        if (validSelectedIds.length != controller.selectedTopicIds.length) {
          // Some selected topics are no longer available, update the filter
          if (validSelectedIds.isEmpty && topics.isNotEmpty) {
            // If all selected topics were removed, select all available topics
            controller.setTopicFilter(topicIds);
          } else {
            // Keep only the valid selected topics
            controller.setTopicFilter(validSelectedIds);
          }
        } else if (topics.isNotEmpty && controller.selectedTopicIds.isEmpty) {
          // Set all topics as selected by default if nothing is selected
          controller.setTopicFilter(topicIds);
        }
      });
    } catch (e) {
      setState(() {
        setIsLoadingTopics(false);
      });
    }
  }

  void handleControllerChanged() {
    // Update language visibility defaults when user data is loaded
    if (controller.currentUser != null && allLanguages.isNotEmpty) {
      final sourceCode = controller.sourceLanguageCode;
      final targetCode = controller.targetLanguageCode;
      
      // Only update if languages list is empty (initial state)
      if (languageVisibilityManager.languagesToShow.isEmpty) {
        languageVisibilityManager.initializeForLoggedInUser(
          allLanguages,
          sourceCode,
          targetCode,
        );
        setState(() {});
        // Set language filter to visible languages (for search only)
        controller.setLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
        // Set visible languages for count calculation
        controller.setVisibleLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
      }
    } else if (controller.currentUser == null && allLanguages.isNotEmpty) {
      // When logged out, default to English only
      if (languageVisibilityManager.languagesToShow.isEmpty) {
        languageVisibilityManager.initializeForLoggedOutUser(allLanguages);
        setState(() {});
        // Set language filter to visible languages (for search only)
        controller.setLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
        // Set visible languages for count calculation
        controller.setVisibleLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
      }
    }
  }
}

