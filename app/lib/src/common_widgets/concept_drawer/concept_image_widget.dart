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
  bool _isLoadingCamera = false;
  bool _isLoadingGallery = false;
  bool _showButtons = false;
  int _imageReloadKey = 0; // Key to force image reload when updated
  String _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString(); // Timestamp that updates on image change
  final ImagePicker _imagePicker = ImagePicker();

  String? _previousImageUrl;

  @override
  void didUpdateWidget(ConceptImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the image URL changed, force a reload
    final currentImageUrl = widget.item.imageUrl ?? widget.item.imagePath1;
    if (currentImageUrl != _previousImageUrl && currentImageUrl != null) {
      setState(() {
        _imageReloadKey++;
        _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
        _previousImageUrl = currentImageUrl;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _previousImageUrl = widget.item.imageUrl ?? widget.item.imagePath1;
  }

  /// Get the primary image URL from the item with cache-busting
  String? get _primaryImageUrl {
    // Use image_url or fallback to image_path_1 (for backward compatibility)
    final imageUrl = widget.item.imageUrl ?? widget.item.imagePath1;
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    
    // Build base URL
    String baseUrl;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      baseUrl = imageUrl;
    } else {
      // Otherwise, prepend the API base URL
      final cleanUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
      baseUrl = '${ApiConfig.baseUrl}/$cleanUrl';
    }
    
    // Add cache-busting timestamp parameter (only updates when image changes)
    final uri = Uri.parse(baseUrl);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      't': _cacheBustTimestamp,
    }).toString();
  }

  Future<void> _generateImage() async {
    if (_isGenerating || _isLoadingCamera || _isLoadingGallery) return;
    
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
        // Force image reload by updating the key and cache-bust timestamp
        if (mounted) {
          setState(() {
            _imageReloadKey++;
            _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
            _showButtons = false;
          });
        }
        // Don't trigger full drawer reload - just update the image URL locally
        // The image will reload automatically due to the key change and cache-busting
        
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
    if (_isLoadingGallery || _isLoadingCamera || _isGenerating) return;
    
    try {
      // Pick image from gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image == null) {
        // User cancelled image picker
        return;
      }
      
      setState(() {
        _isLoadingGallery = true;
      });

      // Upload the selected image
      final uploadResult = await FlashcardService.uploadConceptImage(
        conceptId: widget.item.conceptId,
        imageFile: File(image.path),
      );

      if (!mounted) return;

      if (uploadResult['success'] == true) {
        // Force image reload by updating the key and cache-bust timestamp
        if (mounted) {
          setState(() {
            _imageReloadKey++;
            _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
            _showButtons = false;
          });
        }
        // Don't trigger full drawer reload - just update the image URL locally
        // The image will reload automatically due to the key change and cache-busting
        
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
          _isLoadingGallery = false;
        });
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (_isLoadingCamera || _isLoadingGallery || _isGenerating) return;
    
    try {
      // Pick image from camera
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image == null) {
        // User cancelled image picker
        return;
      }
      
      setState(() {
        _isLoadingCamera = true;
      });

      // Upload the selected image
      final uploadResult = await FlashcardService.uploadConceptImage(
        conceptId: widget.item.conceptId,
        imageFile: File(image.path),
      );

      if (!mounted) return;

      if (uploadResult['success'] == true) {
        // Force image reload by updating the key and cache-bust timestamp
        if (mounted) {
          setState(() {
            _imageReloadKey++;
            _cacheBustTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
            _showButtons = false;
          });
        }
        // Don't trigger full drawer reload - just update the image URL locally
        // The image will reload automatically due to the key change and cache-busting
        
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
          _isLoadingCamera = false;
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
                  key: ValueKey('${widget.item.conceptId}_${widget.item.imageUrl}_$_imageReloadKey'),
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
                      onTap: (_isLoadingGallery || _isLoadingCamera || _isGenerating) ? null : _reloadFromLibrary,
                      isLoading: _isLoadingGallery,
                    ),
                    const SizedBox(width: 8),
                    // Camera button
                    _buildOverlayButton(
                      icon: Icons.camera_alt,
                      onTap: (_isLoadingCamera || _isLoadingGallery || _isGenerating) ? null : _pickImageFromCamera,
                      isLoading: _isLoadingCamera,
                    ),
                    const SizedBox(width: 8),
                    // Generate button
                    _buildOverlayButton(
                      icon: Icons.auto_awesome,
                      onTap: (_isGenerating || _isLoadingCamera || _isLoadingGallery) ? null : _generateImage,
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
            child: (_isLoadingCamera || _isLoadingGallery)
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
                  onTap: (_isLoadingGallery || _isLoadingCamera || _isGenerating) ? null : _reloadFromLibrary,
                  isLoading: _isLoadingGallery,
                ),
                const SizedBox(width: 8),
                // Camera button
                _buildOverlayButton(
                  icon: Icons.camera_alt,
                  onTap: (_isLoadingCamera || _isLoadingGallery || _isGenerating) ? null : _pickImageFromCamera,
                  isLoading: _isLoadingCamera,
                ),
                const SizedBox(width: 8),
                // Generate button
                _buildOverlayButton(
                  icon: Icons.auto_awesome,
                  onTap: (_isGenerating || _isLoadingCamera || _isLoadingGallery) ? null : _generateImage,
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