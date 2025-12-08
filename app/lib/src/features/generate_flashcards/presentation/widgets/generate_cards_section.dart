import 'package:flutter/material.dart';
import '../../../../features/profile/domain/language.dart';
import '../../data/flashcard_service.dart';
import 'language_selection_widget.dart';
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

  @override
  void initState() {
    super.initState();
    // Default to all languages if available
    _updateSelectedLanguages();
  }

  @override
  void didUpdateWidget(GenerateCardsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selection when languages are loaded
    if (oldWidget.languages.isEmpty && widget.languages.isNotEmpty) {
      _updateSelectedLanguages();
    }
  }

  void _updateSelectedLanguages() {
    // Select all languages by default if none are selected or if languages just loaded
    if (widget.languages.isNotEmpty && 
        (_selectedLanguages.isEmpty || _selectedLanguages.length != widget.languages.length)) {
      setState(() {
        _selectedLanguages = widget.languages.map((lang) => lang.code).toList();
      });
    }
  }

  void _handleLanguageSelectionChanged(List<String> selectedLanguages) {
    setState(() {
      _selectedLanguages = selectedLanguages;
    });
  }

  void _handleCancel() {
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
        final costUsd = (data?['session_cost_usd'] as num?)?.toDouble() ?? 0.0;
        
        setState(() {
          _conceptsProcessed++;
          _cardsCreated += cardsCreated;
          _sessionCostUsd += costUsd;
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
              'Generate Cards',
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
            onCancel: _isGeneratingCards ? _handleCancel : null,
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
                    'Generate Cards',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}

