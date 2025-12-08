import 'package:flutter/material.dart';
import '../../data/vocabulary_service.dart';
import '../../domain/paired_vocabulary_item.dart';

class VocabularyImageSection extends StatelessWidget {
  final PairedVocabularyItem item;
  final bool isEditing;
  final Function(PairedVocabularyItem)? onItemUpdated;

  const VocabularyImageSection({
    super.key,
    required this.item,
    required this.isEditing,
    this.onItemUpdated,
  });

  List<String?> get _imageUrls {
    return [
      item.imagePath1,
      item.imagePath2,
      item.imagePath3,
      item.imagePath4,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return isEditing ? _buildImageGrid(context) : _buildSingleImage(context);
  }

  Widget _buildSingleImage(BuildContext context) {
    final firstImageUrl = _imageUrls[0];
    const size = 185.0; // Fixed smaller size
    
    if (firstImageUrl == null || firstImageUrl.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: _buildEmptySlot(context),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: _buildImage(context, firstImageUrl, 1, showDeleteButton: false),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final images = _imageUrls;
    final gridSpacing = 8.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final itemSize = (availableWidth - gridSpacing) / 2;
        
        return SizedBox(
          height: itemSize * 2 + gridSpacing,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: 1,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final imageUrl = images[index];
              if (imageUrl == null || imageUrl.isEmpty) {
                return _buildEditableEmptySlot(context, index + 1);
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
        if (showDeleteButton)
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await VocabularyService.deleteConceptImage(
        conceptId: item.conceptId,
        imageIndex: imageIndex,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (result['success'] == true) {
        onItemUpdated?.call(item);
        
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
      if (!context.mounted) return;
      Navigator.of(context).pop();
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

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final updateResult = await VocabularyService.updateConceptImage(
        conceptId: item.conceptId,
        imageIndex: imageIndex,
        imageUrl: newUrl,
      );

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (updateResult['success'] == true) {
        onItemUpdated?.call(item);
        
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
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

