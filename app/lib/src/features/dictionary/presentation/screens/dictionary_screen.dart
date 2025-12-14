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
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_filter_menu.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_fab_buttons.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/dictionary_empty_search_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/export_flashcards_drawer.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/card_generation_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/dictionary/presentation/screens/edit_concept_screen.dart';
import 'package:archipelago/src/features/profile/data/language_service.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/create/data/flashcard_service.dart';
import 'package:archipelago/src/features/create/data/card_generation_background_service.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/card_generation_progress_widget.dart';
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
                // Progress display for lemma generation
                if (_cardGenerationState.totalConcepts != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                      child: CardGenerationProgressWidget(
                        totalConcepts: _cardGenerationState.totalConcepts,
                        currentConceptIndex: _cardGenerationState.currentConceptIndex,
                        currentConceptTerm: _cardGenerationState.currentConceptTerm,
                        currentConceptMissingLanguages: _cardGenerationState.currentConceptMissingLanguages,
                        conceptsProcessed: _cardGenerationState.conceptsProcessed,
                        cardsCreated: _cardGenerationState.cardsCreated,
                        errors: _cardGenerationState.errors,
                        sessionCostUsd: _cardGenerationState.sessionCostUsd,
                        isGenerating: _cardGenerationState.isGeneratingCards,
                        isCancelled: _cardGenerationState.isCancelled,
                        onCancel: _cardGenerationState.isGeneratingCards 
                            ? () => _cardGenerationState.handleCancel()
                            : null,
                        onDismiss: !_cardGenerationState.isGeneratingCards 
                            ? () => _cardGenerationState.dismissProgress()
                            : null,
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
                  onGenerateLemmasPressed: () => _handleGenerateLemmas(context),
                  onExportPressed: () => _showExportDrawer(context),
                  isLoadingConcepts: _isLoadingConcepts,
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
    // Get the first visible language for alphabetical sorting
    final firstVisibleLanguage = _languageVisibilityManager.languagesToShow.isNotEmpty 
        ? _languageVisibilityManager.languagesToShow.first 
        : null;
    showDictionaryFilterSheet(
      context: context,
      controller: _controller,
      topics: _allTopics,
      isLoadingTopics: _isLoadingTopics,
      firstVisibleLanguage: firstVisibleLanguage,
    );
  }

  void _showExportDrawer(BuildContext context) {
    final completedCount = _controller.conceptsWithAllVisibleLanguages ?? 0;
    final visibleLanguageCodes = _languageVisibilityManager.getVisibleLanguageCodes();
    
    showExportFlashcardsDrawer(
      context: context,
      completedConceptsCount: completedCount,
      availableLanguages: _allLanguages,
      visibleLanguageCodes: visibleLanguageCodes,
    );
  }

  void _showFilterMenu(BuildContext context) {
    final RenderBox? button = _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    RelativeRect position;
    if (button != null) {
      position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );
    } else {
      // Fallback: position menu near bottom right where the button should be
      final screenSize = MediaQuery.of(context).size;
      position = RelativeRect.fromLTRB(
        screenSize.width - 200,
        screenSize.height - 200,
        screenSize.width - 16,
        screenSize.height - 16,
      );
    }

    showMenu<void>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: DictionaryFilterMenu.buildMenuItems(
        context: context,
        allLanguages: _allLanguages,
        languageVisibility: _languageVisibilityManager.languageVisibility,
        languagesToShow: _languageVisibilityManager.languagesToShow,
        showDescription: _showDescription,
        showExtraInfo: _showExtraInfo,
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
      ),
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
      
      // Get own user ID for private filtering
      final ownUserId = (_controller.includePrivate && _controller.currentUser != null) 
          ? _controller.currentUser!.id 
          : null;
      
      // Get concepts with missing languages for visible languages
      // All filtering is now done API-side
      final missingResult = await FlashcardService.getConceptsWithMissingLanguages(
        languages: visibleLanguages,
        levels: effectiveLevels,
        partOfSpeech: effectivePOS,
        topicIds: effectiveTopicIds,
        includeWithoutTopic: _controller.showLemmasWithoutTopic,
        includePublic: _controller.includePublic,
        includePrivate: _controller.includePrivate,
        ownUserId: ownUserId,
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

