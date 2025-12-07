import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../features/profile/domain/user.dart';
import '../../../utils/language_emoji.dart';
import '../../../utils/html_entity_decoder.dart';
import '../data/vocabulary_service.dart';
import '../domain/paired_vocabulary_item.dart';
import '../domain/vocabulary_card.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
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
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserAndVocabulary();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      _loadMoreVocabulary();
    }
  }

  Future<void> _loadUserAndVocabulary({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _pairedItems = [];
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Load user data
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        setState(() {
          _currentUser = User.fromJson(userMap);
          _sourceLanguageCode = _currentUser!.langNative;
          _targetLanguageCode = _currentUser!.langLearning;
        });
      }

      // Load vocabulary
      if (_currentUser != null) {
        final result = await VocabularyService.getVocabulary(
          userId: _currentUser!.id,
          page: 1,
          pageSize: _pageSize,
        );

        if (result['success'] == true) {
          final List<dynamic> itemsData = result['items'] as List<dynamic>;
          final items = itemsData
              .map((json) => PairedVocabularyItem.fromJson(json as Map<String, dynamic>))
              .toList();
          
          setState(() {
            _pairedItems = items;
            _currentPage = result['page'] as int;
            _totalItems = result['total'] as int;
            _hasNextPage = result['has_next'] as bool;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = result['message'] as String? ?? 'Failed to load vocabulary';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Please log in to view vocabulary';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading vocabulary: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreVocabulary() async {
    if (_isLoadingMore || !_hasNextPage || _currentUser == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await VocabularyService.getVocabulary(
        userId: _currentUser!.id,
        page: nextPage,
        pageSize: _pageSize,
      );

      if (result['success'] == true) {
        final List<dynamic> itemsData = result['items'] as List<dynamic>;
        final newItems = itemsData
            .map((json) => PairedVocabularyItem.fromJson(json as Map<String, dynamic>))
            .toList();
        
        setState(() {
          _pairedItems.addAll(newItems);
          _currentPage = result['page'] as int;
          _totalItems = result['total'] as int;
          _hasNextPage = result['has_next'] as bool;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String? ?? 'Failed to load more vocabulary'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading more vocabulary: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserAndVocabulary,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
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
      body: RefreshIndicator(
        onRefresh: () => _loadUserAndVocabulary(reset: true),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      '${_totalItems > 0 ? _totalItems : _pairedItems.length} phrases',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Paired vocabulary items
            if (_pairedItems.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _pairedItems[index];
                    return _buildPairedItem(item);
                  },
                  childCount: _pairedItems.length,
                ),
              ),
            // Empty state
            if (_pairedItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No vocabulary yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generate flashcards to build your vocabulary',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            // Loading more indicator
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairedItem(PairedVocabularyItem item) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _showEditDialog(item),
            backgroundColor: const Color(0xFFFFD4A3), // Pastel orange
            foregroundColor: const Color(0xFF8B4513), // Dark brown for contrast
            icon: Icons.edit,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
          SlidableAction(
            onPressed: (context) => _deleteItem(item),
            backgroundColor: const Color(0xFFFFB3B3), // Pastel red
            foregroundColor: const Color(0xFF8B0000), // Dark red for contrast
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source card (if available)
            if (item.sourceCard != null && _sourceLanguageCode != null)
              _buildCardSection(
                item.sourceCard!,
                _sourceLanguageCode!,
                isSource: true,
              ),
            // Target card (if available)
            if (item.targetCard != null && _targetLanguageCode != null)
              _buildCardSection(
                item.targetCard!,
                _targetLanguageCode!,
                isSource: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection(VocabularyCard item, String languageCode, {required bool isSource}) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        top: isSource ? 12.0 : 0.0,
        bottom: isSource ? 0.0 : 12.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                LanguageEmoji.getEmoji(languageCode),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  HtmlEntityDecoder.decode(item.translation),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: isSource ? FontWeight.w400 : FontWeight.w600,
                    fontStyle: isSource ? FontStyle.italic : FontStyle.normal,
                    color: isSource 
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                        : null,
                  ),
                ),
              ),
              if (item.gender != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSource
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.gender!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSource
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              HtmlEntityDecoder.decode(item.description),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: isSource ? 0.5 : 0.7,
                ),
              ),
            ),
          ],
          if (item.ipa != null && item.ipa!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '/${item.ipa}/',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: isSource ? 0.4 : 0.6,
                ),
              ),
            ),
          ],
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              HtmlEntityDecoder.decode(item.notes!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: isSource ? 0.4 : 0.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditDialog(PairedVocabularyItem item) async {
    final sourceController = TextEditingController(
      text: item.sourceCard?.translation ?? '',
    );
    final targetController = TextEditingController(
      text: item.targetCard?.translation ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Translation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.sourceCard != null && _sourceLanguageCode != null) ...[
                Text(
                  '${LanguageEmoji.getEmoji(_sourceLanguageCode!)} Source (${_sourceLanguageCode!.toUpperCase()})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    hintText: 'Enter source translation',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (item.targetCard != null && _targetLanguageCode != null) ...[
                Text(
                  '${LanguageEmoji.getEmoji(_targetLanguageCode!)} Target (${_targetLanguageCode!.toUpperCase()})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    hintText: 'Enter target translation',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop({
                'source': sourceController.text.trim(),
                'target': targetController.text.trim(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateItem(item, result['source'], result['target']);
    }
  }

  Future<void> _updateItem(
    PairedVocabularyItem item,
    String? sourceTranslation,
    String? targetTranslation,
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] as String? ?? 'Failed to update source card'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return;
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] as String? ?? 'Failed to update target card'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          return;
        }
      }

      // Reload vocabulary to show updated data
      await _loadUserAndVocabulary(reset: true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Translation updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating translation: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(PairedVocabularyItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Translation'),
        content: const Text(
          'Are you sure you want to delete this translation? '
          'This will delete all translations and the related concept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await VocabularyService.deleteConcept(
          conceptId: item.conceptId,
        );

        if (result['success'] == true) {
          // Reload vocabulary to reflect deletion
          await _loadUserAndVocabulary(reset: true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Translation deleted successfully'),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] as String? ?? 'Failed to delete translation'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting translation: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}

