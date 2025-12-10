import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/topic_service.dart' show Topic, TopicService;
import '../../data/flashcard_service.dart';
import '../../../profile/domain/user.dart';

class CreateConceptSection extends StatefulWidget {
  const CreateConceptSection({super.key});

  @override
  State<CreateConceptSection> createState() => _CreateConceptSectionState();
}

class _CreateConceptSectionState extends State<CreateConceptSection> {
  final _formKey = GlobalKey<FormState>();
  final _termController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _topicController = TextEditingController();
  final _termFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _topicFocusNode = FocusNode();
  
  List<Topic> _topics = [];
  bool _isCreatingConcept = false;
  Topic? _selectedTopic;

  @override
  void initState() {
    super.initState();
    _loadTopics();
    
    // Prevent fields from requesting focus automatically
    _termFocusNode.canRequestFocus = false;
    _descriptionFocusNode.canRequestFocus = false;
    _topicFocusNode.canRequestFocus = false;
    
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
    _topicFocusNode.addListener(() {
      if (!_topicFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_topicFocusNode.hasFocus) {
            _topicFocusNode.canRequestFocus = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _termController.dispose();
    _descriptionController.dispose();
    _topicController.dispose();
    _termFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _topicFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final topics = await TopicService.getTopics();
    
    setState(() {
      _topics = topics;
    });
  }

  Future<void> _createOrGetTopic(String topicName) async {
    if (topicName.trim().isEmpty) {
      return;
    }

    final topic = await TopicService.createTopic(topicName);
    if (topic != null) {
      setState(() {
        _selectedTopic = topic;
        // Add to topics list if not already there
        if (!_topics.any((t) => t.id == topic.id)) {
          _topics.add(topic);
        }
      });
    }
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
      
      // Create or get topic if provided
      int? topicId;
      if (_topicController.text.trim().isNotEmpty) {
        await _createOrGetTopic(_topicController.text);
        if (_selectedTopic == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create or get topic'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        topicId = _selectedTopic!.id;
      }
      
      setState(() {
        _isCreatingConcept = true;
      });
      
      // Load user ID if available
      int? userId;
      try {
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString('current_user');
        if (userJson != null) {
          final userMap = jsonDecode(userJson) as Map<String, dynamic>;
          final user = User.fromJson(userMap);
          userId = user.id;
        }
      } catch (e) {
        // If loading user fails, continue without user_id
      }
      
      final result = await FlashcardService.createConceptOnly(
        term: term,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        topicId: topicId,
        userId: userId,
      );
      
      setState(() {
        _isCreatingConcept = false;
      });
      
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concept created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear form after successful creation
        _termController.clear();
        _descriptionController.clear();
        _topicController.clear();
        setState(() {
          _selectedTopic = null;
        });
      } else {
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
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                minLines: 1,
                maxLines: 5,
              ),
              const SizedBox(height: 12),

              // Topic field
              TextFormField(
                controller: _topicController,
                focusNode: _topicFocusNode,
                autofocus: false,
                enabled: true,
                textCapitalization: TextCapitalization.sentences,
                onTap: () {
                  _topicFocusNode.canRequestFocus = true;
                  _topicFocusNode.requestFocus();
                },
                onChanged: (value) {
                  // Clear selected topic when user types
                  setState(() {
                    _selectedTopic = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Topic (optional)',
                  hintText: 'Enter topic name (will be created if new)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              
              // Create Concept button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreatingConcept ? null : _handleCreateConcept,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

