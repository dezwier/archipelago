import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';
import 'package:archipelago/src/features/shared/providers/languages_provider.dart';

/// Helper class for data loading functionality in DictionaryScreen
class DictionaryScreenDataHelper {
  final DictionaryController controller;
  final LanguageVisibilityManager languageVisibilityManager;
  final TopicsProvider topicsProvider;
  final LanguagesProvider languagesProvider;
  final Function(List<Language>) setAllLanguages;
  final Function(List<Topic>) setAllTopics;
  final Function(bool) setIsLoadingTopics;
  final Function() onControllerChanged;
  final VoidCallback setState;

  DictionaryScreenDataHelper({
    required this.controller,
    required this.languageVisibilityManager,
    required this.topicsProvider,
    required this.languagesProvider,
    required this.setAllLanguages,
    required this.setAllTopics,
    required this.setIsLoadingTopics,
    required this.onControllerChanged,
    required this.setState,
  });

  void loadLanguages() {
    final languages = languagesProvider.languages;
    
    // Initialize visibility - default to English if logged out
    // For logged in users, initialize if we have user data, otherwise wait for handleControllerChanged
    // This doesn't call setState, so it's safe to do synchronously
    if (controller.currentUser == null) {
      languageVisibilityManager.initializeForLoggedOutUser(languages);
    } else if (languageVisibilityManager.languagesToShow.isEmpty) {
      // Initialize for logged in user if not already initialized and we have user data
      final sourceCode = controller.sourceLanguageCode;
      final targetCode = controller.targetLanguageCode;
      // Only initialize if we have at least one language code
      if (sourceCode != null || targetCode != null) {
        languageVisibilityManager.initializeForLoggedInUser(
          languages,
          sourceCode,
          targetCode,
        );
      }
    }
    
    // Defer all state updates to avoid calling setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setAllLanguages(languages);
      
      // Update defaults based on user state
      onControllerChanged();
      
      // Set language filter after visibility is initialized (for search only)
      // Only set if languages to show have changed to avoid infinite loops
      final visibleCodes = languageVisibilityManager.getVisibleLanguageCodes();
      if (languageVisibilityManager.languagesToShow.isNotEmpty) {
        // Check if values actually changed before setting to avoid triggering reloads
        final currentVisible = controller.visibleLanguageCodes.toSet();
        final newVisible = visibleCodes.toSet();
        if (currentVisible != newVisible) {
          controller.setVisibleLanguageCodes(visibleCodes);
        }
        final currentLanguageCodes = controller.languageCodes.toSet();
        if (currentLanguageCodes != newVisible) {
          controller.setLanguageCodes(visibleCodes);
        }
      }
      
      setState();
    });
  }
  
  void loadTopics() {
    final topics = topicsProvider.topics;
    final isLoading = topicsProvider.isLoading;
    
    // Defer all state updates to avoid calling setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setIsLoadingTopics(isLoading);
      setAllTopics(topics);
      
      // Set all available topic IDs in controller first (this doesn't trigger reload)
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
      
      setState();
    });
  }

  void handleControllerChanged(List<Language> allLanguages) {
    // Update language visibility defaults when user data is loaded
    if (controller.currentUser != null && allLanguages.isNotEmpty) {
      final sourceCode = controller.sourceLanguageCode;
      final targetCode = controller.targetLanguageCode;
      
      // Always initialize if we have user data and languages (handles hot restart)
      // Check if we need to initialize (either empty or doesn't match current user languages)
      final needsInitialization = languageVisibilityManager.languagesToShow.isEmpty ||
          (sourceCode != null && !languageVisibilityManager.languagesToShow.contains(sourceCode)) ||
          (targetCode != null && !languageVisibilityManager.languagesToShow.contains(targetCode));
      
      if (needsInitialization && (sourceCode != null || targetCode != null)) {
        languageVisibilityManager.initializeForLoggedInUser(
          allLanguages,
          sourceCode,
          targetCode,
        );
        // Defer controller updates to avoid calling notifyListeners() during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Set language filter to visible languages (for search only)
          // Only set if values have changed to avoid infinite loops
          final visibleCodes = languageVisibilityManager.getVisibleLanguageCodes();
          final currentVisible = controller.visibleLanguageCodes.toSet();
          final newVisible = visibleCodes.toSet();
          if (currentVisible != newVisible) {
            controller.setVisibleLanguageCodes(visibleCodes);
          }
          final currentLanguageCodes = controller.languageCodes.toSet();
          if (currentLanguageCodes != newVisible) {
            controller.setLanguageCodes(visibleCodes);
          }
          setState();
        });
      }
    } else if (controller.currentUser == null && allLanguages.isNotEmpty) {
      // When logged out, default to English only
      // Always initialize if empty (handles hot restart)
      if (languageVisibilityManager.languagesToShow.isEmpty || 
          !languageVisibilityManager.languagesToShow.contains('en')) {
        languageVisibilityManager.initializeForLoggedOutUser(allLanguages);
        // Defer controller updates to avoid calling notifyListeners() during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Set language filter to visible languages (for search only)
          // Only set if values have changed to avoid infinite loops
          final visibleCodes = languageVisibilityManager.getVisibleLanguageCodes();
          final currentVisible = controller.visibleLanguageCodes.toSet();
          final newVisible = visibleCodes.toSet();
          if (currentVisible != newVisible) {
            controller.setVisibleLanguageCodes(visibleCodes);
          }
          final currentLanguageCodes = controller.languageCodes.toSet();
          if (currentLanguageCodes != newVisible) {
            controller.setLanguageCodes(visibleCodes);
          }
          setState();
        });
      }
    }
  }
}

