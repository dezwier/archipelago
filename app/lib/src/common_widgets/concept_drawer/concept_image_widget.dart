import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/create/data/flashcard_service.dart';

class ConceptImageWidget extends StatefulWidget {
  final PairedDictionaryItem item;
  final Function(PairedDictionaryItem)? onItemUpdated;
  final double? size;
  final bool showEditButtons;
  final VoidCallback? onEditButtonsChanged;

  const ConceptImageWidget({
    super.key,
    required this.item,
    this.onItemUpdated,
    this.size,
    this.showEditButtons = false,
    this.onEditButtonsChanged,
  });

  @override
  State<ConceptImageWidget> createState() => _ConceptImageWidgetState();
}

class _ConceptImageWidgetState extends State<ConceptImageWidget> {
  bool _isGenerating = false;
  bool _isReloading = false;
  bool _showButtons = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Cache the computed image URL to avoid recomputation on every build
  String? _cachedImageUrl;
  String? _cachedRawImageUrl; // Track the raw image URL to detect changes

  /// Get the primary image URL from the item (cached)
  String? get _primaryImageUrl {
    // Use image_url or fallback to image_path_1 (for backward compatibility)
    final imageUrl = widget.item.imageUrl ?? widget.item.imagePath1;
    
    // Return cached value if the raw image URL hasn't changed
    if (_cachedImageUrl != null && _cachedRawImageUrl == imageUrl) {
      return _cachedImageUrl!.isEmpty ? null : _cachedImageUrl;
    }
    
    // Cache the raw URL for comparison
    _cachedRawImageUrl = imageUrl;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      _cachedImageUrl = '';
      return null;
    }
    
    // If URL is already absolute, return as-is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      _cachedImageUrl = imageUrl;
      return imageUrl;
    }
    
    // Otherwise, prepend the API base URL
    // Remove leading slash if present to avoid double slashes
    final cleanUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    _cachedImageUrl = '${ApiConfig.baseUrl}/$cleanUrl';
    return _cachedImageUrl;
  }

  Future<void> _generateImage() async {
    if (_isGenerating) return;
    
    setState(() {
      _isGenerating = true;
    });

    try {
      // Get concept data
      final term = widget.item.conceptTerm ?? widget.item.sourceCard?.translation ?? '';
      if (term.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Concept term is missing'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final description = widget.item.conceptDescription;
      final topicId = widget.item.topicId;
      final topicDescription = widget.item.topicDescription;

      // Call the image generation endpoint
      final url = Uri.parse('${ApiConfig.apiBaseUrl}/concept-image/generate');
      
      final requestBody = <String, dynamic>{
        'concept_id': widget.item.conceptId,
        'term': term,
      };
      
      if (description != null && description.isNotEmpty) {
        requestBody['description'] = description;
      }
      
      if (topicId != null) {
        requestBody['topic_id'] = topicId;
      }
      
      if (topicDescription != null && topicDescription.isNotEmpty) {
        requestBody['topic_description'] = topicDescription;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Clear image cache to force reload of new image
        setState(() {
          _cachedImageUrl = null;
          _cachedRawImageUrl = null;
        });
        // Image generated successfully - refresh the item
        widget.onItemUpdated?.call(widget.item);
        // Hide edit buttons after successful generation
        if (mounted) {
          setState(() {
            _showButtons = false;
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Parse error response
        String errorMessage = 'Failed to generate image';
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = error['detail'] as String? ?? errorMessage;
        } catch (_) {
          errorMessage = 'Failed to generate image: ${response.statusCode}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _reloadFromLibrary() async {
    if (_isReloading) return;
    
    try {
      // Pick image from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Maximum quality
      );
      
      if (image == null) {
        // User cancelled image picker
        return;
      }
      
      setState(() {
        _isReloading = true;
      });

      // Upload the selected image
      final uploadResult = await FlashcardService.uploadConceptImage(
        conceptId: widget.item.conceptId,
        imageFile: File(image.path),
      );

      if (!mounted) return;

      if (uploadResult['success'] == true) {
        // Clear image cache to force reload of new image
        setState(() {
          _cachedImageUrl = null;
          _cachedRawImageUrl = null;
        });
        // Image uploaded successfully - refresh the item
        widget.onItemUpdated?.call(widget.item);
        // Hide edit buttons after successful upload
        if (mounted) {
          setState(() {
            _showButtons = false;
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMessage = uploadResult['message'] as String? ?? 'Failed to upload image';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking/uploading image: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReloading = false;
        });
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (_isReloading) return;
    
    try {
      // Pick image from camera
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Maximum quality
      );
      
      if (image == null) {
        // User cancelled image picker
        return;
      }
      
      setState(() {
        _isReloading = true;
      });

      // Upload the selected image
      final uploadResult = await FlashcardService.uploadConceptImage(
        conceptId: widget.item.conceptId,
        imageFile: File(image.path),
      );

      if (!mounted) return;

      if (uploadResult['success'] == true) {
        // Clear image cache to force reload of new image
        setState(() {
          _cachedImageUrl = null;
          _cachedRawImageUrl = null;
        });
        // Image uploaded successfully - refresh the item
        widget.onItemUpdated?.call(widget.item);
        // Hide edit buttons after successful upload
        if (mounted) {
          setState(() {
            _showButtons = false;
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMessage = uploadResult['message'] as String? ?? 'Failed to upload image';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Failed to capture image';
      if (e.toString().contains('permission') || e.toString().contains('Permission')) {
        errorMessage = 'Camera permission denied. Please enable camera access in settings.';
      } else if (e.toString().contains('camera') || e.toString().contains('Camera')) {
        errorMessage = 'Camera not available. Please check your device settings.';
      } else {
        errorMessage = 'Error capturing/uploading image: ${e.toString()}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReloading = false;
        });
      }
    }
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    final isDisabled = onTap == null || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: isDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDisabled 
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  icon,
                  color: isDisabled 
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white,
                  size: 18,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? 185.0;
    final imageUrl = _primaryImageUrl;
    final shouldShowButtons = imageUrl == null || imageUrl.isEmpty || _showButtons;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // Show the image
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showButtons = !_showButtons;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  // Use 2x resolution for retina displays, or remove cache constraints for full quality
                  cacheWidth: (size * 2).toInt(),
                  cacheHeight: (size * 2).toInt(),
                  filterQuality: FilterQuality.high,
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
            ),
            // Edit buttons overlay at top right (shown when tapped or no image)
            if (shouldShowButtons)
              Positioned(
                top: 8,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gallery button
                    _buildOverlayButton(
                      icon: Icons.photo_library,
                      onTap: _isReloading ? null : _reloadFromLibrary,
                      isLoading: _isReloading,
                    ),
                    const SizedBox(width: 8),
                    // Camera button
                    _buildOverlayButton(
                      icon: Icons.camera_alt,
                      onTap: _isReloading ? null : _pickImageFromCamera,
                      isLoading: _isReloading,
                    ),
                    const SizedBox(width: 8),
                    // Generate button
                    _buildOverlayButton(
                      icon: Icons.auto_awesome,
                      onTap: _isGenerating ? null : _generateImage,
                      isLoading: _isGenerating,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    // Show placeholder with buttons at top right
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                width: 1,
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: _isReloading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
          // Buttons at top right
          Positioned(
            top: 8,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gallery button
                _buildOverlayButton(
                  icon: Icons.photo_library,
                  onTap: _isReloading ? null : _reloadFromLibrary,
                  isLoading: _isReloading,
                ),
                const SizedBox(width: 8),
                // Camera button
                _buildOverlayButton(
                  icon: Icons.camera_alt,
                  onTap: _isReloading ? null : _pickImageFromCamera,
                  isLoading: _isReloading,
                ),
                const SizedBox(width: 8),
                // Generate button
                _buildOverlayButton(
                  icon: Icons.auto_awesome,
                  onTap: _isGenerating ? null : _generateImage,
                  isLoading: _isGenerating,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
