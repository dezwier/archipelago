import 'package:flutter/material.dart';
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
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/create/domain/topic.dart';
import 'mixins/dictionary_screen_data.dart';
import 'mixins/dictionary_screen_export.dart';
import 'mixins/dictionary_screen_generate_lemma.dart';
import 'mixins/dictionary_screen_generate_image.dart';
import 'mixins/dictionary_screen_generate_audio.dart';
import 'mixins/dictionary_screen_handlers.dart';

class DictionaryScreen extends StatefulWidget {
  final Function(Function())? onRefreshCallbackReady;
  
  const DictionaryScreen({
    super.key,
    this.onRefreshCallbackReady,
  });

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen>
    with
        DictionaryScreenData,
        DictionaryScreenExport,
        DictionaryScreenGenerateLemma,
        DictionaryScreenGenerateImage,
        DictionaryScreenGenerateAudio,
        DictionaryScreenHandlers {
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

  // Getters for mixins
  @override
  DictionaryController get controller => _controller;

  @override
  LanguageVisibilityManager get languageVisibilityManager => _languageVisibilityManager;

  @override
  CardGenerationState get cardGenerationState => _cardGenerationState;

  @override
  List<Language> get allLanguages => _allLanguages;

  @override
  List<Topic> get allTopics => _allTopics;

  @override
  bool get isLoadingTopics => _isLoadingTopics;

  @override
  bool get isLoadingConcepts => _isLoadingConcepts;

  @override
  bool get isLoadingExport => _isLoadingExport;

  @override
  bool get showDescription => _showDescription;

  @override
  bool get showExtraInfo => _showExtraInfo;

  // Setters for mixins
  @override
  void setAllLanguages(List<Language> value) => _allLanguages = value;

  @override
  void setAllTopics(List<Topic> value) => _allTopics = value;

  @override
  void setIsLoadingTopics(bool value) => _isLoadingTopics = value;

  @override
  void setIsLoadingConcepts(bool value) => _isLoadingConcepts = value;

  @override
  void setIsLoadingExport(bool value) => _isLoadingExport = value;

  @override
  void setShowDescription(bool value) => _showDescription = value;

  @override
  void setShowExtraInfo(bool value) => _showExtraInfo = value;

  @override
  void onControllerChanged() => _onControllerChanged();

  @override
  void initState() {
    super.initState();
    _controller = DictionaryController();
    _cardGenerationState = CardGenerationState();
    _languageVisibilityManager = LanguageVisibilityManager();
    _controller.initialize();
    _scrollController.addListener(_onScroll);
    loadLanguages();
    loadTopics();
    
    // Register refresh callback with parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRefreshCallbackReady?.call(() {
        // Reload topics and refresh dictionary (which will reload concept count if user changed)
        loadTopics();
        _controller.refresh();
      });
    });
    
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
    handleControllerChanged();
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

  @override
  void onCardGenerationComplete() => _onCardGenerationComplete();
  
  // Override to provide access to image and audio handlers
  void openGenerateLemmasDrawer(BuildContext context) {
    final visibleLanguages = languageVisibilityManager.getVisibleLanguageCodes();
    
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
      cardGenerationState: cardGenerationState,
      onConfirmGenerate: () => handleGenerateLemmas(context),
      onConfirmGenerateImages: () => handleGenerateImages(context),
      onConfirmGenerateAudio: () => handleGenerateAudio(context),
      visibleLanguageCodes: visibleLanguages,
    );
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
                          onTap: () => handleItemTap(item),
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

