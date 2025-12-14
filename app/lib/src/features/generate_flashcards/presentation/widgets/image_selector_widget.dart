import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../data/flashcard_service.dart';

class ImageSelectorWidget extends StatefulWidget {
  final File? initialImage;
  final ValueChanged<File?>? onImageChanged;
  final String? term;
  final String? description;
  final String? topicDescription;

  const ImageSelectorWidget({
    super.key,
    this.initialImage,
    this.onImageChanged,
    this.term,
    this.description,
    this.topicDescription,
  });

  @override
  State<ImageSelectorWidget> createState() => _ImageSelectorWidgetState();
}

class _ImageSelectorWidgetState extends State<ImageSelectorWidget> {
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isGeneratingImage = false;

  @override
  void initState() {
    super.initState();
    _selectedImage = widget.initialImage;
  }

  @override
  void didUpdateWidget(ImageSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImage != oldWidget.initialImage) {
      _selectedImage = widget.initialImage;
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        widget.onImageChanged?.call(_selectedImage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        widget.onImageChanged?.call(_selectedImage);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to capture image';
        if (e.toString().contains('permission') || e.toString().contains('Permission')) {
          errorMessage = 'Camera permission denied. Please enable camera access in settings.';
        } else if (e.toString().contains('camera') || e.toString().contains('Camera')) {
          errorMessage = 'Camera not available. Please check your device settings.';
        } else {
          errorMessage = 'Failed to capture image: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
    widget.onImageChanged?.call(null);
  }

  Future<void> _generateImageWithGemini() async {
    // Check if term exists
    final term = widget.term?.trim();
    if (term == null || term.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a word or phrase first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isGeneratingImage = true;
    });

    try {
      final result = await FlashcardService.generateImagePreview(
        term: term,
        description: widget.description?.trim().isNotEmpty == true 
            ? widget.description!.trim() 
            : null,
        topicDescription: widget.topicDescription?.trim().isNotEmpty == true
            ? widget.topicDescription!.trim()
            : null,
      );

      if (mounted) {
        if (result['success'] == true && result['data'] != null) {
          final generatedImage = result['data'] as File;
          setState(() {
            _selectedImage = generatedImage;
          });
          widget.onImageChanged?.call(generatedImage);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image generated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String? ?? 'Failed to generate image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingImage = false;
        });
      }
    }
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
    bool isEnabled = true,
    bool isLoading = false,
  }) {
    final isDisabled = !isEnabled || onTap == null || isLoading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isDisabled ? null : onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDisabled 
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 185.0,
      height: 185.0,
      child: Stack(
        children: [
          // Image or placeholder
          _selectedImage != null
              ? Container(
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
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
          // Buttons overlay at top right
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _selectedImage == null
                  ? [
                      // Gallery button
                      _buildOverlayButton(
                        icon: Icons.photo_library,
                        onTap: _pickImageFromGallery,
                        tooltip: 'Gallery',
                      ),
                      const SizedBox(width: 4),
                      // Camera button
                      _buildOverlayButton(
                        icon: Icons.camera_alt,
                        onTap: _pickImageFromCamera,
                        tooltip: 'Camera',
                      ),
                      const SizedBox(width: 4),
                      // Gemini generate button
                      _buildOverlayButton(
                        icon: Icons.auto_awesome,
                        onTap: _isGeneratingImage ? null : _generateImageWithGemini,
                        tooltip: (widget.term?.trim().isEmpty ?? true) 
                            ? 'Enter a word or phrase first'
                            : 'Generate with Gemini',
                        isEnabled: (widget.term?.trim().isNotEmpty ?? false) && !_isGeneratingImage,
                        isLoading: _isGeneratingImage,
                      ),
                    ]
                  : [
                      // Discard button
                      _buildOverlayButton(
                        icon: Icons.close,
                        onTap: _removeSelectedImage,
                        tooltip: 'Discard',
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

