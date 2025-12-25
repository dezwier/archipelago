import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/create/data/flashcard_service.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/domain/user.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';
import 'package:archipelago/src/features/shared/providers/languages_provider.dart';

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
  final AuthProvider _authProvider;
  final TopicsProvider _topicsProvider;
  final LanguagesProvider _languagesProvider;
  
  // Form state
  String _term = '';
  String _description = '';
  List<Topic> _selectedTopics = [];
  List<String> _selectedLanguages = [];
  File? _selectedImage;

  // Loading states
  bool _isCreatingConcept = false;

  // Status messages
  String? _statusMessage;
  Map<String, bool> _languageStatus = {}; // Track which languages have completed

  // Data
  bool _hasSetDefaultLanguages = false;
  
  CreateConceptController(
    this._authProvider,
    this._topicsProvider,
    this._languagesProvider,
  ) {
    // Listen to auth provider changes
    _authProvider.addListener(_onAuthChanged);
    // Listen to providers to update local state
    _topicsProvider.addListener(_onTopicsChanged);
    _languagesProvider.addListener(_onLanguagesChanged);
    // Load initial data
    _updateTopics();
    _updateLanguages();
  }
  
  void _onAuthChanged() {
    // Update default languages when auth changes
    _setDefaultLanguages();
    notifyListeners();
  }
  
  void _onTopicsChanged() {
    _updateTopics();
  }
  
  void _onLanguagesChanged() {
    _updateLanguages();
  }
  
  void _updateTopics() {
    final topics = _topicsProvider.topics;
    // Remove selected topics that are no longer in the available topics (e.g., private topic after logout)
    _selectedTopics.removeWhere((selected) => !topics.any((t) => t.id == selected.id));
    notifyListeners();
  }
  
  void _updateLanguages() {
    _setDefaultLanguages();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _topicsProvider.removeListener(_onTopicsChanged);
    _languagesProvider.removeListener(_onLanguagesChanged);
    super.dispose();
  }

  // Getters
  String get term => _term;
  String get description => _description;
  List<Topic> get selectedTopics => _selectedTopics;
  List<String> get selectedLanguages => _selectedLanguages;
  File? get selectedImage => _selectedImage;
  bool get isCreatingConcept => _isCreatingConcept;
  bool get isLoadingTopics => _topicsProvider.isLoading;
  bool get isLoadingLanguages => _languagesProvider.isLoading;
  String? get statusMessage => _statusMessage;
  List<Topic> get topics => _topicsProvider.topics;
  List<Language> get languages => _languagesProvider.languages;
  Map<String, bool> get languageStatus => _languageStatus;
  int? get userId => _authProvider.currentUser?.id;
  User? get currentUser => _authProvider.currentUser;

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
    // Add topic if not already selected, remove if already selected (toggle)
    if (topic != null) {
      if (_selectedTopics.any((t) => t.id == topic.id)) {
        _selectedTopics.removeWhere((t) => t.id == topic.id);
      } else {
        _selectedTopics.add(topic);
      }
      notifyListeners();
    }
  }
  
  void setSelectedTopics(List<Topic> topics) {
    _selectedTopics = List.from(topics);
    notifyListeners();
  }
  
  void removeSelectedTopic(Topic topic) {
    _selectedTopics.removeWhere((t) => t.id == topic.id);
    notifyListeners();
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


  /// Refresh topics from provider
  Future<void> loadTopics() async {
    await _topicsProvider.refresh();
  }

  /// Refresh languages from provider
  Future<void> loadLanguages() async {
    await _languagesProvider.refresh();
  }

  /// Set default languages based on user's native and learning languages
  void _setDefaultLanguages() {
    final currentUser = _authProvider.currentUser;
    final languages = _languagesProvider.languages;
    // Only set defaults once, and only if we have both user and languages loaded
    if (_hasSetDefaultLanguages || currentUser == null || languages.isEmpty) {
      return;
    }

    final defaultLanguages = <String>[];

    // Add native language if it exists in available languages
    if (currentUser.langNative.isNotEmpty) {
      final nativeLangExists = languages.any((lang) => lang.code == currentUser.langNative);
      if (nativeLangExists) {
        defaultLanguages.add(currentUser.langNative);
      }
    }

    // Add learning language if it exists in available languages
    if (currentUser.langLearning != null && currentUser.langLearning!.isNotEmpty) {
      final learningLangExists = languages.any((lang) => lang.code == currentUser.langLearning);
      if (learningLangExists) {
        defaultLanguages.add(currentUser.langLearning!);
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
    final userId = _authProvider.currentUser?.id;
    if (userId == null) {
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
    final topicIds = _selectedTopics.map((t) => t.id).toList();
    final createResult = await FlashcardService.createConceptOnly(
      term: term,
      description: _description.trim().isNotEmpty ? _description.trim() : null,
      topicIds: topicIds.isNotEmpty ? topicIds : null,
      userId: userId,
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
    // Keep the selected topics (don't reset them)
    notifyListeners();
  }

  /// Initialize the controller - load topics and languages
  Future<void> initialize() async {
    await Future.wait([
      loadTopics(),
      loadLanguages(),
    ]);
  }
}

