import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../features/profile/domain/language.dart';
import '../../../../features/profile/domain/user.dart';
import '../../data/flashcard_service.dart';
import '../../data/card_generation_background_service.dart';
import '../../../../common_widgets/language_selection_widget.dart';
import 'card_generation_progress_widget.dart';

class GenerateCardsSection extends StatefulWidget {
  final List<Language> languages;
  final bool isLoadingLanguages;

  const GenerateCardsSection({
    super.key,
    required this.languages,
    required this.isLoadingLanguages,
  });

  @override
  State<GenerateCardsSection> createState() => _GenerateCardsSectionState();
}

class _GenerateCardsSectionState extends State<GenerateCardsSection> {
  List<String> _selectedLanguages = [];
  
  // Progress tracking for card generation
  int? _totalConcepts;
  int _currentConceptIndex = 0;
  String? _currentConceptTerm;
  List<String> _currentConceptMissingLanguages = [];
  int _conceptsProcessed = 0;
  int _cardsCreated = 0;
  List<String> _errors = [];
  bool _isCancelled = false;
  bool _isGeneratingCards = false;
  double _sessionCostUsd = 0.0;
  
  Timer? _progressPollTimer;

  @override
  void initState() {
    super.initState();
    // Load existing task state first, then set defaults if no task exists
    _loadExistingTaskState().then((_) {
      // Only set defaults if no existing task was loaded
      _loadUserAndUpdateSelection();
    });
    // Start polling for progress updates
    _startProgressPolling();
  }

  Future<void> _loadUserAndUpdateSelection() async {
    // Only set defaults if selection is still empty (no existing task was loaded)
    if (_selectedLanguages.isNotEmpty) {
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        _updateSelectedLanguages(user);
      } else {
        // If no user, default to all languages
        _updateSelectedLanguages(null);
      }
    } catch (e) {
      // If loading fails, default to all languages
      _updateSelectedLanguages(null);
    }
  }

  @override
  void dispose() {
    _progressPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExistingTaskState() async {
    final state = await CardGenerationBackgroundService.getTaskState();
    if (state != null && state['isRunning'] == true) {
      setState(() {
        _isGeneratingCards = true;
        _totalConcepts = state['totalConcepts'] as int?;
        _currentConceptIndex = state['currentIndex'] as int? ?? 0;
        _currentConceptTerm = state['currentTerm'] as String?;
        _conceptsProcessed = state['conceptsProcessed'] as int? ?? 0;
        _cardsCreated = state['cardsCreated'] as int? ?? 0;
        _sessionCostUsd = state['sessionCostUsd'] as double? ?? 0.0;
        _errors = List<String>.from(state['errors'] as List? ?? []);
        _isCancelled = state['isCancelled'] as bool? ?? false;
        _selectedLanguages = List<String>.from(state['selectedLanguages'] as List? ?? []);
      });
      
      // Resume the task if it's not cancelled
      if (!_isCancelled) {
        _resumeTask();
      }
    }
  }

  void _startProgressPolling() {
    _progressPollTimer?.cancel();
    _progressPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isGeneratingCards) {
        timer.cancel();
        return;
      }

      final state = await CardGenerationBackgroundService.getTaskState();
      if (state == null || state['isRunning'] != true) {
        // Task completed
        timer.cancel();
        setState(() {
          _isGeneratingCards = false;
        });
        _showCompletionMessage();
        return;
      }

      setState(() {
        _currentConceptIndex = state['currentIndex'] as int? ?? 0;
        _currentConceptTerm = state['currentTerm'] as String?;
        _conceptsProcessed = state['conceptsProcessed'] as int? ?? 0;
        _cardsCreated = state['cardsCreated'] as int? ?? 0;
        _sessionCostUsd = state['sessionCostUsd'] as double? ?? 0.0;
        _errors = List<String>.from(state['errors'] as List? ?? []);
        _isCancelled = state['isCancelled'] as bool? ?? false;
      });

      if (_isCancelled) {
        timer.cancel();
        setState(() {
          _isGeneratingCards = false;
        });
      }
    });
  }

  Future<void> _resumeTask() async {
    // Run the task asynchronously - it will continue even if widget is disposed
    _runBackgroundTask();
  }

  void _runBackgroundTask() {
    // Fire and forget - this will continue running even when app goes to background
    CardGenerationBackgroundService.executeTask().catchError((error) {
      print('Error in background task: $error');
      return <String, dynamic>{
        'success': false,
        'message': 'Task failed: $error',
      };
    });
  }

  @override
  void didUpdateWidget(GenerateCardsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selection when languages are loaded
    if (oldWidget.languages.isEmpty && widget.languages.isNotEmpty) {
      _loadUserAndUpdateSelection();
    }
  }

  void _updateSelectedLanguages(User? user) {
    // Select native and learning languages by default if user is available
    if (widget.languages.isNotEmpty) {
      if (user != null) {
        // Select only native and learning languages that exist in available languages
        final availableLanguageCodes = widget.languages.map((lang) => lang.code).toSet();
        final defaultLanguages = <String>[];
        if (user.langNative.isNotEmpty && availableLanguageCodes.contains(user.langNative)) {
          defaultLanguages.add(user.langNative);
        }
        if (user.langLearning != null && 
            user.langLearning!.isNotEmpty && 
            availableLanguageCodes.contains(user.langLearning!)) {
          defaultLanguages.add(user.langLearning!);
        }
        
        // Only update if we have valid languages and selection is empty or was all languages
        if (defaultLanguages.isNotEmpty && 
            (_selectedLanguages.isEmpty || _selectedLanguages.length == widget.languages.length)) {
          setState(() {
            _selectedLanguages = defaultLanguages;
          });
        } else if (defaultLanguages.isEmpty && _selectedLanguages.isEmpty) {
          // If user languages don't exist in available languages, fall back to all languages
          setState(() {
            _selectedLanguages = widget.languages.map((lang) => lang.code).toList();
          });
        }
      } else {
        // If no user, select all languages by default
        if (_selectedLanguages.isEmpty || _selectedLanguages.length != widget.languages.length) {
          setState(() {
            _selectedLanguages = widget.languages.map((lang) => lang.code).toList();
          });
        }
      }
    }
  }

  void _handleLanguageSelectionChanged(List<String> selectedLanguages) {
    setState(() {
      _selectedLanguages = selectedLanguages;
    });
  }

  void _handleCancel() async {
    await CardGenerationBackgroundService.cancelTask();
    setState(() {
      _isCancelled = true;
      _isGeneratingCards = false;
    });
  }

  Future<void> _handleGenerateCards() async {
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
      _sessionCostUsd = 0.0;
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
    
    // Start the background task
    await CardGenerationBackgroundService.startTask(
      conceptIds: conceptIds,
      conceptTerms: conceptTerms,
      conceptMissingLanguages: conceptMissingLanguages,
      selectedLanguages: _selectedLanguages,
    );
    
    // Run the task asynchronously - it will continue even when app goes to background
    _runBackgroundTask();
    
    // Start polling for progress updates
    _startProgressPolling();
  }

  void _showCompletionMessage() {
    setState(() {
      _currentConceptTerm = null;
      _currentConceptMissingLanguages = [];
    });
  }
  
  void _dismissProgress() {
    setState(() {
      _totalConcepts = null;
      _currentConceptIndex = 0;
      _currentConceptTerm = null;
      _currentConceptMissingLanguages = [];
      _conceptsProcessed = 0;
      _cardsCreated = 0;
      _errors = [];
      _isCancelled = false;
      _isGeneratingCards = false;
      _sessionCostUsd = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              'Generate Lemmas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Languages section
        LanguageSelectionWidget(
          languages: widget.languages,
          selectedLanguages: _selectedLanguages,
          isLoading: widget.isLoadingLanguages,
          onSelectionChanged: _handleLanguageSelectionChanged,
        ),
        const SizedBox(height: 16),
        
        // Progress display
        if (_totalConcepts != null) ...[
          CardGenerationProgressWidget(
            totalConcepts: _totalConcepts,
            currentConceptIndex: _currentConceptIndex,
            currentConceptTerm: _currentConceptTerm,
            currentConceptMissingLanguages: _currentConceptMissingLanguages,
            conceptsProcessed: _conceptsProcessed,
            cardsCreated: _cardsCreated,
            errors: _errors,
            sessionCostUsd: _sessionCostUsd,
            isGenerating: _isGeneratingCards,
            isCancelled: _isCancelled,
            onCancel: _isGeneratingCards ? _handleCancel : null,
            onDismiss: !_isGeneratingCards ? _dismissProgress : null,
          ),
          const SizedBox(height: 12),
        ],
        
        // Generate Cards button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isGeneratingCards || _selectedLanguages.isEmpty) ? null : _handleGenerateCards,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
                    'Generate Lemmas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}

