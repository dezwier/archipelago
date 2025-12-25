import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/common/dictionary_item.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/states/dictionary_empty_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/states/dictionary_error_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/common/dictionary_search_bar.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/common/dictionary_fab_buttons.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/states/dictionary_empty_search_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/drawers/generate_lemmas_drawer.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/card_generation_state.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';
import 'package:archipelago/src/features/shared/providers/languages_provider.dart';
import 'helpers/dictionary_screen_data_helper.dart';
import 'helpers/dictionary_screen_export_helper.dart';
import 'helpers/dictionary_screen_generate_lemma_helper.dart';
import 'helpers/dictionary_screen_generate_image_helper.dart';
import 'helpers/dictionary_screen_generate_audio_helper.dart';
import 'helpers/dictionary_screen_handlers_helper.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({
    super.key,
  });

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

  // Helper instances
  late final DictionaryScreenDataHelper _dataHelper;
  late final DictionaryScreenExportHelper _exportHelper;
  late final DictionaryScreenGenerateLemmaHelper _generateLemmaHelper;
  late final DictionaryScreenGenerateImageHelper _generateImageHelper;
  late final DictionaryScreenGenerateAudioHelper _generateAudioHelper;
  late final DictionaryScreenHandlersHelper _handlersHelper;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    _controller = DictionaryController(authProvider);
    _cardGenerationState = CardGenerationState();
    _languageVisibilityManager = LanguageVisibilityManager();
    
    // Initialize helper classes
    _dataHelper = DictionaryScreenDataHelper(
      controller: _controller,
      languageVisibilityManager: _languageVisibilityManager,
      topicsProvider: topicsProvider,
      languagesProvider: languagesProvider,
      setAllLanguages: (languages) => setState(() => _allLanguages = languages),
      setAllTopics: (topics) => setState(() => _allTopics = topics),
      setIsLoadingTopics: (value) => setState(() => _isLoadingTopics = value),
      onControllerChanged: () => _onControllerChanged(),
      setState: () => setState(() {}),
    );
    
    _exportHelper = DictionaryScreenExportHelper(
      controller: _controller,
      languageVisibilityManager: _languageVisibilityManager,
      getAllLanguages: () => _allLanguages,
      getIsLoadingExport: () => _isLoadingExport,
      setIsLoadingExport: (value) => setState(() => _isLoadingExport = value),
      context: context,
      mounted: () => mounted,
      setState: () => setState(() {}),
    );
    
    _generateLemmaHelper = DictionaryScreenGenerateLemmaHelper(
      controller: _controller,
      languageVisibilityManager: _languageVisibilityManager,
      cardGenerationState: _cardGenerationState,
      getIsLoadingConcepts: () => _isLoadingConcepts,
      setIsLoadingConcepts: (value) => setState(() => _isLoadingConcepts = value),
      context: context,
      mounted: () => mounted,
      setState: () => setState(() {}),
      onCardGenerationComplete: _onCardGenerationComplete,
    );
    
    _generateImageHelper = DictionaryScreenGenerateImageHelper(
      controller: _controller,
      cardGenerationState: _cardGenerationState,
      getIsLoadingConcepts: () => _isLoadingConcepts,
      setIsLoadingConcepts: (value) => setState(() => _isLoadingConcepts = value),
      context: context,
      mounted: () => mounted,
      setState: () => setState(() {}),
    );
    
    _generateAudioHelper = DictionaryScreenGenerateAudioHelper(
      controller: _controller,
      cardGenerationState: _cardGenerationState,
      getIsLoadingConcepts: () => _isLoadingConcepts,
      setIsLoadingConcepts: (value) => setState(() => _isLoadingConcepts = value),
      context: context,
      mounted: () => mounted,
      setState: () => setState(() {}),
    );
    
    _handlersHelper = DictionaryScreenHandlersHelper(
      controller: _controller,
      languageVisibilityManager: _languageVisibilityManager,
      getAllLanguages: () => _allLanguages,
      getAllTopics: () => _allTopics,
      getIsLoadingTopics: () => _isLoadingTopics,
      showDescription: _showDescription,
      showExtraInfo: _showExtraInfo,
      setShowDescription: (value) => setState(() => _showDescription = value),
      setShowExtraInfo: (value) => setState(() => _showExtraInfo = value),
      context: context,
      mounted: () => mounted,
      setState: () => setState(() {}),
    );
    
    _controller.initialize();
    _scrollController.addListener(_onScroll);
    
    // Load initial data from providers
    _dataHelper.loadLanguages();
    _dataHelper.loadTopics();
    
    // Listen to provider changes
    authProvider.addListener(_onAuthChanged);
    topicsProvider.addListener(_onTopicsChanged);
    languagesProvider.addListener(_onLanguagesChanged);
    
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
    _dataHelper.handleControllerChanged(_allLanguages);
  }
  
  void _onAuthChanged() {
    // Reload topics and refresh dictionary when auth state changes
    _dataHelper.loadTopics();
    _controller.refresh();
  }
  
  void _onTopicsChanged() {
    // Update topics when provider changes
    _dataHelper.loadTopics();
  }
  
  void _onLanguagesChanged() {
    // Update languages when provider changes
    _dataHelper.loadLanguages();
  }
  

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    authProvider.removeListener(_onAuthChanged);
    topicsProvider.removeListener(_onTopicsChanged);
    languagesProvider.removeListener(_onLanguagesChanged);
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
  
  // Open generate lemmas drawer
  void openGenerateLemmasDrawer(BuildContext context) {
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
      onConfirmGenerate: () => _generateLemmaHelper.handleGenerateLemmas(),
      onConfirmGenerateImages: () => _generateImageHelper.handleGenerateImages(),
      onConfirmGenerateAudio: () => _generateAudioHelper.handleGenerateAudio(),
      visibleLanguageCodes: visibleLanguages,
    );
  }
  
  void showFilterMenu(BuildContext context) {
    _handlersHelper.showFilterMenu();
  }
  
  void showFilteringMenu(BuildContext context) {
    _handlersHelper.showFilteringMenu();
  }
  
  void showExportDrawer(BuildContext context) {
    _exportHelper.showExportDrawer();
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
        // Show loading state only on initial load (not when refreshing)
        if (_controller.isLoading && !_controller.isRefreshing) {
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
                          onTap: () => _handlersHelper.handleItemTap(item),
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
                  onFilterPressed: () => showFilterMenu(context),
                  onFilteringPressed: () => showFilteringMenu(context),
                  onGenerateLemmasPressed: () => openGenerateLemmasDrawer(context),
                  onExportPressed: () => showExportDrawer(context),
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
    
    return '$totalConcepts ${totalConcepts == 1 ? 'concept' : 'concepts'} • $filteredLemmas filtered';
  }

}

