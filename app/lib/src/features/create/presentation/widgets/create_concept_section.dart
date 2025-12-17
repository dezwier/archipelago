import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:archipelago/src/features/create/data/topic_service.dart' show Topic, TopicService;
import 'package:archipelago/src/features/create/data/flashcard_service.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/profile/data/language_service.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'image_selector_widget.dart';
import 'create_selectors_widget.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_drawer.dart';

class CreateConceptSection extends StatefulWidget {
  final Function(Function())? onRefreshCallbackReady;
  
  const CreateConceptSection({
    super.key,
    this.onRefreshCallbackReady,
  });

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
  List<Language> _languages = [];
  bool _isLoadingLanguages = false;
  List<String> _selectedLanguages = [];
  String? _statusMessage;
  Map<String, bool> _languageStatus = {}; // Track which languages have completed
  bool _hasSetDefaultLanguages = false; // Track if defaults have been set

  @override
  void initState() {
    super.initState();
    _loadUserId().then((_) {
      _loadTopics();
    });
    _loadLanguages();
    
    // Register refresh callback with parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRefreshCallbackReady?.call(_loadTopics);
    });
    
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
    
    // Listen to text changes to update ImageSelectorWidget
    _termController.addListener(() {
      if (mounted) {
        setState(() {
          // Trigger rebuild to update ImageSelectorWidget with new term
        });
      }
    });
    _descriptionController.addListener(() {
      if (mounted) {
        setState(() {
          // Trigger rebuild to update ImageSelectorWidget with new description
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
        // Set default languages after loading user
        _setDefaultLanguages();
      } else {
        // User logged out
        setState(() {
          _userId = null;
          _currentUser = null;
        });
      }
    } catch (e) {
      // If loading user fails, clear user state
      setState(() {
        _userId = null;
        _currentUser = null;
      });
    }
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoadingTopics = true;
    });
    
    // Reload user ID in case login state changed
    await _loadUserId();
    
    final topics = await TopicService.getTopics(userId: _userId);
    
    setState(() {
      _topics = topics;
      // Clear selected topic if it's no longer in the available topics (e.g., private topic after logout)
      if (_selectedTopic != null && !topics.any((t) => t.id == _selectedTopic!.id)) {
        _selectedTopic = null;
      }
      // Set the most recent topic as default (first in list since sorted by created_at desc)
      if (_topics.isNotEmpty && _selectedTopic == null) {
        _selectedTopic = _topics.first;
      }
      _isLoadingTopics = false;
    });
  }


  Future<void> _handleCreateConcept() async {
    // Check if user is logged in
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create concepts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
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
      
      // Show the concept drawer with the newly created concept
      if (mounted) {
        // Build language visibility map - show all selected languages, plus English if available
        final languageVisibility = <String, bool>{};
        final languagesToShow = <String>[];
        
        // Add selected languages
        for (final langCode in _selectedLanguages) {
          languageVisibility[langCode] = true;
          languagesToShow.add(langCode);
        }
        
        // If no languages selected, show all available languages (or at least English)
        if (_selectedLanguages.isEmpty) {
          // Show all languages that might have been created
          // The drawer will fetch and show what's available
          languageVisibility['en'] = true;
          languagesToShow.add('en');
        }
        
        // Show the drawer after a short delay to let the snackbar appear first
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            showConceptDrawer(
              context,
              conceptId: conceptId,
              languageVisibility: languageVisibility.isNotEmpty ? languageVisibility : null,
              languagesToShow: languagesToShow.isNotEmpty ? languagesToShow : null,
            );
          }
        });
      }
      
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
              // Image selector with selectors on the right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image selector on the left
                  Expanded(
                    flex: 1,
                    child: ImageSelectorWidget(
                      initialImage: _selectedImage,
                      onImageChanged: (File? image) {
                        setState(() {
                          _selectedImage = image;
                        });
                      },
                      term: _termController.text.trim(),
                      description: _descriptionController.text.trim().isNotEmpty 
                          ? _descriptionController.text.trim() 
                          : null,
                      topicDescription: _selectedTopic?.description,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Selectors on the right
                  Expanded(
                    flex: 1,
                    child: CreateSelectorsWidget(
                      topics: _topics,
                      isLoadingTopics: _isLoadingTopics,
                      selectedTopic: _selectedTopic,
                      userId: _userId,
                      onTopicSelected: (Topic? topic) {
                        setState(() {
                          _selectedTopic = topic;
                        });
                      },
                      onTopicCreated: () async {
                        await _loadTopics();
                      },
                      languages: _languages,
                      isLoadingLanguages: _isLoadingLanguages,
                      selectedLanguages: _selectedLanguages,
                      onLanguageSelectionChanged: (List<String> selected) {
                        setState(() {
                          _selectedLanguages = selected;
                        });
                      },
                    ),
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
                  labelText: 'Concept',
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


