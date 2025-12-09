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
  SortOption _sortOption = SortOption.timeCreatedRecentFirst;
  String? _alphabeticalSortLanguageCode; // Language code to sort by when alphabetical is selected
  
  // Description generation state
  String? _descriptionTaskId;
  String? _descriptionStatus; // 'running', 'completed', 'cancelled', 'failed', 'cancelling'
  Map<String, dynamic>? _descriptionProgress;
  Timer? _descriptionPollingTimer;
  bool _isGeneratingDescriptions = false;
  
  // Search state
  String _searchQuery = '';
  List<String> _searchLanguageCodes = []; // Languages to search in
  Timer? _searchDebounceTimer;
  
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
  List<String> get searchLanguageCodes => _searchLanguageCodes;
  
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
    }
  }

  void _applySorting() {
    // Only apply client-side sorting for alphabetical sorts
    // Recent sort is handled server-side
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
      }

      // Load vocabulary
      if (_currentUser != null) {
        final result = await VocabularyService.getVocabulary(
          userId: _currentUser!.id,
          page: 1,
          pageSize: _pageSize,
          sortBy: _getSortByParameter(),
          search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
          searchLanguageCodes: _searchLanguageCodes,
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
      } else {
        _errorMessage = 'Please log in to view vocabulary';
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
    if (_isLoadingMore || !_hasNextPage || _currentUser == null) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final result = await VocabularyService.getVocabulary(
        userId: _currentUser!.id,
        page: nextPage,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
        searchLanguageCodes: _searchLanguageCodes,
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

      // Update first image if provided and changed
      if (imageUrl != null && imageUrl != item.imagePath1) {
        final result = await VocabularyService.updateConceptImage1(
          conceptId: item.conceptId,
          imageUrl: imageUrl,
        );
        
        if (result['success'] != true) {
          _errorMessage = result['message'] as String? ?? 'Failed to update image';
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

  Future<void> refresh() => _loadUserAndVocabulary(reset: true);

  void initialize() {
    _loadUserAndVocabulary();
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
  void setSearchQuery(String query, List<String> languageCodes) {
    if (_searchQuery != query || _searchLanguageCodes != languageCodes) {
      _searchQuery = query;
      _searchLanguageCodes = languageCodes;
      
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
    if (_currentUser == null) return;
    
    // Don't show loading indicator - keep old content visible
    _errorMessage = null;
    notifyListeners();
    
    try {
      final result = await VocabularyService.getVocabulary(
        userId: _currentUser!.id,
        page: 1,
        pageSize: _pageSize,
        sortBy: _getSortByParameter(),
        search: _searchQuery.trim(),
        searchLanguageCodes: _searchLanguageCodes,
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

