import 'package:flutter/material.dart';
import '../../../features/profile/domain/language.dart';
import '../../../features/profile/data/language_service.dart';
import '../../../common_widgets/language_button.dart';
import '../../../utils/language_emoji.dart';
import '../data/flashcard_service.dart';
import '../data/topic_service.dart' show Topic, TopicService;

class GenerateFlashcardsScreen extends StatefulWidget {
  const GenerateFlashcardsScreen({super.key});

  @override
  State<GenerateFlashcardsScreen> createState() => _GenerateFlashcardsScreenState();
}

class _GenerateFlashcardsScreenState extends State<GenerateFlashcardsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _termController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _topicController = TextEditingController();
  final _termFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _topicFocusNode = FocusNode();
  
  List<Language> _languages = [];
  List<Topic> _topics = [];
  bool _isLoadingLanguages = false;
  bool _isCreatingConcept = false;
  bool _isGeneratingCards = false;
  List<String> _selectedLanguages = [];
  Topic? _selectedTopic;
  
  // Progress tracking for card generation
  int? _totalConcepts;
  int _currentConceptIndex = 0;
  String? _currentConceptTerm;
  List<String> _currentConceptMissingLanguages = [];
  int _conceptsProcessed = 0;
  int _cardsCreated = 0;
  List<String> _errors = [];
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _loadUserAndLanguages();
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

  Future<void> _loadUserAndLanguages() async {
    setState(() {
      _isLoadingLanguages = true;
    });

    // Load languages
    final languages = await LanguageService.getLanguages();
    
    setState(() {
      _languages = languages;
      _isLoadingLanguages = false;
      
      // Default to all languages
      _selectedLanguages = languages.map((lang) => lang.code).toList();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
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
                
                // Part 1: Create Concepts
                Column(
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
                        minLines: 2,
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
                          labelText: 'Topic',
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
                          onPressed: _isCreatingConcept ? null : () async {
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
                              
                              final result = await FlashcardService.createConceptOnly(
                                term: term,
                                description: _descriptionController.text.trim().isNotEmpty 
                                    ? _descriptionController.text.trim() 
                                    : null,
                                topicId: topicId,
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
                          },
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
                
                const SizedBox(height: 32),
                
                // Part 2: Generate Cards
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generate Cards',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                      
                      // Languages section
                      Text(
                        'Select Languages',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingLanguages)
                        const Center(child: CircularProgressIndicator())
                      else
                        Column(
                          children: [
                            // "All Languages" button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedLanguages.length == _languages.length) {
                                      _selectedLanguages = [];
                                    } else {
                                      _selectedLanguages = _languages.map((lang) => lang.code).toList();
                                    }
                                  });
                                },
                                icon: Icon(
                                  _selectedLanguages.length == _languages.length
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                ),
                                label: Text(
                                  _selectedLanguages.length == _languages.length
                                      ? 'All Languages Selected'
                                      : 'Select All Languages',
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Language buttons in grid
                            for (int i = 0; i < _languages.length; i += 3)
                              Padding(
                                padding: EdgeInsets.only(bottom: i + 3 < _languages.length ? 8 : 0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: LanguageButton(
                                        language: _languages[i],
                                        isSelected: _selectedLanguages.contains(_languages[i].code),
                                        onPressed: () {
                                          setState(() {
                                            if (_selectedLanguages.contains(_languages[i].code)) {
                                              _selectedLanguages.remove(_languages[i].code);
                                            } else {
                                              _selectedLanguages.add(_languages[i].code);
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
                                          isSelected: _selectedLanguages.contains(_languages[i + 1].code),
                                          onPressed: () {
                                            setState(() {
                                              if (_selectedLanguages.contains(_languages[i + 1].code)) {
                                                _selectedLanguages.remove(_languages[i + 1].code);
                                              } else {
                                                _selectedLanguages.add(_languages[i + 1].code);
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
                                          isSelected: _selectedLanguages.contains(_languages[i + 2].code),
                                          onPressed: () {
                                            setState(() {
                                              if (_selectedLanguages.contains(_languages[i + 2].code)) {
                                                _selectedLanguages.remove(_languages[i + 2].code);
                                              } else {
                                                _selectedLanguages.add(_languages[i + 2].code);
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
                      const SizedBox(height: 16),
                      
                      // Inline progress display
                      if (_isGeneratingCards && _totalConcepts != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Generating Cards',
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (_isGeneratingCards)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _isCancelled = true;
                                          _isGeneratingCards = false;
                                        });
                                      },
                                      icon: const Icon(Icons.cancel, size: 18),
                                      label: const Text('Cancel'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Total concepts info
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Found $_totalConcepts concept(s) without missing languages',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Current concept being processed
                              if (_currentConceptTerm != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Processing: $_currentConceptTerm',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_currentConceptMissingLanguages.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'Missing languages:',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            ..._currentConceptMissingLanguages.map((lang) {
                                              final langCode = lang.toLowerCase();
                                              final flagEmoji = LanguageEmoji.getEmoji(langCode);
                                              return Text(
                                                flagEmoji,
                                                style: const TextStyle(fontSize: 20),
                                              );
                                            }),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              
                              // Progress bar
                              if (_totalConcepts != null && _totalConcepts! > 0) ...[
                                Text(
                                  'Concept ${_currentConceptIndex + 1} of $_totalConcepts',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _totalConcepts! > 0 ? (_currentConceptIndex + 1) / _totalConcepts! : 0,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              
                              // Stats
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '$_conceptsProcessed',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        'Processed',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '$_cardsCreated',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                      Text(
                                        'Cards Created',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  if (_errors.isNotEmpty)
                                    Column(
                                      children: [
                                        Text(
                                          '${_errors.length}',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                        Text(
                                          'Errors',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Generate Cards button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isGeneratingCards || _selectedLanguages.isEmpty) ? null : () async {
                            // Validate that at least one language is selected
                            if (_selectedLanguages.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select at least one language'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            // Reset progress state
                            setState(() {
                              _isGeneratingCards = true;
                              _isCancelled = false;
                              _totalConcepts = null;
                              _currentConceptIndex = 0;
                              _currentConceptTerm = null;
                              _currentConceptMissingLanguages = [];
                              _conceptsProcessed = 0;
                              _cardsCreated = 0;
                              _errors = [];
                            });
                            
                            // First, get concepts with missing languages
                            final missingResult = await FlashcardService.getConceptsWithMissingLanguages(
                              languages: _selectedLanguages,
                            );
                            
                            if (missingResult['success'] != true) {
                              setState(() {
                                _isGeneratingCards = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(missingResult['message'] as String),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            final missingData = missingResult['data'] as Map<String, dynamic>?;
                            final concepts = missingData?['concepts'] as List<dynamic>?;
                            
                            if (concepts == null || concepts.isEmpty) {
                              setState(() {
                                _isGeneratingCards = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No concepts found that need cards for the selected languages'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                              return;
                            }
                            
                            // Extract concept IDs, terms, and missing languages
                            final conceptIds = <int>[];
                            final conceptTerms = <int, String>{};
                            final conceptMissingLanguages = <int, List<String>>{};
                            for (final c in concepts) {
                              final conceptData = c as Map<String, dynamic>;
                              final concept = conceptData['concept'] as Map<String, dynamic>;
                              final conceptId = concept['id'] as int;
                              final conceptTerm = concept['term'] as String? ?? 'Unknown';
                              final missingLanguages = (conceptData['missing_languages'] as List<dynamic>?)
                                  ?.map((lang) => lang.toString().toUpperCase())
                                  .toList() ?? [];
                              conceptIds.add(conceptId);
                              conceptTerms[conceptId] = conceptTerm;
                              conceptMissingLanguages[conceptId] = missingLanguages;
                            }
                            
                            setState(() {
                              _totalConcepts = conceptIds.length;
                            });
                            
                            // Process concepts one by one
                            for (int i = 0; i < conceptIds.length; i++) {
                              // Check if cancelled
                              if (_isCancelled) {
                                break;
                              }
                              
                              final conceptId = conceptIds[i];
                              final conceptTerm = conceptTerms[conceptId] ?? 'Unknown';
                              final missingLanguages = conceptMissingLanguages[conceptId] ?? [];
                              
                              setState(() {
                                _currentConceptIndex = i;
                                _currentConceptTerm = conceptTerm;
                                _currentConceptMissingLanguages = missingLanguages;
                              });
                              
                              // Generate cards for this concept
                              final generateResult = await FlashcardService.generateCardsForConcept(
                                conceptId: conceptId,
                                languages: _selectedLanguages,
                              );
                              
                              if (generateResult['success'] == true) {
                                final data = generateResult['data'] as Map<String, dynamic>?;
                                final cardsCreated = data?['cards_created'] as int? ?? 0;
                                
                                setState(() {
                                  _conceptsProcessed++;
                                  _cardsCreated += cardsCreated;
                                });
                              } else {
                                final errorMsg = generateResult['message'] as String? ?? 'Unknown error';
                                setState(() {
                                  _errors.add('Concept $conceptId ($conceptTerm): $errorMsg');
                                });
                              }
                            }
                            
                            setState(() {
                              _isGeneratingCards = false;
                              _currentConceptTerm = null;
                              _currentConceptMissingLanguages = [];
                            });
                            
                            // Show completion message
                            if (!_isCancelled) {
                              String message = 'Generated $_cardsCreated card(s) for $_conceptsProcessed of $_totalConcepts concept(s)';
                              if (_errors.isNotEmpty) {
                                message += '\n\nErrors: ${_errors.length}';
                              }
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cancelled. Processed $_conceptsProcessed of $_totalConcepts concept(s)'),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                          ),
                          child: _isGeneratingCards
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Generate Cards for Concepts',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
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

