import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_item_widget.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_empty_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_error_state.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_delete.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_drawer.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_filter_sheet.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_search_bar.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_fab_buttons.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_empty_search_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/export_flashcards_drawer.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/card_generation_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/visibility_options_sheet.dart';
import 'package:archipelago/src/features/dictionary/presentation/screens/edit_concept_screen.dart';
import 'package:archipelago/src/features/profile/data/language_service.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/create/data/flashcard_service.dart';
import 'package:archipelago/src/features/create/data/card_generation_background_service.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/generate_lemmas_drawer.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  late final DictionaryController _controller;
  late final CardGenerationState _cardGenerationState;
  late final LanguageVisibilityManager _languageVisibilityManager;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Filter state
  bool _showDescription = true;
  bool _showExtraInfo = true;
  List<Language> _allLanguages = [];
  List<Topic> _allTopics = [];
  bool _isLoadingTopics = false;
  bool _isLoadingConcepts = false; // Loading state for the button
  bool _isLoadingExport = false; // Loading state for export

  @override
  void initState() {
    super.initState();
    _controller = DictionaryController();
    _cardGenerationState = CardGenerationState();
    _languageVisibilityManager = LanguageVisibilityManager();
    _controller.initialize();
    _scrollController.addListener(_onScroll);
    _loadLanguages();
    _loadTopics();
    
    // Listen to controller changes to update language visibility when user loads
    _controller.addListener(_onControllerChanged);
    
    // Listen to lemma generation state changes
    _cardGenerationState.addListener(() {
      if (mounted) setState(() {});
    });
    
    // Load existing task state and start polling
    _cardGenerationState.loadExistingTaskState().then((_) {
      _cardGenerationState.startProgressPolling(_onCardGenerationComplete);
    });
    
    // Prevent search field from requesting focus automatically
    // It can only get focus when user explicitly taps it
    _searchFocusNode.canRequestFocus = false;
    
    // Reset canRequestFocus when focus is lost, but with a delay
    // to allow the TextField to properly handle the unfocus
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        // Delay reset to allow TextField to complete its unfocus handling
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_searchFocusNode.hasFocus) {
            _searchFocusNode.canRequestFocus = false;
          }
        });
      }
    });
  }

  void _onControllerChanged() {
    // Update language visibility defaults when user data is loaded
    if (_controller.currentUser != null && _allLanguages.isNotEmpty) {
      final sourceCode = _controller.sourceLanguageCode;
      final targetCode = _controller.targetLanguageCode;
      
      // Only update if languages list is empty (initial state)
      if (_languageVisibilityManager.languagesToShow.isEmpty) {
        _languageVisibilityManager.initializeForLoggedInUser(
          _allLanguages,
          sourceCode,
          targetCode,
        );
        setState(() {});
        // Set language filter to visible languages (for search only)
        _controller.setLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
        // Set visible languages for count calculation
        _controller.setVisibleLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
      }
    } else if (_controller.currentUser == null && _allLanguages.isNotEmpty) {
      // When logged out, default to English only
      if (_languageVisibilityManager.languagesToShow.isEmpty) {
        _languageVisibilityManager.initializeForLoggedOutUser(_allLanguages);
        setState(() {});
        // Set language filter to visible languages (for search only)
        _controller.setLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
        // Set visible languages for count calculation
        _controller.setVisibleLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
      }
    }
  }

  Future<void> _loadLanguages() async {
    final languages = await LanguageService.getLanguages();
    
    setState(() {
      _allLanguages = languages;
      // Initialize visibility - default to English if logged out
      if (_controller.currentUser == null) {
        _languageVisibilityManager.initializeForLoggedOutUser(languages);
      }
    });
    
    // Update defaults based on user state
    _onControllerChanged();
    
    // Set language filter after visibility is initialized (for search only)
    if (_languageVisibilityManager.languagesToShow.isNotEmpty) {
      _controller.setLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
      // Set visible languages for count calculation
      _controller.setVisibleLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
    }
  }
  
  Future<void> _loadTopics() async {
    setState(() {
      _isLoadingTopics = true;
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
        _allTopics = topics;
        _isLoadingTopics = false;
        // Set all available topic IDs in controller first
        final topicIds = topics.map((t) => t.id).toSet();
        _controller.setAllAvailableTopicIds(topicIds);
        // Set all topics as selected by default
        if (topics.isNotEmpty && _controller.selectedTopicIds.isEmpty) {
          _controller.setTopicFilter(topicIds);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingTopics = false;
      });
    }
  }
  

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _cardGenerationState.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  void _onCardGenerationComplete() {
    // Refresh dictionary to show new cards
    _controller.refresh();
    _cardGenerationState.clearCurrentConcept();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      _controller.loadMoreDictionary();
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (_controller.errorMessage != null) {
          return Scaffold(
            body: DictionaryErrorState(
              errorMessage: _controller.errorMessage!,
              onRetry: _controller.refresh,
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          body: GestureDetector(
            onTap: () {
              // Dismiss keyboard when tapping outside text fields
              FocusScope.of(context).unfocus();
            },
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _controller.refresh,
                  child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Concept count at top of cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
                    child: Text(
                      _buildPhraseCountText(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                // Paired dictionary items
                if (_controller.filteredItems.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _controller.filteredItems[index];
                        return DictionaryItemWidget(
                          item: item,
                          sourceLanguageCode: _controller.sourceLanguageCode,
                          targetLanguageCode: _controller.targetLanguageCode,
                          languageVisibility: _languageVisibilityManager.languageVisibility,
                          languagesToShow: _languageVisibilityManager.languagesToShow,
                          showDescription: _showDescription,
                          showExtraInfo: _showExtraInfo,
                          allItems: _controller.filteredItems,
                          onTap: () => _handleItemTap(item),
                        );
                      },
                      childCount: _controller.filteredItems.length,
                    ),
                  ),
                // Empty state
                if (_controller.filteredItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _controller.searchQuery.isNotEmpty
                        ? const DictionaryEmptySearchState()
                        : const DictionaryEmptyState(),
                  ),
                // Loading more indicator
                if (_controller.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                // Bottom padding for search bar
                SliverToBoxAdapter(
                  child: SizedBox(height: 80 + MediaQuery.of(context).padding.bottom),
                ),
              ],
                  ),
                ),
              // Fixed bottom search bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DictionarySearchBar(
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  searchQuery: _controller.searchQuery,
                  onSearchChanged: (value) => _controller.setSearchQuery(value),
                  onClear: () {
                    _searchController.clear();
                    _controller.setSearchQuery('');
                  },
                ),
              ),
              // FAB buttons positioned above search bar
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 70,
                child: DictionaryFabButtons(
                  filterButtonKey: _filterButtonKey,
                  onFilterPressed: () => _showFilterMenu(context),
                  onFilteringPressed: () => _showFilteringMenu(context),
                  onGenerateLemmasPressed: () => _showGenerateLemmasDrawer(context),
                  onExportPressed: () => _showExportDrawer(context),
                  isLoadingConcepts: _isLoadingConcepts,
                  isLoadingExport: _isLoadingExport,
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  String _buildPhraseCountText() {
    // Always show total concepts count (doesn't change during search)
    final totalConcepts = _controller.totalConceptCount ?? 0;
    
    // Get filtered count (number of concepts with filters applied)
    final filteredLemmas = _controller.totalItems;
    
    // Get completed count (includes filters AND considers which visible languages are complete)
    final completedCount = _controller.conceptsWithAllVisibleLanguages ?? 0;
    
    return '$totalConcepts ${totalConcepts == 1 ? 'concept' : 'concepts'} • $filteredLemmas filtered • $completedCount completed';
  }


  void _showFilteringMenu(BuildContext context) {
    showDictionaryFilterSheet(
      context: context,
      controller: _controller,
      topics: _allTopics,
      isLoadingTopics: _isLoadingTopics,
    );
  }

  Future<void> _showExportDrawer(BuildContext context) async {
    if (_isLoadingExport) return; // Prevent multiple simultaneous exports
    
    setState(() {
      _isLoadingExport = true;
    });
    
    try {
      final completedCount = _controller.conceptsWithAllVisibleLanguages ?? 0;
      final visibleLanguageCodes = _languageVisibilityManager.getVisibleLanguageCodes();
      
      print('🔵 [Export] Starting export - completedCount: $completedCount, visibleLanguages: $visibleLanguageCodes');
      
      // Fetch ALL concept IDs that match the current filters (not just visible ones)
      // Use the EXACT same parameters as the controller uses
      // Loop through all pages to get all results
      
      final Set<int> conceptIdSet = {};
      int currentPage = 1;
      bool hasMorePages = true;
      int totalPagesFetched = 0;
      
      // Use the same helper methods as the controller
      final effectiveTopicIds = _controller.getEffectiveTopicIds();
      final effectiveLevels = _controller.getEffectiveLevels();
      final effectivePartOfSpeech = _controller.getEffectivePartOfSpeech();
      
      print('🔵 [Export] Starting to fetch pages with filters...');
      print('🔵 [Export] Using same parameters as controller:');
      print('  - userId: ${_controller.currentUser?.id}');
      print('  - visibleLanguageCodes: $visibleLanguageCodes');
      print('  - includeLemmas: ${_controller.includeLemmas}');
      print('  - includePhrases: ${_controller.includePhrases}');
      print('  - search: ${_controller.searchQuery.trim().isNotEmpty ? _controller.searchQuery.trim() : null}');
      print('  - topicIds: $effectiveTopicIds');
      print('  - includeWithoutTopic: ${_controller.showLemmasWithoutTopic}');
      print('  - levels: $effectiveLevels');
      print('  - partOfSpeech: $effectivePartOfSpeech');
      
      while (hasMorePages) {
        print('🔵 [Export] Fetching page $currentPage...');
        final result = await DictionaryService.getDictionary(
          userId: _controller.currentUser?.id,
          page: currentPage,
          pageSize: 100, // Maximum allowed page size
          sortBy: _controller.sortOption == SortOption.alphabetical 
              ? 'alphabetical' 
              : (_controller.sortOption == SortOption.timeCreatedRecentFirst ? 'recent' : 'random'),
          search: _controller.searchQuery.trim().isNotEmpty ? _controller.searchQuery.trim() : null,
          visibleLanguageCodes: visibleLanguageCodes,
          includeLemmas: _controller.includeLemmas,
          includePhrases: _controller.includePhrases,
          topicIds: effectiveTopicIds, // Use helper method
          includeWithoutTopic: _controller.showLemmasWithoutTopic,
          levels: effectiveLevels, // Use helper method
          partOfSpeech: effectivePartOfSpeech, // Use helper method
        );
        
        print('🔵 [Export] Page $currentPage result - success: ${result['success']}, items: ${(result['items'] as List?)?.length ?? 0}');
        
        if (result['success'] == true) {
          final List<dynamic> itemsData = result['items'] as List<dynamic>;
          print('🔵 [Export] Page $currentPage has ${itemsData.length} items');
          
          // Extract unique concept IDs from items
          for (final item in itemsData) {
            final conceptId = (item as Map<String, dynamic>)['concept_id'] as int?;
            if (conceptId != null) {
              conceptIdSet.add(conceptId);
            }
          }
          
          print('🔵 [Export] Total unique concept IDs so far: ${conceptIdSet.length}');
          
          // Check if there are more pages
          hasMorePages = result['has_next'] as bool? ?? false;
          totalPagesFetched++;
          currentPage++;
          
          print('🔵 [Export] Has more pages: $hasMorePages');
        } else {
          // Error occurred, break the loop
          final errorMsg = result['message'] as String? ?? 'Failed to load concepts for export';
          print('🔴 [Export] Error on page $currentPage: $errorMsg');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        }
      }
      
      print('🔵 [Export] Finished fetching. Total pages: $totalPagesFetched, Total concept IDs: ${conceptIdSet.length}');
      
      if (!context.mounted) {
        print('🔴 [Export] Context not mounted, cannot show drawer');
        return;
      }
      
      if (conceptIdSet.isEmpty) {
        print('🔴 [Export] No concept IDs found!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No concepts found to export with current filters'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final conceptIds = conceptIdSet.toList();
      print('🔵 [Export] Opening export drawer with ${conceptIds.length} concept IDs');
      
      showExportFlashcardsDrawer(
        context: context,
        conceptIds: conceptIds,
        completedConceptsCount: completedCount,
        availableLanguages: _allLanguages,
        visibleLanguageCodes: visibleLanguageCodes,
      );
      
      print('🔵 [Export] Export drawer opened successfully');
    } catch (e, stackTrace) {
      print('🔴 [Export] Exception occurred: $e');
      print('🔴 [Export] Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading concepts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExport = false;
        });
        print('🔵 [Export] Loading state reset');
      }
    }
  }

  void _showFilterMenu(BuildContext context) {
    // Get the first visible language for alphabetical sorting
    final firstVisibleLanguage = _languageVisibilityManager.languagesToShow.isNotEmpty 
        ? _languageVisibilityManager.languagesToShow.first 
        : null;
    showVisibilityOptionsSheet(
      context: context,
      allLanguages: _allLanguages,
      languageVisibility: _languageVisibilityManager.languageVisibility,
      showDescription: _showDescription,
      showExtraInfo: _showExtraInfo,
      controller: _controller,
      firstVisibleLanguage: firstVisibleLanguage,
      onLanguageVisibilityToggled: (languageCode) {
        setState(() {
          _languageVisibilityManager.toggleLanguageVisibility(languageCode);
          // Update language filter for search (concepts are no longer filtered by visibility)
          _controller.setLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
          // Update visible languages - this will refresh dictionary and counts
          _controller.setVisibleLanguageCodes(_languageVisibilityManager.getVisibleLanguageCodes());
        });
      },
      onShowDescriptionChanged: (value) {
        setState(() {
          _showDescription = value;
        });
      },
      onShowExtraInfoChanged: (value) {
        setState(() {
          _showExtraInfo = value;
        });
      },
    );
  }

  Future<void> _handleEdit(PairedDictionaryItem item) async {
    // Navigate to edit concept screen
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditConceptScreen(item: item),
      ),
    );

    if (result == true && mounted) {
      // Refresh the dictionary list to show updated concept
      await _controller.refresh();
      
      // Refresh the detail drawer if it's still open
      // Find the updated item in the list
      final updatedItems = _controller.filteredItems;
      final updatedItem = updatedItems.firstWhere(
        (i) => i.conceptId == item.conceptId,
        orElse: () => item,
      );
      
      // Close current drawer and reopen with updated item
      if (mounted) {
        Navigator.of(context).pop(); // Close current drawer
        _handleItemTap(updatedItem); // Reopen with updated item
      }
    }
  }

  Future<void> _handleDelete(PairedDictionaryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDictionaryDialog(),
    );

    if (confirmed == true && mounted) {
      final success = await _controller.deleteItem(item);

      if (mounted) {
        // Close the detail drawer if deletion was successful
        if (success) {
          Navigator.of(context).pop();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Translation deleted successfully'
                  : _controller.errorMessage ?? 'Failed to delete translation',
            ),
            backgroundColor: success
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleItemTap(PairedDictionaryItem item) {
    showConceptDrawer(
      context,
      conceptId: item.conceptId,
      languageVisibility: _languageVisibilityManager.languageVisibility,
      languagesToShow: _languageVisibilityManager.languagesToShow,
      onEdit: () => _handleEdit(item),
      onDelete: () => _handleDelete(item),
      onItemUpdated: () => _handleItemUpdated(context, item),
    );
  }

  Future<void> _handleItemUpdated(BuildContext context, PairedDictionaryItem item) async {
    // Refresh the dictionary list to get updated item
    await _controller.refresh();
    
    // The drawer will reload the concept data itself via its onItemUpdated callback
    // No need to close and reopen - the drawer handles its own refresh
  }

  void _showGenerateLemmasDrawer(BuildContext context) {
    final visibleLanguages = _languageVisibilityManager.getVisibleLanguageCodes();
    
    if (visibleLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one visible language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showGenerateLemmasDrawer(
      context: context,
      cardGenerationState: _cardGenerationState,
      onConfirmGenerate: () => _handleGenerateLemmas(context),
      visibleLanguageCodes: visibleLanguages,
    );
  }

  Future<void> _handleGenerateLemmas(BuildContext context) async {
    // Get visible languages
    final visibleLanguages = _languageVisibilityManager.getVisibleLanguageCodes();
    
    if (visibleLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one visible language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Set loading state
    setState(() {
      _isLoadingConcepts = true;
    });
    
    try {
      // Get effective filters (same logic as controller)
      final effectiveLevels = _controller.getEffectiveLevels();
      final effectivePOS = _controller.getEffectivePartOfSpeech();
      final effectiveTopicIds = _controller.getEffectiveTopicIds();
      
      // Get concepts with missing languages for visible languages
      // All filtering is now done API-side
      final missingResult = await FlashcardService.getConceptsWithMissingLanguages(
        languages: visibleLanguages,
        levels: effectiveLevels,
        partOfSpeech: effectivePOS,
        topicIds: effectiveTopicIds,
        includeWithoutTopic: _controller.showLemmasWithoutTopic,
        includeLemmas: _controller.includeLemmas,
        includePhrases: _controller.includePhrases,
        search: _controller.searchQuery.trim().isNotEmpty ? _controller.searchQuery.trim() : null,
      );
      
      if (missingResult['success'] != true) {
        setState(() {
          _isLoadingConcepts = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(missingResult['message'] as String),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final missingData = missingResult['data'] as Map<String, dynamic>?;
      final concepts = missingData?['concepts'] as List<dynamic>?;
      
      if (concepts == null || concepts.isEmpty) {
        setState(() {
          _isLoadingConcepts = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No concepts found that need cards for the visible languages'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }
      
      // All filtering is done API-side, so use concepts directly
      // Extract concept IDs, terms, and missing languages
      final conceptIds = <int>[];
      final conceptTerms = <int, String>{};
      final conceptMissingLanguages = <int, List<String>>{};
      
      for (final c in concepts) {
        final conceptData = c as Map<String, dynamic>;
        final concept = conceptData['concept'] as Map<String, dynamic>;
        final conceptId = concept['id'] as int;
        final conceptTerm = concept['term'] as String? ?? 'Unknown';
        final missingLanguages = (conceptData['missing_languages'] as List<dynamic>?)
            ?.map((lang) => lang.toString().toUpperCase())
            .toList() ?? [];
        conceptIds.add(conceptId);
        conceptTerms[conceptId] = conceptTerm;
        conceptMissingLanguages[conceptId] = missingLanguages;
      }
      
      // Set initial progress state
      setState(() {
        _isLoadingConcepts = false;
      });
      
      _cardGenerationState.startGeneration(
        totalConcepts: conceptIds.length,
        conceptIds: conceptIds,
        conceptTerms: conceptTerms,
        conceptMissingLanguages: conceptMissingLanguages,
      );
      
      // Start the background task
      await CardGenerationBackgroundService.startTask(
        conceptIds: conceptIds,
        conceptTerms: conceptTerms,
        conceptMissingLanguages: conceptMissingLanguages,
        selectedLanguages: visibleLanguages,
      );
      
      // Run the task asynchronously
      CardGenerationBackgroundService.executeTask().catchError((error) {
        print('Error in background task: $error');
        return <String, dynamic>{
          'success': false,
          'message': 'Task failed: $error',
        };
      });
      
      // Start polling for progress updates
      _cardGenerationState.startProgressPolling(_onCardGenerationComplete);
    } catch (e) {
      setState(() {
        _isLoadingConcepts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}

