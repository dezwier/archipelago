import 'package:flutter/material.dart';
import 'vocabulary_controller.dart';
import '../domain/paired_vocabulary_item.dart';
import 'widgets/vocabulary_item_widget.dart';
import 'widgets/vocabulary_empty_state.dart';
import 'widgets/vocabulary_error_state.dart';
import 'widgets/delete_vocabulary_dialog.dart';
import 'widgets/vocabulary_detail_dialog.dart';
import 'widgets/vocabulary_filter_sheet.dart';
import 'edit_concept_screen.dart';
import '../../../utils/language_emoji.dart';
import '../../profile/data/language_service.dart';
import '../../profile/domain/language.dart';
import '../../generate_flashcards/data/topic_service.dart';
import '../../generate_flashcards/data/flashcard_service.dart';
import '../../generate_flashcards/data/card_generation_background_service.dart';
import '../../generate_flashcards/presentation/widgets/card_generation_progress_widget.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../profile/domain/user.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  late final VocabularyController _controller;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey _filteringButtonKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Filter state - all enabled by default
  Map<String, bool> _languageVisibility = {}; // languageCode -> isVisible
  List<String> _languagesToShow = []; // Ordered list of languages to show
  bool _showDescription = true;
  bool _showExtraInfo = true;
  List<Language> _allLanguages = [];
  List<Topic> _allTopics = [];
  bool _isLoadingTopics = false;
  
  // Progress tracking for card generation
  int? _totalConcepts;
  int _currentConceptIndex = 0;
  String? _currentConceptTerm;
  List<String> _currentConceptMissingLanguages = [];
  int _conceptsProcessed = 0;
  int _cardsCreated = 0;
  List<String> _errors = [];
  bool _isCancelled = false;
  bool _isGeneratingCards = false;
  double _sessionCostUsd = 0.0;
  bool _isLoadingConcepts = false; // Loading state for the button
  
  Timer? _progressPollTimer;

  @override
  void initState() {
    super.initState();
    _controller = VocabularyController();
    _controller.initialize();
    _scrollController.addListener(_onScroll);
    _loadLanguages();
    _loadTopics();
    
    // Listen to controller changes to update language visibility when user loads
    _controller.addListener(_onControllerChanged);
    
    // Load existing task state and start polling
    _loadExistingTaskState().then((_) {
      _startProgressPolling();
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
      if (_languagesToShow.isEmpty) {
        setState(() {
          _languageVisibility = {
            for (var lang in _allLanguages) 
              lang.code: (lang.code == sourceCode || lang.code == targetCode)
          };
          // Initialize with source and target languages
          _languagesToShow = [];
          if (sourceCode != null) {
            _languagesToShow.add(sourceCode);
          }
          if (targetCode != null && targetCode != sourceCode) {
            _languagesToShow.add(targetCode);
          }
        });
        // Set language filter to visible languages (for search only)
        _controller.setLanguageCodes(_getVisibleLanguageCodes());
        // Set visible languages for count calculation
        _controller.setVisibleLanguageCodes(_getVisibleLanguageCodes());
      }
    } else if (_controller.currentUser == null && _allLanguages.isNotEmpty) {
      // When logged out, default to English only
      if (_languagesToShow.isEmpty) {
        setState(() {
          _languageVisibility = {
            for (var lang in _allLanguages) 
              lang.code: lang.code.toLowerCase() == 'en'
          };
          // Initialize with English only
          _languagesToShow = ['en'];
        });
        // Set language filter to visible languages (for search only)
        _controller.setLanguageCodes(_getVisibleLanguageCodes());
        // Set visible languages for count calculation
        _controller.setVisibleLanguageCodes(_getVisibleLanguageCodes());
      }
    }
  }

  Future<void> _loadLanguages() async {
    final languages = await LanguageService.getLanguages();
    
    setState(() {
      _allLanguages = languages;
      // Initialize visibility - default to English if logged out
      if (_controller.currentUser == null) {
        _languageVisibility = {
          for (var lang in languages) 
            lang.code: lang.code.toLowerCase() == 'en'
        };
        _languagesToShow = ['en'];
      } else {
        _languageVisibility = {
          for (var lang in languages) lang.code: false
        };
      }
    });
    
    // Update defaults based on user state
    _onControllerChanged();
    
    // Set language filter after visibility is initialized (for search only)
    if (_languagesToShow.isNotEmpty) {
      _controller.setLanguageCodes(_getVisibleLanguageCodes());
      // Set visible languages for count calculation
      _controller.setVisibleLanguageCodes(_getVisibleLanguageCodes());
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
    _progressPollTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _loadExistingTaskState() async {
    final state = await CardGenerationBackgroundService.getTaskState();
    if (state != null && state['isRunning'] == true) {
      // Get missing languages for current concept
      final conceptIds = state['conceptIds'] as List<int>? ?? [];
      final conceptMissingLanguagesMap = state['conceptMissingLanguages'] as Map<int, List<String>>? ?? {};
      final currentIndex = state['currentIndex'] as int? ?? 0;
      final currentConceptMissingLanguages = <String>[];
      
      if (currentIndex < conceptIds.length) {
        final currentConceptId = conceptIds[currentIndex];
        currentConceptMissingLanguages.addAll(conceptMissingLanguagesMap[currentConceptId] ?? []);
      }
      
      setState(() {
        _isGeneratingCards = true;
        _totalConcepts = state['totalConcepts'] as int?;
        _currentConceptIndex = currentIndex;
        _currentConceptTerm = state['currentTerm'] as String?;
        _currentConceptMissingLanguages = currentConceptMissingLanguages;
        _conceptsProcessed = state['conceptsProcessed'] as int? ?? 0;
        _cardsCreated = state['cardsCreated'] as int? ?? 0;
        _sessionCostUsd = state['sessionCostUsd'] as double? ?? 0.0;
        _errors = List<String>.from(state['errors'] as List? ?? []);
        _isCancelled = state['isCancelled'] as bool? ?? false;
      });
    }
  }

  void _startProgressPolling() {
    _progressPollTimer?.cancel();
    _progressPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isGeneratingCards) {
        timer.cancel();
        return;
      }

      final state = await CardGenerationBackgroundService.getTaskState();
      
      // Check if cancelled first
      final isCancelled = state?['isCancelled'] as bool? ?? false;
      if (isCancelled) {
        timer.cancel();
        setState(() {
          _isCancelled = true;
          _isGeneratingCards = false;
        });
        _showCompletionMessage();
        return;
      }
      
      if (state == null || state['isRunning'] != true) {
        // Task completed (not cancelled)
        timer.cancel();
        setState(() {
          _isGeneratingCards = false;
        });
        _showCompletionMessage();
        return;
      }

      // Get missing languages for current concept
      final conceptIds = state['conceptIds'] as List<int>? ?? [];
      final conceptMissingLanguagesMap = state['conceptMissingLanguages'] as Map<int, List<String>>? ?? {};
      final currentIndex = state['currentIndex'] as int? ?? 0;
      final currentConceptMissingLanguages = <String>[];
      
      if (currentIndex < conceptIds.length) {
        final currentConceptId = conceptIds[currentIndex];
        currentConceptMissingLanguages.addAll(conceptMissingLanguagesMap[currentConceptId] ?? []);
      }

      setState(() {
        _currentConceptIndex = currentIndex;
        _currentConceptTerm = state['currentTerm'] as String?;
        _currentConceptMissingLanguages = currentConceptMissingLanguages;
        _conceptsProcessed = state['conceptsProcessed'] as int? ?? 0;
        _cardsCreated = state['cardsCreated'] as int? ?? 0;
        _sessionCostUsd = state['sessionCostUsd'] as double? ?? 0.0;
        _errors = List<String>.from(state['errors'] as List? ?? []);
        _isCancelled = false; // Only set to false if we're still running and not cancelled
      });
    });
  }
  
  void _showCompletionMessage() {
    // Refresh vocabulary to show new cards
    _controller.refresh();
    
    setState(() {
      _currentConceptTerm = null;
      _currentConceptMissingLanguages = [];
    });
  }
  
  void _dismissProgress() {
    setState(() {
      _totalConcepts = null;
      _currentConceptIndex = 0;
      _currentConceptTerm = null;
      _currentConceptMissingLanguages = [];
      _conceptsProcessed = 0;
      _cardsCreated = 0;
      _errors = [];
      _isCancelled = false;
      _isGeneratingCards = false;
      _sessionCostUsd = 0.0;
    });
  }
  
  Future<void> _handleCancel() async {
    // Stop polling immediately
    _progressPollTimer?.cancel();
    await CardGenerationBackgroundService.cancelTask();
    setState(() {
      _isCancelled = true;
      _isGeneratingCards = false;
    });
    // Show cancellation message immediately
    _showCompletionMessage();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      _controller.loadMoreVocabulary();
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
            body: VocabularyErrorState(
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
                // Progress display for card generation
                if (_totalConcepts != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                      child: CardGenerationProgressWidget(
                        totalConcepts: _totalConcepts,
                        currentConceptIndex: _currentConceptIndex,
                        currentConceptTerm: _currentConceptTerm,
                        currentConceptMissingLanguages: _currentConceptMissingLanguages,
                        conceptsProcessed: _conceptsProcessed,
                        cardsCreated: _cardsCreated,
                        errors: _errors,
                        sessionCostUsd: _sessionCostUsd,
                        isGenerating: _isGeneratingCards,
                        isCancelled: _isCancelled,
                        onCancel: _isGeneratingCards ? _handleCancel : null,
                        onDismiss: !_isGeneratingCards ? _dismissProgress : null,
                      ),
                    ),
                  ),
                // Paired vocabulary items
                if (_controller.filteredItems.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _controller.filteredItems[index];
                        return VocabularyItemWidget(
                          item: item,
                          sourceLanguageCode: _controller.sourceLanguageCode,
                          targetLanguageCode: _controller.targetLanguageCode,
                          languageVisibility: _languageVisibility,
                          languagesToShow: _languagesToShow,
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
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No results found',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try a different search term',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const VocabularyEmptyState(),
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
                child: _buildBottomSearchBar(context),
              ),
              // Filter button positioned above search bar
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 70,
                child: FloatingActionButton.small(
                  key: _filterButtonKey,
                  heroTag: 'filter_fab',
                  onPressed: () => _showFilterMenu(context),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  child: const Icon(Icons.visibility),
                  tooltip: 'Show/Hide',
                ),
              ),
              // Filtering button positioned above filter button
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 120,
                child: FloatingActionButton.small(
                  key: _filteringButtonKey,
                  heroTag: 'filtering_fab',
                  onPressed: () => _showFilteringMenu(context),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  child: const Icon(Icons.filter_list),
                  tooltip: 'Filter',
                ),
              ),
              // Generate lemmas button positioned above filtering button
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 170,
                child: FloatingActionButton.small(
                  heroTag: 'generate_lemmas_fab',
                  onPressed: _isLoadingConcepts ? null : () => _handleGenerateLemmas(context),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  child: _isLoadingConcepts
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  tooltip: 'Generate Lemmas',
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

  List<String> _getVisibleLanguageCodes() {
    return _languageVisibility.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  Widget _buildBottomSearchBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 2,
                  spreadRadius: 0,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: false,
                    textCapitalization: TextCapitalization.sentences,
                    onTap: () {
                      // Always enable focus when user taps on the field
                      _searchFocusNode.canRequestFocus = true;
                      // Request focus explicitly to ensure it works
                      _searchFocusNode.requestFocus();
                    },
                    onChanged: (value) => _controller.setSearchQuery(value),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      suffixIcon: _controller.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _controller.setSearchQuery('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showFilteringMenu(BuildContext context) {
    // Get the first visible language for alphabetical sorting
    final firstVisibleLanguage = _languagesToShow.isNotEmpty 
        ? _languagesToShow.first 
        : null;
    showVocabularyFilterSheet(
      context: context,
      controller: _controller,
      topics: _allTopics,
      isLoadingTopics: _isLoadingTopics,
      firstVisibleLanguage: firstVisibleLanguage,
    );
  }

  void _showFilterMenu(BuildContext context) {
    final RenderBox? button = _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    if (button != null) {
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );

      showMenu<void>(
        context: context,
        position: position,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        items: [
          // Language visibility buttons
          PopupMenuItem<void>(
            child: StatefulBuilder(
              builder: (context, setMenuState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Languages',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allLanguages.map((language) {
                        final isVisible = _languageVisibility[language.code] ?? true;
                        return GestureDetector(
                          onTap: () {
                            setMenuState(() {
                              setState(() {
                                final wasVisible = _languageVisibility[language.code] ?? true;
                                final willBeVisible = !isVisible;
                                
                                // Prevent disabling if this is the last visible language
                                if (wasVisible && !willBeVisible) {
                                  final visibleCount = _languageVisibility.values.where((v) => v == true).length;
                                  if (visibleCount <= 1) {
                                    return; // Don't proceed with the change
                                  }
                                }
                                
                                _languageVisibility[language.code] = willBeVisible;
                                
                                if (!wasVisible && willBeVisible) {
                                  // Language was just enabled - append to the end of the list
                                  if (!_languagesToShow.contains(language.code)) {
                                    _languagesToShow.add(language.code);
                                  }
                                } else if (wasVisible && !willBeVisible) {
                                  // Language was just disabled - remove from the list
                                  _languagesToShow.remove(language.code);
                                }
                                
                                // Update language filter for search (concepts are no longer filtered by visibility)
                                _controller.setLanguageCodes(_getVisibleLanguageCodes());
                                // Update visible languages - this will refresh vocabulary and counts
                                _controller.setVisibleLanguageCodes(_getVisibleLanguageCodes());
                              });
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isVisible
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isVisible
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: isVisible ? 1 : 1,
                              ),
                            ),
                            child: Text(
                              LanguageEmoji.getEmoji(language.code),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<void>(
            child: StatefulBuilder(
              builder: (context, setMenuState) {
                return Row(
                  children: [
                    Checkbox(
                      value: _showExtraInfo,
                      onChanged: (value) {
                        setMenuState(() {
                          setState(() {
                            _showExtraInfo = value ?? true;
                          });
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Extra Info'),
                  ],
                );
              },
            ),
          ),
          PopupMenuItem<void>(
            child: StatefulBuilder(
              builder: (context, setMenuState) {
                return Row(
                  children: [
                    Checkbox(
                      value: _showDescription,
                      onChanged: (value) {
                        setMenuState(() {
                          setState(() {
                            _showDescription = value ?? true;
                          });
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Description'),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
  }

  Future<void> _handleEdit(PairedVocabularyItem item) async {
    // Navigate to edit concept screen
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditConceptScreen(item: item),
      ),
    );

    if (result == true && mounted) {
      // Refresh the vocabulary list to show updated concept
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

  Future<void> _handleDelete(PairedVocabularyItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteVocabularyDialog(),
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

  void _handleItemTap(PairedVocabularyItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VocabularyDetailDrawer(
        item: item,
        sourceLanguageCode: _controller.sourceLanguageCode,
        targetLanguageCode: _controller.targetLanguageCode,
        languageVisibility: _languageVisibility,
        languagesToShow: _languagesToShow,
        onEdit: () => _handleEdit(item),
        onDelete: () => _handleDelete(item),
        onItemUpdated: (updatedItem) => _handleItemUpdated(context, updatedItem),
      ),
    );
  }

  Future<void> _handleItemUpdated(BuildContext context, PairedVocabularyItem item) async {
    // Refresh the vocabulary list to get updated item
    await _controller.refresh();
    
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

  Future<void> _handleGenerateLemmas(BuildContext context) async {
    // Get visible languages
    final visibleLanguages = _getVisibleLanguageCodes();
    
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
      // Get concepts with missing languages for visible languages
      final missingResult = await FlashcardService.getConceptsWithMissingLanguages(
        languages: visibleLanguages,
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
      
      // Filter concepts based on current filters
      final filteredConcepts = _filterConceptsByCurrentFilters(concepts);
      
      if (filteredConcepts.isEmpty) {
        setState(() {
          _isLoadingConcepts = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No concepts match the current filters'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }
      
      // Extract concept IDs, terms, and missing languages
      final conceptIds = <int>[];
      final conceptTerms = <int, String>{};
      final conceptMissingLanguages = <int, List<String>>{};
      
      for (final c in filteredConcepts) {
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
        _isGeneratingCards = true;
        _isCancelled = false;
        _totalConcepts = conceptIds.length;
        _currentConceptIndex = 0;
        _currentConceptTerm = null;
        _currentConceptMissingLanguages = [];
        _conceptsProcessed = 0;
        _cardsCreated = 0;
        _errors = [];
        _sessionCostUsd = 0.0;
      });
      
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
      _startProgressPolling();
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
  
  List<dynamic> _filterConceptsByCurrentFilters(List<dynamic> concepts) {
    return concepts.where((c) {
      final conceptData = c as Map<String, dynamic>;
      final concept = conceptData['concept'] as Map<String, dynamic>;
      
      // Filter by topic - use same logic as _getEffectiveTopicIds
      final selectedTopicIds = _controller.selectedTopicIds;
      final allAvailableTopicIds = _controller.allAvailableTopicIds;
      final conceptTopicId = concept['topic_id'] as int?;
      
      // Check if all topics are selected (same logic as _getEffectiveTopicIds)
      final allTopicsSelected = allAvailableTopicIds != null &&
          allAvailableTopicIds.isNotEmpty &&
          selectedTopicIds.length == allAvailableTopicIds.length &&
          selectedTopicIds.containsAll(allAvailableTopicIds) &&
          allAvailableTopicIds.containsAll(selectedTopicIds);
      
      if (!allTopicsSelected && selectedTopicIds.isNotEmpty) {
        // Not all topics selected - need to filter
        if (!_controller.showLemmasWithoutTopic) {
          // Exclude concepts without topic
          if (conceptTopicId == null) {
            return false;
          }
          // Include only if topic is selected
          if (!selectedTopicIds.contains(conceptTopicId)) {
            return false;
          }
        } else {
          // Include concepts without topic OR with selected topic
          if (conceptTopicId != null && !selectedTopicIds.contains(conceptTopicId)) {
            return false;
          }
        }
      } else if (!_controller.showLemmasWithoutTopic) {
        // All topics selected or no topics selected, but exclude concepts without topic
        if (conceptTopicId == null) {
          return false;
        }
      }
      
      // Filter by part of speech - use same logic as _getEffectivePartOfSpeech
      final selectedPOS = _controller.selectedPartOfSpeech;
      const allPOS = {
        'Noun', 'Verb', 'Adjective', 'Adverb', 'Pronoun', 'Preposition', 
        'Conjunction', 'Determiner / Article', 'Interjection', 'Saying', 'Sentence'
      };
      final allPOSSelected = selectedPOS.length == allPOS.length && 
          selectedPOS.containsAll(allPOS);
      
      if (!allPOSSelected && selectedPOS.isNotEmpty) {
        final conceptPOS = concept['part_of_speech'] as String?;
        if (conceptPOS != null && !selectedPOS.contains(conceptPOS)) {
          return false;
        }
      }
      
      // Filter by public/private
      final conceptUserId = concept['user_id'] as int?;
      final currentUserId = _controller.currentUser?.id;
      
      if (!_controller.includePublic && !_controller.includePrivate) {
        return false; // Both filters are false - show nothing
      } else if (!_controller.includePublic && _controller.includePrivate) {
        // Only private - must have user_id matching current user
        if (conceptUserId == null || conceptUserId != currentUserId) {
          return false;
        }
      } else if (_controller.includePublic && !_controller.includePrivate) {
        // Only public - must have user_id == null
        if (conceptUserId != null) {
          return false;
        }
      }
      // If both are true, include all (no filter)
      
      // Filter by search query (if any)
      final searchQuery = _controller.searchQuery.trim().toLowerCase();
      if (searchQuery.isNotEmpty) {
        final conceptTerm = (concept['term'] as String? ?? '').toLowerCase();
        if (!conceptTerm.contains(searchQuery)) {
          return false;
        }
      }
      
      // Note: Level filtering is not available in ConceptResponse, so we skip it
      // This is a limitation - we could enhance the API endpoint later to include level
      
      return true;
    }).toList();
  }

}

