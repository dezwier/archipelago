import 'dart:math';
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
import '../data/vocabulary_service.dart';
import '../../../utils/language_emoji.dart';

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
  bool _showSourceLanguage = true;
  bool _showTargetLanguage = true;
  bool _showDescription = true;
  bool _showImages = true;
  

  @override
  void initState() {
    super.initState();
    _controller = VocabularyController();
    _controller.initialize();
    _scrollController.addListener(_onScroll);
    
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

  @override
  void dispose() {
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

        if (_controller.currentUser == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please log in to view vocabulary',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
                // Description generation progress banner
                if (_controller.isGeneratingDescriptions)
                  SliverToBoxAdapter(
                    child: _buildDescriptionGenerationBanner(context),
                  ),
                // Generate descriptions button
                if (!_controller.isGeneratingDescriptions && 
                    _controller.hasCardsNeedingDescriptions())
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleGenerateDescriptions(),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Descriptions'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                          showSource: _showSourceLanguage,
                          showTarget: _showTargetLanguage,
                          showDescription: _showDescription,
                          showImages: _showImages,
                          onEdit: () => _handleEdit(item),
                          onDelete: () => _handleDelete(item),
                          allItems: _controller.filteredItems,
                          onRandomCard: () => _handleRandomCard(context),
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
    return '$displayCount ${displayCount == 1 ? 'phrase' : 'phrases'}';
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
                // Divider
                Container(
                  width: 1,
                  height: 32,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
                // Source/Target toggle
                ToggleButtons(
                  isSelected: [
                    _controller.searchInSource,
                    !_controller.searchInSource,
                  ],
                  onPressed: (index) {
                    _controller.setSearchMode(index == 0);
                  },
                  borderRadius: BorderRadius.circular(18),
                  constraints: const BoxConstraints(
                    minWidth: 50,
                    minHeight: 48,
                  ),
                  selectedColor: Theme.of(context).colorScheme.onPrimary,
                  fillColor: Theme.of(context).colorScheme.primary,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _controller.sourceLanguageCode != null
                                ? LanguageEmoji.getEmoji(_controller.sourceLanguageCode!)
                                : '🌐',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _controller.targetLanguageCode != null
                                ? LanguageEmoji.getEmoji(_controller.targetLanguageCode!)
                                : '🌐',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
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
            value: SortOption.sourceLanguage,
            child: Row(
              children: [
                if (_controller.sortOption == SortOption.sourceLanguage)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('Source Language'),
              ],
            ),
          ),
          PopupMenuItem<SortOption>(
            value: SortOption.targetLanguage,
            child: Row(
              children: [
                if (_controller.sortOption == SortOption.targetLanguage)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                const Text('Target Language'),
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
          _controller.setSortOption(value);
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
          PopupMenuItem<void>(
            child: StatefulBuilder(
              builder: (context, setMenuState) {
                return Row(
                  children: [
                    Checkbox(
                      value: _showSourceLanguage,
                      onChanged: (value) {
                        setMenuState(() {
                          setState(() {
                            _showSourceLanguage = value ?? true;
                          });
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Source Language'),
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
                      value: _showTargetLanguage,
                      onChanged: (value) {
                        setMenuState(() {
                          setState(() {
                            _showTargetLanguage = value ?? true;
                          });
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Target Language'),
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
          PopupMenuItem<void>(
            child: StatefulBuilder(
              builder: (context, setMenuState) {
                return Row(
                  children: [
                    Checkbox(
                      value: _showImages,
                      onChanged: (value) {
                        setMenuState(() {
                          setState(() {
                            _showImages = value ?? true;
                          });
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text('Images'),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
  }

  Widget _buildDescriptionGenerationBanner(BuildContext context) {
    final progress = _controller.descriptionProgress;
    final status = _controller.descriptionStatus;
    final processed = progress?['processed'] as int? ?? 0;
    final total = progress?['total_concepts'] as int? ?? 0;
    final cardsUpdated = progress?['cards_updated'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Generating descriptions...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status == 'running')
                TextButton(
                  onPressed: () => _handleCancelGenerateDescriptions(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel'),
                ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: processed / total,
              minHeight: 4,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Processed: $processed / $total concepts • $cardsUpdated cards updated',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleGenerateDescriptions() async {
    final success = await _controller.startGenerateDescriptions();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Description generation started'
                : _controller.errorMessage ?? 'Failed to start description generation',
          ),
          backgroundColor: success
              ? null
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleCancelGenerateDescriptions() async {
    final success = await _controller.cancelGenerateDescriptions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Description generation cancelled'
                : _controller.errorMessage ?? 'Failed to cancel',
          ),
          backgroundColor: success
              ? null
              : Theme.of(context).colorScheme.error,
        ),
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
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => VocabularyDetailDrawer(
        item: item,
        sourceLanguageCode: _controller.sourceLanguageCode,
        targetLanguageCode: _controller.targetLanguageCode,
        onEdit: () => _handleEdit(item),
        onRandomCard: () => _handleRandomCard(context),
        onRefreshImages: () => _handleRefreshImages(context, item),
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
    
    // Close current dialog and reopen with updated item
    if (mounted) {
      Navigator.of(context).pop(); // Close current dialog
      _handleItemTap(updatedItem); // Reopen with updated item
    }
  }

  void _handleRandomCard(BuildContext context) {
    final items = _controller.filteredItems;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available')),
      );
      return;
    }

    final random = Random();
    final randomItem = items[random.nextInt(items.length)];
    _handleItemTap(randomItem);
  }

  Future<void> _handleRefreshImages(BuildContext context, PairedVocabularyItem item) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await VocabularyService.refreshImagesForConcept(
        conceptId: item.conceptId,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        if (result['success'] == true) {
          // Refresh the vocabulary list to show new images
          await _controller.refresh();
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] as String? ?? 'Images added successfully',
              ),
            ),
          );
          
          // Update the item in the dialog without closing it
          final updatedItems = _controller.filteredItems;
          final updatedItem = updatedItems.firstWhere(
            (i) => i.conceptId == item.conceptId,
            orElse: () => item,
          );
          
          // Close current dialog and reopen with updated item
          Navigator.of(context).pop(); // Close detail dialog
          _handleItemTap(updatedItem); // Reopen with updated item
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] as String? ?? 'Failed to refresh images',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing images: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

