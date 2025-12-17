import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';

enum SortOption {
  alphabetical,
  timeCreatedRecentFirst,
  random,
}
class DictionaryController extends ChangeNotifier {
  User? _currentUser;
  List<PairedDictionaryItem> _pairedItems = [];
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
  int? _conceptsWithAllVisibleLanguages; // Count of concepts with cards for all visible languages (with filters applied)
  
  // Own lemmas filter state
  bool _ownLemmasFilter = false; // Filter for own user id cards
  
  // Lemmas/Phrases filter state
  bool _includeLemmas = true; // Include lemmas (is_phrase is false)
  bool _includePhrases = true; // Include phrases (is_phrase is true)
  
  // Topic, level, and POS filter state
  Set<int> _selectedTopicIds = {}; // Selected topic IDs (empty means all topics) - will be set to all topics when loaded
  Set<int>? _allAvailableTopicIds; // All available topic IDs (used to determine if all are selected)
  bool _showLemmasWithoutTopic = true; // Show concepts without a topic (topic_id is null) - default: true
  Set<String> _selectedLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'}; // Selected CEFR levels (default: all selected)
  Set<String> _selectedPartOfSpeech = {
    'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
    'Conjunction', 'Determiner / Article', 'Interjection'
  }; // Selected part of speech values (default: all selected)
  
  // Concept counts - fetched separately and not affected by search
  int? _totalConceptCount; // Total count of all concepts (doesn't change during search)
  
  // Getters
  User? get currentUser => _currentUser;
  List<PairedDictionaryItem> get pairedItems => _pairedItems;
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
  
  // Lemmas/Phrases filter getters
  bool get includeLemmas => _includeLemmas;
  bool get includePhrases => _includePhrases;
  
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
        _loadUserAndDictionary(reset: true, showLoading: false);
      }
    }
  }
  
  // Set visible languages (used to calculate count of concepts with cards for all visible languages)
  void setVisibleLanguageCodes(List<String> visibleLanguageCodes) {
    if (_visibleLanguageCodes != visibleLanguageCodes) {
      _visibleLanguageCodes = visibleLanguageCodes;
      // Always reload dictionary when visible languages change
      // This updates the cards shown and recalculates the completed count with filters
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set lemmas filter
  void setIncludeLemmas(bool include) {
    if (_includeLemmas != include) {
      _includeLemmas = include;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set phrases filter
  void setIncludePhrases(bool include) {
    if (_includePhrases != include) {
      _includePhrases = include;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set topic filter
  void setTopicFilter(Set<int> topicIds) {
    if (_selectedTopicIds != topicIds) {
      _selectedTopicIds = topicIds;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set level filter
  void setLevelFilter(Set<String> levels) {
    if (_selectedLevels != levels) {
      _selectedLevels = levels;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set part of speech filter
  void setPartOfSpeechFilter(Set<String> partOfSpeech) {
    if (_selectedPartOfSpeech != partOfSpeech) {
      _selectedPartOfSpeech = partOfSpeech;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set show lemmas without topic filter
  void setShowLemmasWithoutTopic(bool show) {
    if (_showLemmasWithoutTopic != show) {
      _showLemmasWithoutTopic = show;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set all available topic IDs (called when topics are loaded)
  void setAllAvailableTopicIds(Set<int> topicIds) {
    _allAvailableTopicIds = topicIds;
  }
  
  // Get effective topic IDs to pass to API
  // Returns null if all topics are selected (no filter needed)
  List<int>? getEffectiveTopicIds() {
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
  List<String>? getEffectiveLevels() {
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
  List<String>? getEffectivePartOfSpeech() {
    const allPOS = {
      'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
      'Conjunction', 'Determiner / Article', 'Interjection'
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
  List<PairedDictionaryItem> get filteredItems {
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
            // Get lemma for the first visible language
            final aCard = a.getCardByLanguage(_alphabeticalSortLanguageCode!);
            final bCard = b.getCardByLanguage(_alphabeticalSortLanguageCode!);
            
            // Get translation text, fallback to empty string if lemma not found
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
      _loadUserAndDictionary(reset: true);
    }
  }

  Future<void> _loadUserAndDictionary({bool reset = false, bool showLoading = true}) async {
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
      final previousUserId = _currentUser?.id;
      
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
      
      // Reload concept count if user state changed (login/logout)
      if (previousUserId != _currentUser?.id) {
        _loadConceptCountTotal();
      }

      // Load dictionary - pass visible languages to get cards for those languages only
      // The dictionary endpoint will return the filtered completed count (with all filters applied)
      final result = await DictionaryService.getDictionary(
        userId: _currentUser?.id,
        page: 1,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        visibleLanguageCodes: _visibleLanguageCodes, // Pass visible languages to filter cards
        includeLemmas: _includeLemmas, // Pass lemmas filter
        includePhrases: _includePhrases, // Pass phrases filter
        topicIds: getEffectiveTopicIds(), // Pass topic filter (null if all topics selected)
        includeWithoutTopic: _showLemmasWithoutTopic, // Pass filter for concepts without topic
        levels: getEffectiveLevels(), // Pass level filter (null if all levels selected)
        partOfSpeech: getEffectivePartOfSpeech(), // Pass POS filter (null if all POS selected)
      );

      if (result['success'] == true) {
        final List<dynamic> itemsData = result['items'] as List<dynamic>;
        final items = itemsData
            .map((json) => PairedDictionaryItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _pairedItems = items;
        _applySorting();
        _currentPage = result['page'] as int;
        _totalItems = result['total'] as int;
        _hasNextPage = result['has_next'] as bool;
        // Update filtered completed count from dictionary endpoint (includes all filters)
        if (result['concepts_with_all_visible_languages'] != null) {
          _conceptsWithAllVisibleLanguages = result['concepts_with_all_visible_languages'] as int;
        }
        if (showLoading) {
          _isLoading = false;
        }
        _errorMessage = null;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to load dictionary';
        if (showLoading) {
          _isLoading = false;
        }
      }
    } catch (e) {
      _errorMessage = 'Error loading dictionary: ${e.toString()}';
      if (showLoading) {
        _isLoading = false;
      }
    }
    notifyListeners();
  }

  Future<void> loadMoreDictionary() async {
    if (_isLoadingMore || !_hasNextPage) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await DictionaryService.getDictionary(
        userId: _currentUser?.id,
        page: nextPage,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        visibleLanguageCodes: _visibleLanguageCodes, // Pass visible languages to filter cards
        includeLemmas: _includeLemmas, // Pass lemmas filter
        includePhrases: _includePhrases, // Pass phrases filter
        topicIds: getEffectiveTopicIds(), // Pass topic filter (null if all topics selected)
        includeWithoutTopic: _showLemmasWithoutTopic, // Pass filter for concepts without topic
        levels: getEffectiveLevels(), // Pass level filter (null if all levels selected)
        partOfSpeech: getEffectivePartOfSpeech(), // Pass POS filter (null if all POS selected)
      );

      if (result['success'] == true) {
        final List<dynamic> itemsData = result['items'] as List<dynamic>;
        final newItems = itemsData
            .map((json) => PairedDictionaryItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _pairedItems.addAll(newItems);
        _applySorting();
        _currentPage = result['page'] as int;
        _totalItems = result['total'] as int;
        _hasNextPage = result['has_next'] as bool;
        // Update filtered completed count from dictionary endpoint (includes all filters)
        if (result['concepts_with_all_visible_languages'] != null) {
          _conceptsWithAllVisibleLanguages = result['concepts_with_all_visible_languages'] as int;
        }
        _isLoadingMore = false;
      } else {
        _isLoadingMore = false;
        _errorMessage = result['message'] as String? ?? 'Failed to load more dictionary';
      }
    } catch (e) {
      _isLoadingMore = false;
      _errorMessage = 'Error loading more dictionary: ${e.toString()}';
    }
    notifyListeners();
  }

  Future<bool> deleteItem(PairedDictionaryItem item) async {
    try {
      final result = await DictionaryService.deleteConcept(
        conceptId: item.conceptId,
      );

      if (result['success'] == true) {
        // Reload dictionary to reflect deletion
        await _loadUserAndDictionary(reset: true);
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
    // Load user and dictionary first (this will update user state and reload concept count if user changed)
    // Filtered completed count will be loaded from dictionary endpoint
    return _loadUserAndDictionary(reset: true);
  }

  void initialize() {
    // Load concept counts separately (not affected by search)
    _loadConceptCountTotal();
    // Load dictionary
    _loadUserAndDictionary();
  }
  
  /// Load total concept count (doesn't change during search)
  Future<void> _loadConceptCountTotal() async {
    try {
      final result = await DictionaryService.getConceptCountTotal(userId: _currentUser?.id);
      if (result['success'] == true) {
        _totalConceptCount = result['count'] as int;
        notifyListeners();
      }
    } catch (e) {
      // Silently fail - don't show error for count
      print('Error loading total concept count: $e');
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
      final result = await DictionaryService.startGenerateDescriptions(
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
        final result = await DictionaryService.getDescriptionGenerationStatus(
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
            
            // Reload dictionary to show updated descriptions
            if (_descriptionStatus == 'completed') {
              await _loadUserAndDictionary(reset: true);
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
        // If search is cleared, reload all dictionary without showing loader
        _loadUserAndDictionary(reset: true, showLoading: false);
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
      final result = await DictionaryService.getDictionary(
        userId: _currentUser?.id,
        page: 1,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim(),
        visibleLanguageCodes: _visibleLanguageCodes, // Pass visible languages to filter cards
        includeLemmas: _includeLemmas, // Pass lemmas filter
        includePhrases: _includePhrases, // Pass phrases filter
        topicIds: getEffectiveTopicIds(), // Pass topic filter (null if all topics selected)
        includeWithoutTopic: _showLemmasWithoutTopic, // Pass filter for concepts without topic
        levels: getEffectiveLevels(), // Pass level filter (null if all levels selected)
        partOfSpeech: getEffectivePartOfSpeech(), // Pass POS filter (null if all POS selected)
      );
      
      if (result['success'] == true) {
        final List<dynamic> itemsData = result['items'] as List<dynamic>;
        final items = itemsData
            .map((json) => PairedDictionaryItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _pairedItems = items;
        _applySorting();
        _currentPage = result['page'] as int;
        _totalItems = result['total'] as int;
        _hasNextPage = result['has_next'] as bool;
        // Update filtered completed count from dictionary endpoint (includes all filters)
        if (result['concepts_with_all_visible_languages'] != null) {
          _conceptsWithAllVisibleLanguages = result['concepts_with_all_visible_languages'] as int;
        }
        _errorMessage = null;
      } else {
        // On error, keep previous items visible
        _errorMessage = result['message'] as String? ?? 'Failed to search dictionary';
      }
    } catch (e) {
      // On error, keep previous items visible
      _errorMessage = 'Error searching dictionary: ${e.toString()}';
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

