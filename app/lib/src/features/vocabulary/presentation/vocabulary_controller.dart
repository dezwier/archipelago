import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/profile/domain/user.dart';
import '../data/vocabulary_service.dart';
import '../domain/paired_vocabulary_item.dart';
import 'widgets/vocabulary_header_widget.dart';

class VocabularyController extends ChangeNotifier {
  User? _currentUser;
  List<PairedVocabularyItem> _pairedItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _sourceLanguageCode;
  String? _targetLanguageCode;
  
  // Pagination state
  int _currentPage = 1;
  int _totalItems = 0;
  bool _hasNextPage = false;
  static const int _pageSize = 20;
  
  // Sort state
  SortOption _sortOption = SortOption.alphabetical;
  String? _alphabeticalSortLanguageCode; // Language code to sort by when alphabetical is selected
  
  // Description generation state
  String? _descriptionTaskId;
  String? _descriptionStatus; // 'running', 'completed', 'cancelled', 'failed', 'cancelling'
  Map<String, dynamic>? _descriptionProgress;
  Timer? _descriptionPollingTimer;
  bool _isGeneratingDescriptions = false;
  
  // Search state
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  
  // Language filter state - used only for limiting search (does not filter which concepts are shown)
  List<String> _languageCodes = []; // Languages to limit search to (does not filter which concepts are shown)
  List<String> _visibleLanguageCodes = []; // Visible languages - used to calculate count of concepts with cards for all visible languages
  int? _conceptsWithAllVisibleLanguages; // Count of concepts with cards for all visible languages
  
  // Own lemmas filter state
  bool _ownLemmasFilter = false; // Filter for own user id cards
  
  // Public/Private filter state
  bool _includePublic = true; // Include public concepts (user_id is null)
  bool _includePrivate = true; // Include private concepts (user_id == logged in user)
  
  // Topic, level, and POS filter state
  Set<int> _selectedTopicIds = {}; // Selected topic IDs (empty means all topics) - will be set to all topics when loaded
  Set<int>? _allAvailableTopicIds; // All available topic IDs (used to determine if all are selected)
  bool _showLemmasWithoutTopic = true; // Show concepts without a topic (topic_id is null) - default: true
  Set<String> _selectedLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'}; // Selected CEFR levels (default: all selected)
  Set<String> _selectedPartOfSpeech = {
    'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
    'Conjunction', 'Determiner / Article', 'Interjection', 'Saying', 'Sentence'
  }; // Selected part of speech values (default: all selected)
  
  // Concept counts - fetched separately and not affected by search
  int? _totalConceptCount; // Total count of all concepts (doesn't change during search)
  
  // Getters
  User? get currentUser => _currentUser;
  List<PairedVocabularyItem> get pairedItems => _pairedItems;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  String? get sourceLanguageCode => _sourceLanguageCode;
  String? get targetLanguageCode => _targetLanguageCode;
  int get totalItems => _totalItems > 0 ? _totalItems : _pairedItems.length;
  SortOption get sortOption => _sortOption;
  bool get hasNextPage => _hasNextPage;
  
  // Description generation getters
  bool get isGeneratingDescriptions => _isGeneratingDescriptions;
  String? get descriptionStatus => _descriptionStatus;
  Map<String, dynamic>? get descriptionProgress => _descriptionProgress;
  String? get descriptionTaskId => _descriptionTaskId;
  
  // Search getters
  String get searchQuery => _searchQuery;
  
  // Language filter getters
  List<String> get languageCodes => _languageCodes;
  int? get conceptsWithAllVisibleLanguages => _conceptsWithAllVisibleLanguages;
  int? get totalConceptCount => _totalConceptCount;
  
  // Own lemmas filter getter
  bool get ownLemmasFilter => _ownLemmasFilter;
  
  // Public/Private filter getters
  bool get includePublic => _includePublic;
  bool get includePrivate => _includePrivate;
  
  // Topic, level, and POS filter getters
  Set<int> get selectedTopicIds => _selectedTopicIds;
  Set<int>? get allAvailableTopicIds => _allAvailableTopicIds;
  bool get showLemmasWithoutTopic => _showLemmasWithoutTopic;
  Set<String> get selectedLevels => _selectedLevels;
  Set<String> get selectedPartOfSpeech => _selectedPartOfSpeech;
  
  // Set language filter (used for limiting search only, not for filtering concepts)
  void setLanguageCodes(List<String> languageCodes) {
    if (_languageCodes != languageCodes) {
      _languageCodes = languageCodes;
      // Only reload if there's a search query, otherwise just update the filter for future searches
      if (_searchQuery.trim().isNotEmpty) {
        _loadUserAndVocabulary(reset: true, showLoading: false);
      }
    }
  }
  
  // Set visible languages (used to calculate count of concepts with cards for all visible languages)
  void setVisibleLanguageCodes(List<String> visibleLanguageCodes) {
    if (_visibleLanguageCodes != visibleLanguageCodes) {
      _visibleLanguageCodes = visibleLanguageCodes;
      // Reload count for visible languages (doesn't affect vocabulary items)
      _loadConceptCountWithCardsForLanguages();
      // Only reload vocabulary if there's a search query (to update search results)
      if (_searchQuery.trim().isNotEmpty) {
        _loadUserAndVocabulary(reset: true, showLoading: false);
      }
    }
  }
  
  // Set own lemmas filter
  void setOwnLemmasFilter(bool ownLemmas) {
    if (_ownLemmasFilter != ownLemmas) {
      _ownLemmasFilter = ownLemmas;
      // Reload vocabulary when filter changes
      _loadUserAndVocabulary(reset: true, showLoading: false);
    }
  }
  
  // Set public filter
  void setIncludePublic(bool include) {
    if (_includePublic != include) {
      _includePublic = include;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload vocabulary when filter changes
      _loadUserAndVocabulary(reset: true, showLoading: false);
    }
  }
  
  // Set private filter
  void setIncludePrivate(bool include) {
    if (_includePrivate != include) {
      _includePrivate = include;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload vocabulary when filter changes
      _loadUserAndVocabulary(reset: true, showLoading: false);
    }
  }
  
  // Set topic filter
  void setTopicFilter(Set<int> topicIds) {
    if (_selectedTopicIds != topicIds) {
      _selectedTopicIds = topicIds;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload vocabulary when filter changes
      _loadUserAndVocabulary(reset: true, showLoading: false);
    }
  }
  
  // Set level filter
  void setLevelFilter(Set<String> levels) {
    if (_selectedLevels != levels) {
      _selectedLevels = levels;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload vocabulary when filter changes
      _loadUserAndVocabulary(reset: true, showLoading: false);
    }
  }
  
  // Set part of speech filter
  void setPartOfSpeechFilter(Set<String> partOfSpeech) {
    if (_selectedPartOfSpeech != partOfSpeech) {
      _selectedPartOfSpeech = partOfSpeech;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload vocabulary when filter changes
      _loadUserAndVocabulary(reset: true, showLoading: false);
    }
  }
  
  // Set show lemmas without topic filter
  void setShowLemmasWithoutTopic(bool show) {
    if (_showLemmasWithoutTopic != show) {
      _showLemmasWithoutTopic = show;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload vocabulary when filter changes
      _loadUserAndVocabulary(reset: true, showLoading: false);
    }
  }
  
  // Set all available topic IDs (called when topics are loaded)
  void setAllAvailableTopicIds(Set<int> topicIds) {
    _allAvailableTopicIds = topicIds;
  }
  
  // Get effective topic IDs to pass to API
  // Returns null if all topics are selected (no filter needed)
  List<int>? _getEffectiveTopicIds() {
    // If no topics selected, return null (show all)
    if (_selectedTopicIds.isEmpty) {
      return null;
    }
    // If all available topics are selected, return null (show all, more efficient)
    // Only check this if we know what all available topics are
    if (_allAvailableTopicIds != null && 
        _allAvailableTopicIds!.isNotEmpty &&
        _selectedTopicIds.length == _allAvailableTopicIds!.length &&
        _selectedTopicIds.containsAll(_allAvailableTopicIds!) &&
        _allAvailableTopicIds!.containsAll(_selectedTopicIds)) {
      return null;
    }
    // Otherwise return the selected topic IDs
    return _selectedTopicIds.toList();
  }
  
  // Get effective levels to pass to API
  // Returns null if all levels are selected (no filter needed)
  List<String>? _getEffectiveLevels() {
    const allLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};
    // If all levels are selected, return null (show all)
    if (_selectedLevels.length == allLevels.length && 
        _selectedLevels.containsAll(allLevels)) {
      return null;
    }
    // If no levels selected, return null (show all)
    if (_selectedLevels.isEmpty) {
      return null;
    }
    // Otherwise return the selected levels
    return _selectedLevels.toList();
  }
  
  // Get effective part of speech values to pass to API
  // Returns null if all POS are selected (no filter needed)
  List<String>? _getEffectivePartOfSpeech() {
    const allPOS = {
      'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
      'Conjunction', 'Determiner / Article', 'Interjection', 'Saying', 'Sentence'
    };
    // If all POS are selected, return null (show all)
    if (_selectedPartOfSpeech.length == allPOS.length && 
        _selectedPartOfSpeech.containsAll(allPOS)) {
      return null;
    }
    // If no POS selected, return null (show all)
    if (_selectedPartOfSpeech.isEmpty) {
      return null;
    }
    // Otherwise return the selected POS
    return _selectedPartOfSpeech.toList();
  }
  
  // Filtered items - when searching, items are already filtered by API
  List<PairedVocabularyItem> get filteredItems {
    return _pairedItems;
  }

  String _getSortByParameter() {
    switch (_sortOption) {
      case SortOption.alphabetical:
        return 'alphabetical';
      case SortOption.timeCreatedRecentFirst:
        return 'recent';
      case SortOption.random:
        return 'random';
    }
  }

  void _applySorting() {
    // Only apply client-side sorting for alphabetical sorts
    // Recent and random sorts are handled server-side
    switch (_sortOption) {
      case SortOption.alphabetical:
        if (_alphabeticalSortLanguageCode != null) {
          _pairedItems.sort((a, b) {
            // Get card for the first visible language
            final aCard = a.getCardByLanguage(_alphabeticalSortLanguageCode!);
            final bCard = b.getCardByLanguage(_alphabeticalSortLanguageCode!);
            
            // Get translation text, fallback to empty string if card not found
            final aText = aCard?.translation.toLowerCase().trim() ?? '';
            final bText = bCard?.translation.toLowerCase().trim() ?? '';
            
            return aText.compareTo(bText);
          });
        }
        break;
      case SortOption.timeCreatedRecentFirst:
        // Server-side sorting - no client-side sorting needed
        break;
      case SortOption.random:
        // Server-side sorting - no client-side sorting needed
        break;
    }
    notifyListeners();
  }

  void setSortOption(SortOption option, {String? firstVisibleLanguage}) {
    if (_sortOption != option || 
        (option == SortOption.alphabetical && _alphabeticalSortLanguageCode != firstVisibleLanguage)) {
      _sortOption = option;
      if (option == SortOption.alphabetical) {
        _alphabeticalSortLanguageCode = firstVisibleLanguage;
      } else {
        _alphabeticalSortLanguageCode = null;
      }
      _loadUserAndVocabulary(reset: true);
    }
  }

  Future<void> _loadUserAndVocabulary({bool reset = false, bool showLoading = true}) async {
    if (reset) {
      if (showLoading) {
        _isLoading = true;
      }
      _errorMessage = null;
      _currentPage = 1;
      if (showLoading) {
        _pairedItems = [];
      }
      notifyListeners();
    } else {
      if (showLoading) {
        _isLoading = true;
      }
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // Load user data
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userMap);
        _sourceLanguageCode = _currentUser!.langNative;
        _targetLanguageCode = _currentUser!.langLearning;
      } else {
        // When logged out, default to English
        _currentUser = null;
        _sourceLanguageCode = 'en';
        _targetLanguageCode = null;
      }

      // Load concept count for visible languages if not already loaded or if languages changed
      if (_visibleLanguageCodes.isNotEmpty) {
        _loadConceptCountWithCardsForLanguages();
      }
      
      // Load vocabulary - pass visible languages to get cards for those languages only
      // Pass own_user_id when include_private is true (needed for filtering private concepts)
      // or when legacy _ownLemmasFilter is true
      final ownUserIdForApi = (_includePrivate && _currentUser != null) || 
                              (_ownLemmasFilter && _currentUser != null) 
                              ? _currentUser!.id 
                              : null;
      
      final result = await VocabularyService.getVocabulary(
        userId: _currentUser?.id,
        page: 1,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        visibleLanguageCodes: _visibleLanguageCodes, // Pass visible languages to filter cards
        ownUserId: ownUserIdForApi, // Pass own user id filter (for private concepts or legacy filter)
        includePublic: _includePublic, // Pass public filter
        includePrivate: _includePrivate, // Pass private filter
        topicIds: _getEffectiveTopicIds(), // Pass topic filter (null if all topics selected)
        includeWithoutTopic: _showLemmasWithoutTopic, // Pass filter for concepts without topic
        levels: _getEffectiveLevels(), // Pass level filter (null if all levels selected)
        partOfSpeech: _getEffectivePartOfSpeech(), // Pass POS filter (null if all POS selected)
      );

      if (result['success'] == true) {
        final List<dynamic> itemsData = result['items'] as List<dynamic>;
        final items = itemsData
            .map((json) => PairedVocabularyItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _pairedItems = items;
        _applySorting();
        _currentPage = result['page'] as int;
        _totalItems = result['total'] as int;
        _hasNextPage = result['has_next'] as bool;
        // Don't update counts from vocabulary endpoint - they're fetched separately
        if (showLoading) {
          _isLoading = false;
        }
        _errorMessage = null;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to load vocabulary';
        if (showLoading) {
          _isLoading = false;
        }
      }
    } catch (e) {
      _errorMessage = 'Error loading vocabulary: ${e.toString()}';
      if (showLoading) {
        _isLoading = false;
      }
    }
    notifyListeners();
  }

  Future<void> loadMoreVocabulary() async {
    if (_isLoadingMore || !_hasNextPage) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      // Pass own_user_id when include_private is true (needed for filtering private concepts)
      // or when legacy _ownLemmasFilter is true
      final ownUserIdForApi = (_includePrivate && _currentUser != null) || 
                              (_ownLemmasFilter && _currentUser != null) 
                              ? _currentUser!.id 
                              : null;
      
      final result = await VocabularyService.getVocabulary(
        userId: _currentUser?.id,
        page: nextPage,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        visibleLanguageCodes: _visibleLanguageCodes, // Pass visible languages to filter cards
        ownUserId: ownUserIdForApi, // Pass own user id filter (for private concepts or legacy filter)
        includePublic: _includePublic, // Pass public filter
        includePrivate: _includePrivate, // Pass private filter
        topicIds: _getEffectiveTopicIds(), // Pass topic filter (null if all topics selected)
        includeWithoutTopic: _showLemmasWithoutTopic, // Pass filter for concepts without topic
        levels: _getEffectiveLevels(), // Pass level filter (null if all levels selected)
        partOfSpeech: _getEffectivePartOfSpeech(), // Pass POS filter (null if all POS selected)
      );

      if (result['success'] == true) {
        final List<dynamic> itemsData = result['items'] as List<dynamic>;
        final newItems = itemsData
            .map((json) => PairedVocabularyItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _pairedItems.addAll(newItems);
        _applySorting();
        _currentPage = result['page'] as int;
        _totalItems = result['total'] as int;
        _hasNextPage = result['has_next'] as bool;
        _isLoadingMore = false;
      } else {
        _isLoadingMore = false;
        _errorMessage = result['message'] as String? ?? 'Failed to load more vocabulary';
      }
    } catch (e) {
      _isLoadingMore = false;
      _errorMessage = 'Error loading more vocabulary: ${e.toString()}';
    }
    notifyListeners();
  }

  Future<bool> updateItem(
    PairedVocabularyItem item,
    String? sourceTranslation,
    String? targetTranslation,
    String? imageUrl,
  ) async {
    try {
      // Update source card if it exists and translation changed
      if (item.sourceCard != null && 
          sourceTranslation != null && 
          sourceTranslation.isNotEmpty &&
          sourceTranslation != item.sourceCard!.translation) {
        final result = await VocabularyService.updateCard(
          cardId: item.sourceCard!.id,
          translation: sourceTranslation,
        );
        
        if (result['success'] != true) {
          _errorMessage = result['message'] as String? ?? 'Failed to update source card';
          notifyListeners();
          return false;
        }
      }

      // Update target card if it exists and translation changed
      if (item.targetCard != null && 
          targetTranslation != null && 
          targetTranslation.isNotEmpty &&
          targetTranslation != item.targetCard!.translation) {
        final result = await VocabularyService.updateCard(
          cardId: item.targetCard!.id,
          translation: targetTranslation,
        );
        
        if (result['success'] != true) {
          _errorMessage = result['message'] as String? ?? 'Failed to update target card';
          notifyListeners();
          return false;
        }
      }


      // Reload vocabulary to show updated data
      await _loadUserAndVocabulary(reset: true);
      return true;
    } catch (e) {
      _errorMessage = 'Error updating translation: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteItem(PairedVocabularyItem item) async {
    try {
      final result = await VocabularyService.deleteConcept(
        conceptId: item.conceptId,
      );

      if (result['success'] == true) {
        // Reload vocabulary to reflect deletion
        await _loadUserAndVocabulary(reset: true);
        return true;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to delete translation';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error deleting translation: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh() {
    // Reload concept counts when refreshing
    _loadConceptCountTotal();
    if (_visibleLanguageCodes.isNotEmpty) {
      _loadConceptCountWithCardsForLanguages();
    }
    return _loadUserAndVocabulary(reset: true);
  }

  void initialize() {
    // Load concept counts separately (not affected by search)
    _loadConceptCountTotal();
    // Load vocabulary
    _loadUserAndVocabulary();
  }
  
  /// Load total concept count (doesn't change during search)
  Future<void> _loadConceptCountTotal() async {
    try {
      final result = await VocabularyService.getConceptCountTotal();
      if (result['success'] == true) {
        _totalConceptCount = result['count'] as int;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - don't show error for count
      print('Error loading total concept count: $e');
    }
  }
  
  /// Load concept count with cards for all visible languages
  Future<void> _loadConceptCountWithCardsForLanguages() async {
    if (_visibleLanguageCodes.isEmpty) {
      _conceptsWithAllVisibleLanguages = null;
      notifyListeners();
      return;
    }
    
    try {
      final result = await VocabularyService.getConceptCountWithCardsForLanguages(
        languageCodes: _visibleLanguageCodes,
      );
      if (result['success'] == true) {
        _conceptsWithAllVisibleLanguages = result['count'] as int;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - don't show error for count
      print('Error loading concept count with cards for languages: $e');
    }
  }

  /// Start generating descriptions for cards that don't have them
  Future<bool> startGenerateDescriptions() async {
    if (_isGeneratingDescriptions || _currentUser == null) {
      return false;
    }

    _isGeneratingDescriptions = true;
    _descriptionStatus = null;
    _descriptionProgress = null;
    notifyListeners();

    try {
      final result = await VocabularyService.startGenerateDescriptions(
        userId: _currentUser!.id,
      );

      if (result['success'] == true) {
        _descriptionTaskId = result['task_id'] as String;
        _descriptionStatus = 'running';
        _descriptionProgress = {
          'total_concepts': result['total_concepts'] as int,
          'processed': 0,
          'cards_updated': 0,
        };
        
        // Start polling for status
        _startPollingStatus();
        notifyListeners();
        return true;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to start description generation';
        _isGeneratingDescriptions = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error starting description generation: ${e.toString()}';
      _isGeneratingDescriptions = false;
      notifyListeners();
      return false;
    }
  }

  /// Start polling for task status
  void _startPollingStatus() {
    _descriptionPollingTimer?.cancel();
    _descriptionPollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_descriptionTaskId == null) {
        timer.cancel();
        return;
      }

      try {
        final result = await VocabularyService.getDescriptionGenerationStatus(
          taskId: _descriptionTaskId!,
        );

        if (result['success'] == true) {
          _descriptionStatus = result['status'] as String;
          _descriptionProgress = result['progress'] as Map<String, dynamic>;

          // Check if task is complete, cancelled, or failed
          if (_descriptionStatus == 'completed' || 
              _descriptionStatus == 'cancelled' || 
              _descriptionStatus == 'failed') {
            timer.cancel();
            _isGeneratingDescriptions = false;
            
            // Reload vocabulary to show updated descriptions
            if (_descriptionStatus == 'completed') {
              await _loadUserAndVocabulary(reset: true);
            }
          }
          notifyListeners();
        } else {
          // If we can't get status, assume task failed
          timer.cancel();
          _isGeneratingDescriptions = false;
          _descriptionStatus = 'failed';
          _errorMessage = result['message'] as String? ?? 'Failed to get task status';
          notifyListeners();
        }
      } catch (e) {
        // Continue polling on error, but log it
        print('Error polling task status: $e');
      }
    });
  }

  // Search methods
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      
      // Cancel previous debounce timer
      _searchDebounceTimer?.cancel();
      
      // Debounce search API calls (wait 300ms after user stops typing)
      if (query.trim().isEmpty) {
        // If search is cleared, reload all vocabulary without showing loader
        _loadUserAndVocabulary(reset: true, showLoading: false);
      } else {
        _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
          _performSearch();
        });
      }
      
      notifyListeners();
    }
  }
  
  Future<void> _performSearch() async {
    // Don't show loading indicator - keep old content visible
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Pass own_user_id when include_private is true (needed for filtering private concepts)
      // or when legacy _ownLemmasFilter is true
      final ownUserIdForApi = (_includePrivate && _currentUser != null) || 
                              (_ownLemmasFilter && _currentUser != null) 
                              ? _currentUser!.id 
                              : null;
      
      final result = await VocabularyService.getVocabulary(
        userId: _currentUser?.id,
        page: 1,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim(),
        visibleLanguageCodes: _visibleLanguageCodes, // Pass visible languages to filter cards
        ownUserId: ownUserIdForApi, // Pass own user id filter (for private concepts or legacy filter)
        includePublic: _includePublic, // Pass public filter
        includePrivate: _includePrivate, // Pass private filter
        topicIds: _getEffectiveTopicIds(), // Pass topic filter (null if all topics selected)
        includeWithoutTopic: _showLemmasWithoutTopic, // Pass filter for concepts without topic
        levels: _getEffectiveLevels(), // Pass level filter (null if all levels selected)
        partOfSpeech: _getEffectivePartOfSpeech(), // Pass POS filter (null if all POS selected)
      );
      
      if (result['success'] == true) {
        final List<dynamic> itemsData = result['items'] as List<dynamic>;
        final items = itemsData
            .map((json) => PairedVocabularyItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _pairedItems = items;
        _applySorting();
        _currentPage = result['page'] as int;
        _totalItems = result['total'] as int;
        _hasNextPage = result['has_next'] as bool;
        // Don't update counts from vocabulary endpoint - they're fetched separately
        _errorMessage = null;
      } else {
        // On error, keep previous items visible
        _errorMessage = result['message'] as String? ?? 'Failed to search vocabulary';
      }
    } catch (e) {
      // On error, keep previous items visible
      _errorMessage = 'Error searching vocabulary: ${e.toString()}';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _descriptionPollingTimer?.cancel();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}

