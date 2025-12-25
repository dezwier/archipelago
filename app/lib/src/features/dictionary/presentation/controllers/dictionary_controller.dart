import 'dart:async';
import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/user.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/common_widgets/filter_interface.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:archipelago/src/features/shared/domain/base_filter_state.dart';

enum SortOption {
  alphabetical,
  timeCreatedRecentFirst,
  random,
}
class DictionaryController extends ChangeNotifier with BaseFilterStateMixin implements FilterState {
  final AuthProvider _authProvider;
  List<PairedDictionaryItem> _pairedItems = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
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
  List<String> _visibleLanguageCodes = []; // Visible languages
  
  // Own lemmas filter state
  bool _ownLemmasFilter = false; // Filter for own user id cards
  
  // Lemmas/Phrases filter state
  bool _includeLemmas = false; // Include lemmas (is_phrase is false)
  bool _includePhrases = true; // Include phrases (is_phrase is true)
  
  // Include with filter state
  bool _hasImages = true; // Show concepts with images (default: true, means exclude missing images)
  bool _hasNoImages = true; // Show concepts without images
  bool _hasAudio = true; // Show concepts with audio (default: true, means exclude missing audio)
  bool _hasNoAudio = true; // Show concepts without audio
  bool _isComplete = true; // Show complete concepts (default: true, means exclude incomplete)
  bool _isIncomplete = true; // Show incomplete concepts
  
  // Topic, level, and POS filter state
  Set<int> _selectedTopicIds = {}; // Selected topic IDs (empty means all topics) - will be set to all topics when loaded
  Set<int>? _allAvailableTopicIds; // All available topic IDs (used to determine if all are selected)
  bool _showLemmasWithoutTopic = true; // Show concepts without a topic (topic_id is null) - default: true
  Set<String> _selectedLevels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'}; // Selected CEFR levels (default: all selected)
  Set<String> _selectedPartOfSpeech = {
    'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
    'Conjunction', 'Determiner / Article', 'Interjection', 'Numeral'
  }; // Selected part of speech values (default: all selected)
  Set<int> _selectedLeitnerBins = {}; // Will be populated with available bins
  Set<String> _selectedLearningStatus = {'new', 'due', 'learned'}; // All enabled by default
  
  // Concept counts - fetched separately and not affected by search
  int? _totalConceptCount; // Total count of all concepts (doesn't change during search)
  
  DictionaryController(this._authProvider) {
    // Listen to auth provider changes
    _authProvider.addListener(_onAuthChanged);
  }
  
  void _onAuthChanged() {
    // Update user-dependent state when auth changes
    _updateUserDependentState();
    notifyListeners();
  }
  
  void _updateUserDependentState() {
    final user = _authProvider.currentUser;
    if (user != null) {
      _sourceLanguageCode = user.langNative;
      _targetLanguageCode = user.langLearning;
      
      // Initialize all bins by default if empty
      if (_selectedLeitnerBins.isEmpty) {
        final maxBins = user.leitnerMaxBins ?? 7;
        _selectedLeitnerBins = Set<int>.from(List.generate(maxBins, (index) => index + 1));
      }
    } else {
      // When logged out, default to English
      _sourceLanguageCode = 'en';
      _targetLanguageCode = null;
    }
  }
  
  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    _descriptionPollingTimer?.cancel();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
  
  // Getters
  User? get currentUser => _authProvider.currentUser;
  List<PairedDictionaryItem> get pairedItems => _pairedItems;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
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
  List<String> get visibleLanguageCodes => _visibleLanguageCodes;
  int? get totalConceptCount => _totalConceptCount;
  
  // Own lemmas filter getter
  bool get ownLemmasFilter => _ownLemmasFilter;
  
  // Lemmas/Phrases filter getters
  bool get includeLemmas => _includeLemmas;
  bool get includePhrases => _includePhrases;
  
  // Include with filter getters
  bool get hasImages => _hasImages;
  bool get hasNoImages => _hasNoImages;
  bool get hasAudio => _hasAudio;
  bool get hasNoAudio => _hasNoAudio;
  bool get isComplete => _isComplete;
  bool get isIncomplete => _isIncomplete;
  
  // Topic, level, and POS filter getters
  Set<int> get selectedTopicIds => _selectedTopicIds;
  Set<int>? get allAvailableTopicIds => _allAvailableTopicIds;
  bool get showLemmasWithoutTopic => _showLemmasWithoutTopic;
  Set<String> get selectedLevels => _selectedLevels;
  Set<String> get selectedPartOfSpeech => _selectedPartOfSpeech;

  @override
  Set<int> get selectedLeitnerBins => _selectedLeitnerBins;

  @override
  Set<String> get selectedLearningStatus => _selectedLearningStatus;
  
  // Set language filter (used for limiting search only, not for filtering concepts)
  void setLanguageCodes(List<String> languageCodes) {
    // Compare by value, not by reference, to avoid infinite loops
    final currentSet = _languageCodes.toSet();
    final newSet = languageCodes.toSet();
    if (currentSet != newSet) {
      _languageCodes = languageCodes;
      // Only reload if there's a search query, otherwise just update the filter for future searches
      if (_searchQuery.trim().isNotEmpty) {
        _loadUserAndDictionary(reset: true, showLoading: false);
      }
    }
  }
  
  // Set visible languages
  void setVisibleLanguageCodes(List<String> visibleLanguageCodes) {
    // Compare by value, not by reference, to avoid infinite loops
    final currentSet = _visibleLanguageCodes.toSet();
    final newSet = visibleLanguageCodes.toSet();
    if (currentSet != newSet) {
      _visibleLanguageCodes = visibleLanguageCodes;
      // Always reload dictionary when visible languages change
      // This updates the cards shown
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
  
  // Set has images filter
  void setHasImages(bool has) {
    if (_hasImages != has) {
      _hasImages = has;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set has no images filter
  void setHasNoImages(bool has) {
    if (_hasNoImages != has) {
      _hasNoImages = has;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set has audio filter
  void setHasAudio(bool has) {
    if (_hasAudio != has) {
      _hasAudio = has;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set has no audio filter
  void setHasNoAudio(bool has) {
    if (_hasNoAudio != has) {
      _hasNoAudio = has;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set is complete filter
  void setIsComplete(bool isComplete) {
    if (_isComplete != isComplete) {
      _isComplete = isComplete;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // Set is incomplete filter
  void setIsIncomplete(bool isIncomplete) {
    if (_isIncomplete != isIncomplete) {
      _isIncomplete = isIncomplete;
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary when filter changes
      _loadUserAndDictionary(reset: true, showLoading: false);
    }
  }
  
  // getEffectiveHasImages, getEffectiveHasAudio, getEffectiveIsComplete are now provided by BaseFilterStateMixin
  
  // Batch update multiple filters at once (used when filter drawer closes)
  // This prevents multiple API calls when multiple filters change simultaneously
  void batchUpdateFilters({
    Set<int>? topicIds,
    bool? showLemmasWithoutTopic,
    Set<String>? levels,
    Set<String>? partOfSpeech,
    bool? includeLemmas,
    bool? includePhrases,
    bool? hasImages,
    bool? hasNoImages,
    bool? hasAudio,
    bool? hasNoAudio,
    bool? isComplete,
    bool? isIncomplete,
    Set<int>? leitnerBins,
    Set<String>? learningStatus,
  }) {
    bool hasChanges = false;
    
    if (topicIds != null && _selectedTopicIds != topicIds) {
      _selectedTopicIds = topicIds;
      hasChanges = true;
    }
    if (showLemmasWithoutTopic != null && _showLemmasWithoutTopic != showLemmasWithoutTopic) {
      _showLemmasWithoutTopic = showLemmasWithoutTopic;
      hasChanges = true;
    }
    if (levels != null && _selectedLevels != levels) {
      _selectedLevels = levels;
      hasChanges = true;
    }
    if (partOfSpeech != null && _selectedPartOfSpeech != partOfSpeech) {
      _selectedPartOfSpeech = partOfSpeech;
      hasChanges = true;
    }
    if (includeLemmas != null && _includeLemmas != includeLemmas) {
      _includeLemmas = includeLemmas;
      hasChanges = true;
    }
    if (includePhrases != null && _includePhrases != includePhrases) {
      _includePhrases = includePhrases;
      hasChanges = true;
    }
    if (hasImages != null && _hasImages != hasImages) {
      _hasImages = hasImages;
      hasChanges = true;
    }
    if (hasNoImages != null && _hasNoImages != hasNoImages) {
      _hasNoImages = hasNoImages;
      hasChanges = true;
    }
    if (hasAudio != null && _hasAudio != hasAudio) {
      _hasAudio = hasAudio;
      hasChanges = true;
    }
    if (hasNoAudio != null && _hasNoAudio != hasNoAudio) {
      _hasNoAudio = hasNoAudio;
      hasChanges = true;
    }
    if (isComplete != null && _isComplete != isComplete) {
      _isComplete = isComplete;
      hasChanges = true;
    }
    if (isIncomplete != null && _isIncomplete != isIncomplete) {
      _isIncomplete = isIncomplete;
      hasChanges = true;
    }
    if (leitnerBins != null && _selectedLeitnerBins != leitnerBins) {
      _selectedLeitnerBins = leitnerBins;
      hasChanges = true;
    }
    if (learningStatus != null && _selectedLearningStatus != learningStatus) {
      _selectedLearningStatus = learningStatus;
      hasChanges = true;
    }
    
    if (hasChanges) {
      notifyListeners(); // Notify listeners immediately for UI update
      // Reload dictionary once with all filter changes
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
    // Otherwise return the selected topic IDs (this is a filter - only show these topics)
    return _selectedTopicIds.toList();
  }
  
  // getEffectiveLevels and getEffectivePartOfSpeech are now provided by BaseFilterStateMixin

  List<int> _availableBins = []; // Available bins from Leitner distribution

  /// Set available bins from Leitner distribution
  void setAvailableBins(List<int> bins) {
    _availableBins = bins;
    // If selected bins is empty, initialize with all bins (1 to maxBins)
    if (_selectedLeitnerBins.isEmpty) {
      final maxBins = _authProvider.currentUser?.leitnerMaxBins ?? 7;
      _selectedLeitnerBins = Set<int>.from(List.generate(maxBins, (index) => index + 1));
    }
  }

  /// Get effective leitner_bins filter (comma-separated string, or null if all bins selected)
  /// Convenience method that gets maxBins from auth provider
  String? getEffectiveLeitnerBinsForUser() {
    final maxBins = _authProvider.currentUser?.leitnerMaxBins ?? 7;
    return getEffectiveLeitnerBins(maxBins);
  }

  // getEffectiveLearningStatus is now provided by BaseFilterStateMixin
  
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

  Future<void> _loadUserAndDictionary({bool reset = false, bool showLoading = true, bool isRefresh = false}) async {
    if (isRefresh) {
      _isRefreshing = true;
      _errorMessage = null;
      _currentPage = 1;
      notifyListeners();
    } else if (reset) {
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
      // Get user from auth provider
      final previousUserId = _authProvider.currentUser?.id;
      _updateUserDependentState();
      
      // Reload concept count if user state changed (login/logout)
      final currentUserId = _authProvider.currentUser?.id;
      if (previousUserId != currentUserId) {
        _loadConceptCountTotal();
      }

      // Load dictionary - pass visible languages to get cards for those languages only
      final result = await DictionaryService.getDictionary(
        userId: _authProvider.currentUser?.id,
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
        hasImages: getEffectiveHasImages(), // Pass has_images filter (1, 0, or null)
        hasAudio: getEffectiveHasAudio(), // Pass has_audio filter (1, 0, or null)
        isComplete: getEffectiveIsComplete(), // Pass is_complete filter (1, 0, or null)
        leitnerBins: getEffectiveLeitnerBinsForUser(), // Pass leitner_bins filter
        learningStatus: getEffectiveLearningStatus(), // Pass learning_status filter
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
        if (isRefresh) {
          _isRefreshing = false;
        } else if (showLoading) {
          _isLoading = false;
        }
        _errorMessage = null;
      } else {
        _errorMessage = result['message'] as String? ?? 'Failed to load dictionary';
        if (isRefresh) {
          _isRefreshing = false;
        } else if (showLoading) {
          _isLoading = false;
        }
      }
    } catch (e) {
      _errorMessage = 'Error loading dictionary: ${e.toString()}';
      if (isRefresh) {
        _isRefreshing = false;
      } else if (showLoading) {
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
        userId: _authProvider.currentUser?.id,
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
        hasImages: getEffectiveHasImages(), // Pass has_images filter (1, 0, or null)
        hasAudio: getEffectiveHasAudio(), // Pass has_audio filter (1, 0, or null)
        isComplete: getEffectiveIsComplete(), // Pass is_complete filter (1, 0, or null)
        leitnerBins: getEffectiveLeitnerBinsForUser(), // Pass leitner_bins filter
        learningStatus: getEffectiveLearningStatus(), // Pass learning_status filter
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

  Future<void> refresh() async {
    // Load concept count first to ensure it's updated on refresh
    await _loadConceptCountTotal();
    // Load user and dictionary (this will update user state and reload concept count if user changed)
    return _loadUserAndDictionary(reset: true, isRefresh: true);
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
      final result = await DictionaryService.getConceptCountTotal(userId: _authProvider.currentUser?.id);
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
    if (_isGeneratingDescriptions || _authProvider.currentUser == null) {
      return false;
    }

    _isGeneratingDescriptions = true;
    _descriptionStatus = null;
    _descriptionProgress = null;
    notifyListeners();

    try {
      final result = await DictionaryService.startGenerateDescriptions(
        userId: _authProvider.currentUser!.id,
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
        userId: _authProvider.currentUser?.id,
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
        hasImages: getEffectiveHasImages(), // Pass has_images filter (1, 0, or null)
        hasAudio: getEffectiveHasAudio(), // Pass has_audio filter (1, 0, or null)
        isComplete: getEffectiveIsComplete(), // Pass is_complete filter (1, 0, or null)
        leitnerBins: getEffectiveLeitnerBinsForUser(), // Pass leitner_bins filter
        learningStatus: getEffectiveLearningStatus(), // Pass learning_status filter
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

}

