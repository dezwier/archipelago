import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../data/topic_service.dart' show Topic, TopicService;
import '../../data/flashcard_service.dart';
import '../../../profile/domain/user.dart';
import '../../../profile/domain/language.dart';
import '../../../profile/data/language_service.dart';
import '../../../../common_widgets/language_selection_widget.dart';
import '../../../../utils/language_emoji.dart';
import 'topic_drawer.dart';

class CreateConceptSection extends StatefulWidget {
  const CreateConceptSection({super.key});

  @override
  State<CreateConceptSection> createState() => _CreateConceptSectionState();
}

class _CreateConceptSectionState extends State<CreateConceptSection> {
  final _formKey = GlobalKey<FormState>();
  final _termController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  
  List<Topic> _topics = [];
  bool _isCreatingConcept = false;
  bool _isLoadingTopics = false;
  Topic? _selectedTopic;
  int? _userId;
  User? _currentUser;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  List<Language> _languages = [];
  bool _isLoadingLanguages = false;
  List<String> _selectedLanguages = [];
  String? _statusMessage;
  Map<String, bool> _languageStatus = {}; // Track which languages have completed
  bool _hasSetDefaultLanguages = false; // Track if defaults have been set

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadLanguages();
    
    // Prevent fields from requesting focus automatically
    _termFocusNode.canRequestFocus = false;
    _descriptionFocusNode.canRequestFocus = false;
    
    // Reset canRequestFocus when focus is lost
    _termFocusNode.addListener(() {
      if (!_termFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_termFocusNode.hasFocus) {
            _termFocusNode.canRequestFocus = false;
          }
        });
      }
    });
    _descriptionFocusNode.addListener(() {
      if (!_descriptionFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_descriptionFocusNode.hasFocus) {
            _descriptionFocusNode.canRequestFocus = false;
          }
        });
      }
    });
  }

  void _setDefaultLanguages() {
    // Only set defaults once, and only if we have both user and languages loaded
    if (_hasSetDefaultLanguages || _currentUser == null || _languages.isEmpty) {
      return;
    }

    final defaultLanguages = <String>[];
    
    // Add native language if it exists in available languages
    if (_currentUser!.langNative.isNotEmpty) {
      final nativeLangExists = _languages.any((lang) => lang.code == _currentUser!.langNative);
      if (nativeLangExists) {
        defaultLanguages.add(_currentUser!.langNative);
      }
    }
    
    // Add learning language if it exists in available languages
    if (_currentUser!.langLearning != null && _currentUser!.langLearning!.isNotEmpty) {
      final learningLangExists = _languages.any((lang) => lang.code == _currentUser!.langLearning);
      if (learningLangExists) {
        defaultLanguages.add(_currentUser!.langLearning!);
      }
    }
    
    if (defaultLanguages.isNotEmpty) {
      setState(() {
        _selectedLanguages = defaultLanguages;
        _hasSetDefaultLanguages = true;
      });
    }
  }

  Future<void> _loadLanguages() async {
    setState(() {
      _isLoadingLanguages = true;
    });

    final languages = await LanguageService.getLanguages();
    
    setState(() {
      _languages = languages;
      _isLoadingLanguages = false;
    });
    
    // Set default languages after loading
    _setDefaultLanguages();
  }

  @override
  void dispose() {
    _termController.dispose();
    _descriptionController.dispose();
    _termFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
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
  }

  Widget _buildSmallIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    const double buttonWidth = 36.0;
    const double iconSize = 18.0;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: buttonWidth,
            height: buttonWidth,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: onPressed == null
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        setState(() {
          _userId = user.id;
          _currentUser = user;
        });
        _loadTopics();
        // Set default languages after loading user
        _setDefaultLanguages();
      }
    } catch (e) {
      // If loading user fails, still try to load topics without filter
      _loadTopics();
    }
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoadingTopics = true;
    });
    
    final topics = await TopicService.getTopics(userId: _userId);
    
    setState(() {
      _topics = topics;
      // Set the most recent topic as default (first in list since sorted by created_at desc)
      if (_topics.isNotEmpty && _selectedTopic == null) {
        _selectedTopic = _topics.first;
      }
      _isLoadingTopics = false;
    });
  }

  void _openTopicDrawer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Topic Selection',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return TopicDrawer(
          topics: _topics,
          initialSelectedTopic: _selectedTopic,
          userId: _userId,
          onTopicSelected: (Topic? topic) {
            setState(() {
              _selectedTopic = topic;
            });
          },
          onTopicCreated: () async {
            // Reload topics after creation
            await _loadTopics();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  Future<void> _handleCreateConcept() async {
    if (_formKey.currentState!.validate()) {
      // Validate term is not empty
      final term = _termController.text.trim();
      if (term.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a term'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        _isCreatingConcept = true;
        _statusMessage = 'Creating concept...';
        _languageStatus = {};
      });
      
      // Always create the concept first
      final createResult = await FlashcardService.createConceptOnly(
        term: term,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        topicId: _selectedTopic?.id,
        userId: _userId,
      );
      
      if (createResult['success'] != true) {
        setState(() {
          _isCreatingConcept = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(createResult['message'] as String),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Show concept created feedback
      setState(() {
        _statusMessage = 'Concept created ✓';
      });
      
      final conceptData = createResult['data'] as Map<String, dynamic>?;
      final conceptId = conceptData?['id'] as int?;
      
      if (conceptId == null) {
        setState(() {
          _isCreatingConcept = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concept created but ID is missing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // If languages are selected, generate lemmas for the created concept
      if (_selectedLanguages.isNotEmpty) {
        setState(() {
          _statusMessage = 'Generating lemmas...';
          // Initialize all languages as in progress
          for (final langCode in _selectedLanguages) {
            _languageStatus[langCode] = false;
          }
        });
        
        // Start generating lemmas
        final lemmaFuture = FlashcardService.generateCardsForConcepts(
          conceptIds: [conceptId],
          languages: _selectedLanguages,
        );
        
        // Simulate per-language progress updates
        for (int i = 0; i < _selectedLanguages.length; i++) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            setState(() {
              _languageStatus[_selectedLanguages[i]] = true;
            });
          }
        }
        
        final lemmaResult = await lemmaFuture;
        
        if (lemmaResult['success'] != true) {
          // Concept was created but lemma generation failed
          setState(() {
            _isCreatingConcept = false;
            _statusMessage = null;
            _languageStatus = {};
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Concept created but failed to generate lemmas: ${lemmaResult['message']}'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        
        // Ensure all languages are marked as completed
        setState(() {
          for (final langCode in _selectedLanguages) {
            _languageStatus[langCode] = true;
          }
          _statusMessage = 'All lemmas created ✓';
        });
        
        // Clear status after a short delay
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      
      // Success - concept created (and lemmas if languages were selected)
      // If image is provided and concept was created, upload the image
      if (_selectedImage != null) {
        final uploadResult = await FlashcardService.uploadConceptImage(
          conceptId: conceptId,
          imageFile: _selectedImage!,
        );
        
        if (uploadResult['success'] != true) {
          // Concept was created but image upload failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Concept created but image upload failed: ${uploadResult['message']}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      setState(() {
        _isCreatingConcept = false;
        _statusMessage = null;
        _languageStatus = {};
      });
      
      final successMessage = _selectedLanguages.isNotEmpty
          ? 'Concept created with lemmas in ${_selectedLanguages.length} language(s)!'
          : 'Concept created successfully!';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green,
        ),
      );
      // Clear form after successful creation
      _termController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedImage = null;
        _selectedLanguages = [];
      });
      // Keep the selected topic (don't reset it)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Create Concepts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image selector with preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Square image preview (same size as dictionary detail page)
                  SizedBox(
                    width: 185.0,
                    height: 185.0,
                    child: _selectedImage != null
                        ? Stack(
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
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Material(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    onTap: _removeSelectedImage,
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                  ),
                  const SizedBox(width: 12),
                  // Right side: Small Gallery and Camera buttons (matching dictionary action buttons style)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSmallIconButton(
                        context,
                        icon: Icons.photo_library_outlined,
                        tooltip: 'Gallery',
                        onPressed: _pickImageFromGallery,
                      ),
                      const SizedBox(height: 8),
                      _buildSmallIconButton(
                        context,
                        icon: Icons.camera_alt_outlined,
                        tooltip: 'Camera',
                        onPressed: _pickImageFromCamera,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Word or Phrase field
              TextFormField(
                controller: _termController,
                focusNode: _termFocusNode,
                autofocus: false,
                enabled: true,
                textCapitalization: TextCapitalization.sentences,
                onTap: () {
                  _termFocusNode.canRequestFocus = true;
                  _termFocusNode.requestFocus();
                },
                decoration: InputDecoration(
                  labelText: 'Word or Phrase',
                  hintText: 'Enter the word or phrase',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                minLines: 1,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a term';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Description field
              TextFormField(
                controller: _descriptionController,
                focusNode: _descriptionFocusNode,
                autofocus: false,
                enabled: true,
                textCapitalization: TextCapitalization.sentences,
                onTap: () {
                  _descriptionFocusNode.canRequestFocus = true;
                  _descriptionFocusNode.requestFocus();
                },
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Enter the core meaning in English (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                minLines: 1,
                maxLines: 5,
              ),
              const SizedBox(height: 12),

              // Topic selector
              _isLoadingTopics
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => _openTopicDrawer(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedTopic != null
                                  ? (_selectedTopic!.name.isNotEmpty
                                      ? _selectedTopic!.name[0].toUpperCase() + _selectedTopic!.name.substring(1)
                                      : _selectedTopic!.name)
                                  : 'Select Topic Island',
                              style: TextStyle(
                                color: _selectedTopic != null
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
              const SizedBox(height: 12),

              // Language selector
              LanguageSelectionWidget(
                languages: _languages,
                selectedLanguages: _selectedLanguages,
                isLoading: _isLoadingLanguages,
                onSelectionChanged: (List<String> selected) {
                  setState(() {
                    _selectedLanguages = selected;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Create Concept button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreatingConcept ? null : _handleCreateConcept,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isCreatingConcept
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Concept',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              
              // Status feedback
              if (_statusMessage != null || _languageStatus.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_statusMessage != null)
                        Row(
                          children: [
                            Icon(
                              _statusMessage!.contains('✓') 
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                              size: 16,
                              color: _statusMessage!.contains('✓')
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_languageStatus.isNotEmpty) ...[
                        if (_statusMessage != null) const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedLanguages.map((langCode) {
                            final isComplete = _languageStatus[langCode] ?? false;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  LanguageEmoji.getEmoji(langCode),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isComplete ? Icons.check : Icons.hourglass_empty,
                                  size: 14,
                                  color: isComplete
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


