import 'package:flutter/material.dart';
import 'vocabulary_controller.dart';
import '../domain/paired_vocabulary_item.dart';
import 'widgets/vocabulary_header_widget.dart';
import 'widgets/vocabulary_item_widget.dart';
import 'widgets/vocabulary_empty_state.dart';
import 'widgets/vocabulary_error_state.dart';
import 'widgets/edit_vocabulary_dialog.dart';
import 'widgets/delete_vocabulary_dialog.dart';
import 'widgets/vocabulary_detail_dialog.dart';
import '../../../utils/language_emoji.dart';
import '../../profile/data/language_service.dart';
import '../../profile/domain/language.dart';

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
  final GlobalKey _sortButtonKey = GlobalKey();
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Filter state - all enabled by default
  Map<String, bool> _languageVisibility = {}; // languageCode -> isVisible
  List<String> _languagesToShow = []; // Ordered list of languages to show
  bool _showDescription = true;
  bool _showExtraInfo = true;
  List<Language> _allLanguages = [];
  

  @override
  void initState() {
    super.initState();
    _controller = VocabularyController();
    _controller.initialize();
    _scrollController.addListener(_onScroll);
    _loadLanguages();
    
    // Listen to controller changes to update language visibility when user loads
    _controller.addListener(_onControllerChanged);
    
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
        // Set language filter to visible languages
        _controller.setLanguageCodes(_getVisibleLanguageCodes());
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
        // Set language filter to visible languages
        _controller.setLanguageCodes(_getVisibleLanguageCodes());
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
    
    // Set language filter after visibility is initialized
    if (_languagesToShow.isNotEmpty) {
      _controller.setLanguageCodes(_getVisibleLanguageCodes());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
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
                // Phrase count at top of cards
                if (_controller.filteredItems.isNotEmpty)
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
                bottom: MediaQuery.of(context).padding.bottom + 80,
                child: FloatingActionButton.small(
                  key: _filterButtonKey,
                  heroTag: 'filter_fab',
                  onPressed: () => _showFilterMenu(context),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.visibility),
                  tooltip: 'Show/Hide',
                ),
              ),
              // Sort button positioned above filter button
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 140,
                child: FloatingActionButton.small(
                  key: _sortButtonKey,
                  heroTag: 'sort_fab',
                  onPressed: () => _showSortMenu(context),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.sort),
                  tooltip: 'Sort',
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
    final displayCount = _controller.searchQuery.isNotEmpty
        ? _controller.filteredItems.length
        : _controller.totalItems;
    return '$displayCount ${displayCount == 1 ? 'lemma' : 'lemmas'}';
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

  void _showSortMenu(BuildContext context) {
    final RenderBox? button = _sortButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    if (button != null) {
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );

      showMenu<SortOption>(
        context: context,
        position: position,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        items: [
          PopupMenuItem<SortOption>(
            value: SortOption.alphabetical,
            child: Row(
              children: [
                if (_controller.sortOption == SortOption.alphabetical)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('Alphabetically'),
              ],
            ),
          ),
          PopupMenuItem<SortOption>(
            value: SortOption.timeCreatedRecentFirst,
            child: Row(
              children: [
                if (_controller.sortOption == SortOption.timeCreatedRecentFirst)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('Recent First'),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (value != null) {
          // Get the first visible language for alphabetical sorting
          final firstVisibleLanguage = _languagesToShow.isNotEmpty 
              ? _languagesToShow.first 
              : null;
          _controller.setSortOption(value, firstVisibleLanguage: firstVisibleLanguage);
        }
      });
    }
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
                                
                                // Update language filter to only show concepts with terms in visible languages
                                // This will also limit search to these languages
                                _controller.setLanguageCodes(_getVisibleLanguageCodes());
                                
                                // Re-search if there's an active search query (will use updated language codes)
                                if (_controller.searchQuery.isNotEmpty) {
                                  _controller.setSearchQuery(_controller.searchQuery);
                                }
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
                                width: isVisible ? 2 : 1,
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => EditVocabularyDialog(
        item: item,
        sourceLanguageCode: _controller.sourceLanguageCode,
        targetLanguageCode: _controller.targetLanguageCode,
      ),
    );

    if (result != null && mounted) {
      final success = await _controller.updateItem(
        item,
        result['source'],
        result['target'],
        result['image_url'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Translation and image updated successfully'
                  : _controller.errorMessage ?? 'Failed to update translation',
            ),
            backgroundColor: success
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        );
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

}

