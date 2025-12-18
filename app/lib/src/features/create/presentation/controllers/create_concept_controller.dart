import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/features/create/domain/topic.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart' show TopicService;
import 'package:archipelago/src/features/create/data/flashcard_service.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/profile/data/language_service.dart';

/// Result of concept creation operation
class CreateConceptResult {
  final bool success;
  final String? message;
  final int? conceptId;
  final Map<String, bool>? languageVisibility;
  final List<String>? languagesToShow;
  final String? warningMessage; // For non-critical errors (e.g., image upload failed)

  CreateConceptResult({
    required this.success,
    this.message,
    this.conceptId,
    this.languageVisibility,
    this.languagesToShow,
    this.warningMessage,
  });
}

class CreateConceptController extends ChangeNotifier {
  // Form state
  String _term = '';
  String _description = '';
  Topic? _selectedTopic;
  List<String> _selectedLanguages = [];
  File? _selectedImage;

  // Loading states
  bool _isCreatingConcept = false;
  bool _isLoadingTopics = false;
  bool _isLoadingLanguages = false;

  // Status messages
  String? _statusMessage;
  Map<String, bool> _languageStatus = {}; // Track which languages have completed

  // Data
  List<Topic> _topics = [];
  List<Language> _languages = [];
  int? _userId;
  User? _currentUser;
  bool _hasSetDefaultLanguages = false;

  // Getters
  String get term => _term;
  String get description => _description;
  Topic? get selectedTopic => _selectedTopic;
  List<String> get selectedLanguages => _selectedLanguages;
  File? get selectedImage => _selectedImage;
  bool get isCreatingConcept => _isCreatingConcept;
  bool get isLoadingTopics => _isLoadingTopics;
  bool get isLoadingLanguages => _isLoadingLanguages;
  String? get statusMessage => _statusMessage;
  Map<String, bool> get languageStatus => _languageStatus;
  List<Topic> get topics => _topics;
  List<Language> get languages => _languages;
  int? get userId => _userId;
  User? get currentUser => _currentUser;

  // Setters
  void setTerm(String value) {
    if (_term != value) {
      _term = value;
      notifyListeners();
    }
  }

  void setDescription(String value) {
    if (_description != value) {
      _description = value;
      notifyListeners();
    }
  }

  void setSelectedTopic(Topic? topic) {
    if (_selectedTopic != topic) {
      _selectedTopic = topic;
      notifyListeners();
    }
  }

  void setSelectedLanguages(List<String> languages) {
    if (_selectedLanguages != languages) {
      _selectedLanguages = languages;
      notifyListeners();
    }
  }

  void setSelectedImage(File? image) {
    if (_selectedImage != image) {
      _selectedImage = image;
      notifyListeners();
    }
  }

  /// Load user ID from SharedPreferences
  Future<void> loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        _userId = user.id;
        _currentUser = user;
        notifyListeners();
        // Set default languages after loading user
        _setDefaultLanguages();
      } else {
        // User logged out
        _userId = null;
        _currentUser = null;
        notifyListeners();
      }
    } catch (e) {
      // If loading user fails, clear user state
      _userId = null;
      _currentUser = null;
      notifyListeners();
    }
  }

  /// Load topics from TopicService
  Future<void> loadTopics() async {
    _isLoadingTopics = true;
    notifyListeners();

    // Reload user ID in case login state changed
    await loadUserId();

    final topics = await TopicService.getTopics(userId: _userId);

    // Clear selected topic if it's no longer in the available topics (e.g., private topic after logout)
    if (_selectedTopic != null && !topics.any((t) => t.id == _selectedTopic!.id)) {
      _selectedTopic = null;
    }
    // Set the most recent topic as default (first in list since sorted by created_at desc)
    if (topics.isNotEmpty && _selectedTopic == null) {
      _selectedTopic = topics.first;
    }

    _topics = topics;
    _isLoadingTopics = false;
    notifyListeners();
  }

  /// Load languages from LanguageService
  Future<void> loadLanguages() async {
    _isLoadingLanguages = true;
    notifyListeners();

    final languages = await LanguageService.getLanguages();

    _languages = languages;
    _isLoadingLanguages = false;
    notifyListeners();

    // Set default languages after loading
    _setDefaultLanguages();
  }

  /// Set default languages based on user's native and learning languages
  void _setDefaultLanguages() {
    // Only set defaults once, and only if we have both user and languages loaded
    if (_hasSetDefaultLanguages || _currentUser == null || _languages.isEmpty) {
      return;
    }

    final defaultLanguages = <String>[];

    // Add native language if it exists in available languages
    if (_currentUser!.langNative.isNotEmpty) {
      final nativeLangExists = _languages.any((lang) => lang.code == _currentUser!.langNative);
      if (nativeLangExists) {
        defaultLanguages.add(_currentUser!.langNative);
      }
    }

    // Add learning language if it exists in available languages
    if (_currentUser!.langLearning != null && _currentUser!.langLearning!.isNotEmpty) {
      final learningLangExists = _languages.any((lang) => lang.code == _currentUser!.langLearning);
      if (learningLangExists) {
        defaultLanguages.add(_currentUser!.langLearning!);
      }
    }

    if (defaultLanguages.isNotEmpty) {
      _selectedLanguages = defaultLanguages;
      _hasSetDefaultLanguages = true;
      notifyListeners();
    }
  }

  /// Create a concept with optional lemmas and image
  /// Returns CreateConceptResult with success status and any relevant data
  Future<CreateConceptResult> createConcept() async {
    // Check if user is logged in
    if (_userId == null) {
      return CreateConceptResult(
        success: false,
        message: 'You must be logged in to create concepts',
      );
    }

    // Validate term is not empty
    final term = _term.trim();
    if (term.isEmpty) {
      return CreateConceptResult(
        success: false,
        message: 'Please enter a term',
      );
    }

    _isCreatingConcept = true;
    _statusMessage = 'Creating concept...';
    _languageStatus = {};
    notifyListeners();

    // Always create the concept first
    final createResult = await FlashcardService.createConceptOnly(
      term: term,
      description: _description.trim().isNotEmpty ? _description.trim() : null,
      topicId: _selectedTopic?.id,
      userId: _userId,
    );

    if (createResult['success'] != true) {
      _isCreatingConcept = false;
      _statusMessage = null;
      notifyListeners();
      return CreateConceptResult(
        success: false,
        message: createResult['message'] as String? ?? 'Failed to create concept',
      );
    }

    // Show concept created feedback
    _statusMessage = 'Concept created ✓';
    notifyListeners();

    final conceptData = createResult['data'] as Map<String, dynamic>?;
    final conceptId = conceptData?['id'] as int?;

    if (conceptId == null) {
      _isCreatingConcept = false;
      _statusMessage = null;
      notifyListeners();
      return CreateConceptResult(
        success: false,
        message: 'Concept created but ID is missing',
      );
    }

    String? warningMessage;

    // If languages are selected, generate lemmas for the created concept
    if (_selectedLanguages.isNotEmpty) {
      _statusMessage = 'Generating lemmas...';
      // Initialize all languages as in progress
      for (final langCode in _selectedLanguages) {
        _languageStatus[langCode] = false;
      }
      notifyListeners();

      // Start generating lemmas
      final lemmaFuture = FlashcardService.generateCardsForConcepts(
        conceptIds: [conceptId],
        languages: _selectedLanguages,
      );

      // Simulate per-language progress updates
      for (int i = 0; i < _selectedLanguages.length; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        _languageStatus[_selectedLanguages[i]] = true;
        notifyListeners();
      }

      final lemmaResult = await lemmaFuture;

      if (lemmaResult['success'] != true) {
        // Concept was created but lemma generation failed
        _isCreatingConcept = false;
        _statusMessage = null;
        _languageStatus = {};
        notifyListeners();
        return CreateConceptResult(
          success: false,
          message: 'Concept created but failed to generate lemmas: ${lemmaResult['message']}',
        );
      }

      // Ensure all languages are marked as completed
      for (final langCode in _selectedLanguages) {
        _languageStatus[langCode] = true;
      }
      _statusMessage = 'All lemmas created ✓';
      notifyListeners();

      // Clear status after a short delay
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // If image is provided and concept was created, upload the image
    if (_selectedImage != null) {
      final uploadResult = await FlashcardService.uploadConceptImage(
        conceptId: conceptId,
        imageFile: _selectedImage!,
      );

      if (uploadResult['success'] != true) {
        // Concept was created but image upload failed
        warningMessage = 'Concept created but image upload failed: ${uploadResult['message']}';
      }
    }

    _isCreatingConcept = false;
    _statusMessage = null;
    _languageStatus = {};
    notifyListeners();

    // Build language visibility map - show all selected languages, plus English if available
    final languageVisibility = <String, bool>{};
    final languagesToShow = <String>[];

    // Add selected languages
    for (final langCode in _selectedLanguages) {
      languageVisibility[langCode] = true;
      languagesToShow.add(langCode);
    }

    // If no languages selected, show all available languages (or at least English)
    if (_selectedLanguages.isEmpty) {
      // Show all languages that might have been created
      // The drawer will fetch and show what's available
      languageVisibility['en'] = true;
      languagesToShow.add('en');
    }

    return CreateConceptResult(
      success: true,
      conceptId: conceptId,
      languageVisibility: languageVisibility.isNotEmpty ? languageVisibility : null,
      languagesToShow: languagesToShow.isNotEmpty ? languagesToShow : null,
      warningMessage: warningMessage,
    );
  }

  /// Clear form after successful creation
  void clearForm() {
    _term = '';
    _description = '';
    _selectedImage = null;
    _selectedLanguages = [];
    // Keep the selected topic (don't reset it)
    notifyListeners();
  }

  /// Initialize the controller - load user, topics, and languages
  Future<void> initialize() async {
    await loadUserId();
    await Future.wait([
      loadTopics(),
      loadLanguages(),
    ]);
  }
}

