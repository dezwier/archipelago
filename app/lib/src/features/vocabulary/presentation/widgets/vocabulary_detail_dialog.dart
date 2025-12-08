import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../domain/paired_vocabulary_item.dart';
import '../../domain/vocabulary_card.dart';
import '../../../../constants/api_config.dart';
import '../../data/vocabulary_service.dart';
import 'language_lemma_widget.dart';

class VocabularyDetailDrawer extends StatefulWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final Map<String, bool> languageVisibility;
  final List<String> languagesToShow;
  final VoidCallback? onEdit;
  final VoidCallback? onRandomCard;
  final VoidCallback? onRefreshImages;
  final Function(PairedVocabularyItem)? onItemUpdated;

  const VocabularyDetailDrawer({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    required this.languageVisibility,
    required this.languagesToShow,
    this.onEdit,
    this.onRandomCard,
    this.onRefreshImages,
    this.onItemUpdated,
  });

  @override
  State<VocabularyDetailDrawer> createState() => _VocabularyDetailDrawerState();
}

class _VocabularyDetailDrawerState extends State<VocabularyDetailDrawer> {
  bool _isPlayingAudio = false;
  bool _isEditing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late TextEditingController _sourceTranslationController;
  late TextEditingController _targetTranslationController;

  List<String?> get _imageUrls {
    return [
      widget.item.imagePath1,
      widget.item.imagePath2,
      widget.item.imagePath3,
      widget.item.imagePath4,
    ];
  }

  @override
  void initState() {
    super.initState();
    _sourceTranslationController = TextEditingController(
      text: widget.item.sourceCard?.translation ?? '',
    );
    _targetTranslationController = TextEditingController(
      text: widget.item.targetCard?.translation ?? '',
    );
  }

  String? _getFullAudioUrl(String? audioPath) {
    if (audioPath == null || audioPath.isEmpty) return null;
    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      return audioPath;
    }
    return '${ApiConfig.baseUrl}$audioPath';
  }

  Future<void> _handleSave() async {
    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      bool hasChanges = false;

      // Update source card if it exists and translation changed
      if (widget.item.sourceCard != null) {
        final newTranslation = _sourceTranslationController.text.trim();
        if (newTranslation.isNotEmpty && newTranslation != widget.item.sourceCard!.translation) {
          final result = await VocabularyService.updateCard(
            cardId: widget.item.sourceCard!.id,
            translation: newTranslation,
          );
          
          if (result['success'] != true) {
            if (!mounted) return;
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] as String? ?? 'Failed to update source card'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }
          hasChanges = true;
        }
      }

      // Update target card if it exists and translation changed
      if (widget.item.targetCard != null) {
        final newTranslation = _targetTranslationController.text.trim();
        if (newTranslation.isNotEmpty && newTranslation != widget.item.targetCard!.translation) {
          final result = await VocabularyService.updateCard(
            cardId: widget.item.targetCard!.id,
            translation: newTranslation,
          );
          
          if (result['success'] != true) {
            if (!mounted) return;
            Navigator.of(context).pop(); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] as String? ?? 'Failed to update target card'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }
          hasChanges = true;
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (hasChanges) {
        // Notify parent to refresh the item
        widget.onItemUpdated?.call(widget.item);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }

      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _handleCancel() {
    setState(() {
      _isEditing = false;
      // Reset controllers to original values
      _sourceTranslationController.text = widget.item.sourceCard?.translation ?? '';
      _targetTranslationController.text = widget.item.targetCard?.translation ?? '';
    });
  }

  Future<void> _playAudio(VocabularyCard? card) async {
    if (card == null || card.audioPath == null || card.audioPath!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio available')),
        );
      }
      return;
    }

    setState(() {
      _isPlayingAudio = true;
    });

    try {
      final audioUrl = _getFullAudioUrl(card.audioPath);
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
        // Listen for completion
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
            });
          }
        });
      } else {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    } catch (e) {
      setState(() {
        _isPlayingAudio = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _sourceTranslationController.dispose();
    _targetTranslationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            // Images on top, buttons below
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Images on top
                  _buildImageSection(context),
                  const SizedBox(height: 12),
                  // Action buttons horizontally below
                  _buildActionButtons(context),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildLanguageSections(context),
                    if (widget.item.conceptTerm != null || 
                        widget.item.conceptDescription != null) ...[
                      const SizedBox(height: 24),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      _buildConceptInfo(context),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (_isEditing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Save button
          IconButton(
            onPressed: _handleSave,
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          // Cancel button
          IconButton(
            onPressed: _handleCancel,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit button
        IconButton(
          onPressed: () {
            setState(() {
              _isEditing = true;
              // Reset controllers to current values
              _sourceTranslationController.text = widget.item.sourceCard?.translation ?? '';
              _targetTranslationController.text = widget.item.targetCard?.translation ?? '';
            });
          },
          icon: const Icon(Icons.edit),
          tooltip: 'Edit',
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(12),
          ),
        ),
        // Play button
        IconButton(
          onPressed: _isPlayingAudio
              ? null
              : () {
                  // Play audio for target card if available, otherwise source
                  final cardToPlay = widget.item.targetCard ?? widget.item.sourceCard;
                  _playAudio(cardToPlay);
                },
          icon: _isPlayingAudio
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.volume_up),
          tooltip: 'Play',
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(12),
          ),
        ),
        // Refresh images button
        IconButton(
          onPressed: widget.onRefreshImages,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Images',
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(12),
          ),
        ),
        // Random card button
        IconButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onRandomCard?.call();
          },
          icon: const Icon(Icons.shuffle),
          tooltip: 'Random Card',
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context) {
    // When editing, always show all images; otherwise show single image
    return _isEditing ? _buildImageGrid(context) : _buildSingleImage(context);
  }

  Widget _buildSingleImage(BuildContext context) {
    final firstImageUrl = _imageUrls[0];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 70% of available width, make it square
        final size = constraints.maxWidth * 0.9;
        
        if (firstImageUrl == null || firstImageUrl.isEmpty) {
          return Center(
            child: SizedBox(
              width: size,
              height: size,
              child: _buildEmptySlot(context),
            ),
          );
        }

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: _buildImage(context, firstImageUrl, 1, showDeleteButton: false),
          ),
        );
      },
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final images = _imageUrls;
    final gridSpacing = 8.0; // Spacing between grid items
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use available width for grid
        final availableWidth = constraints.maxWidth;
        final itemSize = (availableWidth - gridSpacing) / 2;
        
        return SizedBox(
          height: itemSize * 2 + gridSpacing, // 2 rows with spacing
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: 1,
            ),
            itemCount: 4, // Always show 4 slots
            itemBuilder: (context, index) {
              final imageUrl = images[index];
              if (imageUrl == null || imageUrl.isEmpty) {
                // In edit mode, make empty slots editable
                if (_isEditing) {
                  return _buildEditableEmptySlot(context, index + 1);
                }
                return _buildEmptySlot(context); // Empty slot placeholder
              }
              return _buildImage(context, imageUrl, index + 1);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildEditableEmptySlot(BuildContext context, int imageIndex) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: 2,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Center(
            child: Icon(
              Icons.add_photo_alternate,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              size: 32,
            ),
          ),
        ),
        // Edit button in center
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleEditImage(context, imageIndex, null),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(BuildContext context, String url, int imageIndex, {bool showDeleteButton = true}) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 24,
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
          ),
        ),
        // Action buttons in top-right corner (only if showDeleteButton is true)
        if (showDeleteButton)
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Edit button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleEditImage(context, imageIndex, url),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Delete button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleDeleteImage(context, imageIndex),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleDeleteImage(BuildContext context, int imageIndex) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await VocabularyService.deleteConceptImage(
        conceptId: widget.item.conceptId,
        imageIndex: imageIndex,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true) {
        // Notify parent to refresh the item
        widget.onItemUpdated?.call(widget.item);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] as String? ?? 'Image deleted successfully',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] as String? ?? 'Failed to delete image',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleEditImage(BuildContext context, int imageIndex, String? currentUrl) async {
    final controller = TextEditingController(text: currentUrl ?? '');
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Image ${imageIndex}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Image URL',
            hintText: 'Enter image URL',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop({'cancelled': true}),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop({
              'url': controller.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result['cancelled'] == true) return;

    final newUrl = result['url'] as String? ?? '';

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final updateResult = await VocabularyService.updateConceptImage(
        conceptId: widget.item.conceptId,
        imageIndex: imageIndex,
        imageUrl: newUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (updateResult['success'] == true) {
        // Notify parent to refresh the item
        widget.onItemUpdated?.call(widget.item);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updateResult['message'] as String? ?? 'Image updated successfully',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updateResult['message'] as String? ?? 'Failed to update image',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  List<Widget> _buildLanguageSections(BuildContext context) {
    // Filter visible cards and sort by the languagesToShow order
    final visibleCards = widget.item.cards
        .where((card) => widget.languageVisibility[card.languageCode] ?? true)
        .toList();
    
    // Sort cards according to the languagesToShow list order
    visibleCards.sort((a, b) {
      final indexA = widget.languagesToShow.indexOf(a.languageCode);
      final indexB = widget.languagesToShow.indexOf(b.languageCode);
      
      // If both are in the list, sort by their position
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      // If only one is in the list, prioritize it (shouldn't happen if visibility is synced)
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      // If neither is in the list, maintain original order (fallback)
      return 0;
    });
    
    final widgets = <Widget>[];
    for (int i = 0; i < visibleCards.length; i++) {
      final card = visibleCards[i];
      
      if (i > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        );
      }
      
      widgets.add(
        _buildLanguageSection(
          context,
          card: card,
          languageCode: card.languageCode,
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildLanguageSection(
    BuildContext context, {
    required VocabularyCard card,
    required String languageCode,
  }) {
    // Check if this card is the source or target card (only these can be edited)
    final isSourceCard = widget.item.sourceCard?.id == card.id;
    final isTargetCard = widget.item.targetCard?.id == card.id;
    final isEditableCard = isSourceCard || isTargetCard;
    
    // Get the appropriate controller for editing
    final controller = isSourceCard ? _sourceTranslationController : 
                      (isTargetCard ? _targetTranslationController : null);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LanguageLemmaWidget(
          card: card,
          languageCode: languageCode,
          showDescription: true,
          translationController: _isEditing && isEditableCard ? controller : null,
          isEditing: _isEditing && isEditableCard,
          partOfSpeech: widget.item.partOfSpeech,
        ),
        // Notes
        if (card.notes != null && card.notes!.isNotEmpty && !_isEditing) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    HtmlEntityDecoder.decode(card.notes!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConceptInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Concept Information',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.item.conceptTerm != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Term: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.item.conceptTerm!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (widget.item.conceptDescription != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.item.conceptDescription!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Concept ID: ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                widget.item.conceptId.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
