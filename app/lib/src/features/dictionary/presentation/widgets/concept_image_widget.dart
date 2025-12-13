import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../domain/paired_dictionary_item.dart';
import '../../../../constants/api_config.dart';
import '../../../generate_flashcards/data/flashcard_service.dart';

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

  /// Get the primary image URL from the images array
  String? get _primaryImageUrl {
    if (widget.item.images == null || widget.item.images!.isEmpty) {
      return null;
    }
    
    // Find primary image
    final primaryImage = widget.item.images!.firstWhere(
      (img) => img['is_primary'] == true,
      orElse: () => widget.item.images!.first,
    );
    
    // Build full URL from the image URL
    final imageUrl = primaryImage['url'] as String?;
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    
    // Get created_at timestamp for cache-busting (if available)
    final createdAt = primaryImage['created_at'] as String?;
    String? cacheBust;
    if (createdAt != null) {
      try {
        // Parse ISO format timestamp and use milliseconds since epoch
        final dateTime = DateTime.parse(createdAt);
        cacheBust = dateTime.millisecondsSinceEpoch.toString();
      } catch (_) {
        // If parsing fails, use current time as fallback
        cacheBust = DateTime.now().millisecondsSinceEpoch.toString();
      }
    } else {
      cacheBust = DateTime.now().millisecondsSinceEpoch.toString();
    }
    
    // If URL is already absolute, add cache-busting parameter
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      final uri = Uri.parse(imageUrl);
      return uri.replace(queryParameters: {
        ...uri.queryParameters,
        't': cacheBust,
      }).toString();
    }
    
    // Otherwise, prepend the API base URL
    // Remove leading slash if present to avoid double slashes
    final cleanUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    final baseUrl = '${ApiConfig.baseUrl}/$cleanUrl';
    // Add cache-busting parameter
    final uri = Uri.parse(baseUrl);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      't': cacheBust,
    }).toString();
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
        imageQuality: 85,
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
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Generate button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isGenerating ? null : _generateImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Gallery button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isReloading ? null : _reloadFromLibrary,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: _isReloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_library,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
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
            child: (_isGenerating || _isReloading)
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
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Generate button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isGenerating ? null : _generateImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: _isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Gallery button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isReloading ? null : _reloadFromLibrary,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: _isReloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
