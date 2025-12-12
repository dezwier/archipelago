import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../data/topic_service.dart' show Topic, TopicService;
import '../../data/flashcard_service.dart';
import '../../../profile/domain/user.dart';
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
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserId();
    
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

  @override
  void dispose() {
    _termController.dispose();
    _descriptionController.dispose();
    _termFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    // If image is already selected, remove it
    if (_selectedImage != null) {
      _removeSelectedImage();
      return;
    }
    
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

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
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
        });
        _loadTopics();
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
      });
      
      final result = await FlashcardService.createConceptOnly(
        term: term,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        topicId: _selectedTopic?.id,
        userId: _userId,
      );
      
      if (result['success'] == true) {
        final conceptData = result['data'] as Map<String, dynamic>?;
        final conceptId = conceptData?['id'] as int?;
        
        // If image is provided and concept was created, upload the image
        if (_selectedImage != null && conceptId != null) {
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
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concept created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear form after successful creation
        _termController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedImage = null;
        });
        // Keep the selected topic (don't reset it)
      } else {
        setState(() {
          _isCreatingConcept = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              // Term field
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
                  labelText: 'Term',
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

              // Image selector and Topic selector on same line
              Row(
                children: [
                  // Image selector button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: Icon(
                        _selectedImage != null ? Icons.check_circle : Icons.image_outlined,
                        color: _selectedImage != null 
                            ? Theme.of(context).colorScheme.primary 
                            : null,
                      ),
                      label: Text(
                        _selectedImage != null ? 'Image Selected' : 'Select Image',
                        style: TextStyle(
                          color: _selectedImage != null 
                              ? Theme.of(context).colorScheme.primary 
                              : null,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _selectedImage != null
                                ? Theme.of(context).colorScheme.primary
                                : (Theme.of(context).brightness == Brightness.light
                                    ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Topic selector button
                  Expanded(
                    child: _isLoadingTopics
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
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Create Concept button - full width
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
            ],
          ),
        ),
      ],
    );
  }
}


