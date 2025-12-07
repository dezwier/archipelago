import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../features/profile/domain/user.dart';
import '../../../features/profile/domain/language.dart';
import '../../../features/profile/data/language_service.dart';
import '../../../common_widgets/language_button.dart';
import '../data/flashcard_service.dart';
import 'flashcard_confirmation_screen.dart';

class GenerateFlashcardsScreen extends StatefulWidget {
  const GenerateFlashcardsScreen({super.key});

  @override
  State<GenerateFlashcardsScreen> createState() => _GenerateFlashcardsScreenState();
}

class _GenerateFlashcardsScreenState extends State<GenerateFlashcardsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _conceptController = TextEditingController();
  final _topicController = TextEditingController();
  final _conceptFocusNode = FocusNode();
  final _topicFocusNode = FocusNode();
  
  User? _currentUser;
  List<Language> _languages = [];
  bool _isLoadingLanguages = false;
  bool _isGenerating = false;
  Language? _selectedSourceLanguage;
  Language? _selectedTargetLanguage;

  @override
  void initState() {
    super.initState();
    _loadUserAndLanguages();
    
    // Prevent fields from requesting focus automatically
    // They can only get focus when user explicitly taps them
    _conceptFocusNode.canRequestFocus = false;
    _topicFocusNode.canRequestFocus = false;
    
    // Reset canRequestFocus when focus is lost, but with a delay
    // to allow the TextField to properly handle the unfocus
    _conceptFocusNode.addListener(() {
      if (!_conceptFocusNode.hasFocus) {
        // Delay reset to allow TextField to complete its unfocus handling
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_conceptFocusNode.hasFocus) {
            _conceptFocusNode.canRequestFocus = false;
          }
        });
      }
    });
    _topicFocusNode.addListener(() {
      if (!_topicFocusNode.hasFocus) {
        // Delay reset to allow TextField to complete its unfocus handling
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
    _conceptController.dispose();
    _topicController.dispose();
    _conceptFocusNode.dispose();
    _topicFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndLanguages() async {
    setState(() {
      _isLoadingLanguages = true;
    });

    // Load user data
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        setState(() {
          _currentUser = User.fromJson(userMap);
        });
      }
    } catch (e) {
      // Ignore errors
    }

    // Load languages
    final languages = await LanguageService.getLanguages();
    
    setState(() {
      _languages = languages;
      _isLoadingLanguages = false;
      
      // Set default source and target languages from user settings
      if (_currentUser != null) {
        _selectedSourceLanguage = _languages.firstWhere(
          (lang) => lang.code == _currentUser!.langNative,
          orElse: () => _languages.isNotEmpty ? _languages.first : Language(code: 'en', name: 'English'),
        );
        
        if (_currentUser!.langLearning != null && _currentUser!.langLearning!.isNotEmpty) {
          try {
            _selectedTargetLanguage = _languages.firstWhere(
              (lang) => lang.code == _currentUser!.langLearning,
            );
          } catch (e) {
            _selectedTargetLanguage = null;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const SizedBox(height: 8),
                  Text(
                    'Source Language',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              const SizedBox(height: 8),

              // Concept text field
              TextFormField(
                controller: _conceptController,
                focusNode: _conceptFocusNode,
                autofocus: false,
                enabled: true,
                onTap: () {
                  // Always enable focus when user taps on the field
                  _conceptFocusNode.canRequestFocus = true;
                  // Request focus explicitly to ensure it works
                  _conceptFocusNode.requestFocus();
                },
                decoration: InputDecoration(
                  labelText: 'Concept',
                  hintText: 'Enter a word or phrase',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                minLines: 1,
                maxLines: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a concept';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Optional Topic field
              TextFormField(
                controller: _topicController,
                focusNode: _topicFocusNode,
                autofocus: false,
                enabled: true,
                onTap: () {
                  // Always enable focus when user taps on the field
                  _topicFocusNode.canRequestFocus = true;
                  // Request focus explicitly to ensure it works
                  _topicFocusNode.requestFocus();
                },
                decoration: InputDecoration(
                  labelText: 'Topic Island',
                  hintText: 'Enter what the concept is about',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              
              // Source Language
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source Language',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_isLoadingLanguages)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: [
                        for (int i = 0; i < _languages.length; i += 3)
                          Padding(
                            padding: EdgeInsets.only(bottom: i + 3 < _languages.length ? 0 : 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: LanguageButton(
                                    language: _languages[i],
                                    isSelected: _languages[i].code == _selectedSourceLanguage?.code,
                                    onPressed: () {
                                      setState(() {
                                        _selectedSourceLanguage = _languages[i];
                                        // Clear target language if it's the same as source
                                        if (_selectedTargetLanguage?.code == _languages[i].code) {
                                          _selectedTargetLanguage = null;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                if (i + 1 < _languages.length) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LanguageButton(
                                      language: _languages[i + 1],
                                      isSelected: _languages[i + 1].code == _selectedSourceLanguage?.code,
                                      onPressed: () {
                                        setState(() {
                                          _selectedSourceLanguage = _languages[i + 1];
                                          // Clear target language if it's the same as source
                                          if (_selectedTargetLanguage?.code == _languages[i + 1].code) {
                                            _selectedTargetLanguage = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ] else
                                  const Spacer(),
                                if (i + 2 < _languages.length) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LanguageButton(
                                      language: _languages[i + 2],
                                      isSelected: _languages[i + 2].code == _selectedSourceLanguage?.code,
                                      onPressed: () {
                                        setState(() {
                                          _selectedSourceLanguage = _languages[i + 2];
                                          // Clear target language if it's the same as source
                                          if (_selectedTargetLanguage?.code == _languages[i + 2].code) {
                                            _selectedTargetLanguage = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ] else if (i + 1 < _languages.length)
                                  const Spacer(),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Target Language
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Language',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_isLoadingLanguages)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: [
                        for (int i = 0; i < _languages.length; i += 3)
                          Padding(
                            padding: EdgeInsets.only(bottom: i + 3 < _languages.length ? 0 : 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: LanguageButton(
                                    language: _languages[i],
                                    isSelected: _languages[i].code == _selectedTargetLanguage?.code,
                                    onPressed: _languages[i].code == _selectedSourceLanguage?.code
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedTargetLanguage = _languages[i];
                                            });
                                          },
                                  ),
                                ),
                                if (i + 1 < _languages.length) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LanguageButton(
                                      language: _languages[i + 1],
                                      isSelected: _languages[i + 1].code == _selectedTargetLanguage?.code,
                                      onPressed: _languages[i + 1].code == _selectedSourceLanguage?.code
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedTargetLanguage = _languages[i + 1];
                                              });
                                            },
                                    ),
                                  ),
                                ] else
                                  const Spacer(),
                                if (i + 2 < _languages.length) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LanguageButton(
                                      language: _languages[i + 2],
                                      isSelected: _languages[i + 2].code == _selectedTargetLanguage?.code,
                                      onPressed: _languages[i + 2].code == _selectedSourceLanguage?.code
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedTargetLanguage = _languages[i + 2];
                                              });
                                            },
                                    ),
                                  ),
                                ] else if (i + 1 < _languages.length)
                                  const Spacer(),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      // Validate that both languages are selected
                      if (_selectedSourceLanguage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a source language'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      if (_selectedTargetLanguage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a target language'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      
                      // Generate flashcard
                      setState(() {
                        _isGenerating = true;
                      });
                      
                      final result = await FlashcardService.generateFlashcard(
                        concept: _conceptController.text,
                        sourceLanguage: _selectedSourceLanguage!.code,
                        targetLanguage: _selectedTargetLanguage!.code,
                        topic: _topicController.text.isEmpty ? null : _topicController.text,
                      );
                      
                      setState(() {
                        _isGenerating = false;
                      });
                      
                      if (result['success'] == true) {
                        // Navigate to confirmation screen
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FlashcardConfirmationScreen(
                              flashcardData: result,
                              concept: _conceptController.text,
                              sourceLanguageCode: _selectedSourceLanguage!.code,
                              targetLanguageCode: _selectedTargetLanguage!.code,
                            ),
                          ),
                        );
                        
                        // Clear form
                        _conceptController.clear();
                        _topicController.clear();
                      } else {
                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] as String),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Flashcard',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      ),
    );
  }
}


