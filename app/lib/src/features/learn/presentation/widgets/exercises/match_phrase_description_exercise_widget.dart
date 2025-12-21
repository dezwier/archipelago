import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/concept_content_card_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/selectable_concept_card_widget.dart';

/// Widget that displays a Match Phrase Description exercise
/// Shows a phrase at the top and description cards below
/// User selects the matching description card
class MatchPhraseDescriptionExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;

  const MatchPhraseDescriptionExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  State<MatchPhraseDescriptionExerciseWidget> createState() => _MatchPhraseDescriptionExerciseWidgetState();
}

class _MatchPhraseDescriptionExerciseWidgetState extends State<MatchPhraseDescriptionExerciseWidget> {
  int? _selectedCardIndex;
  bool _isCorrect = false;
  bool _hasAnswered = false;
  List<Map<String, dynamic>> _allConcepts = [];
  dynamic _exerciseConceptId;
  bool _hasAutoPlayed = false; // Track if we've autoplayed for this card instance

  /// Get concept ID from a concept map, checking both 'id' and 'concept_id' fields
  dynamic _getConceptId(Map<String, dynamic> concept) {
    return concept['id'] ?? concept['concept_id'];
  }

  @override
  void initState() {
    super.initState();
    _resetState();
  }

  @override
  void didUpdateWidget(MatchPhraseDescriptionExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when exercise changes (check both ID and concept ID)
    final oldConceptId = _getConceptId(oldWidget.exercise.concept);
    final newConceptId = _getConceptId(widget.exercise.concept);
    if (oldWidget.exercise.id != widget.exercise.id || 
        oldConceptId != newConceptId) {
      _resetState();
    }
    // Reset autoplay flag if we navigated to a different exercise
    if (widget.exercise.id != oldWidget.exercise.id) {
      _hasAutoPlayed = false;
    }
    // If autoPlay changed from false to true, reset the flag to allow autoplay
    if (widget.autoPlay && !oldWidget.autoPlay) {
      _hasAutoPlayed = false;
    }
  }

  void _resetState() {
    _exerciseConceptId = _getConceptId(widget.exercise.concept);
    _initializeConcepts();
    if (mounted) {
      setState(() {
        _selectedCardIndex = null;
        _isCorrect = false;
        _hasAnswered = false;
        _hasAutoPlayed = false;
      });
    } else {
      // If not mounted, set directly (shouldn't happen, but safe)
      _selectedCardIndex = null;
      _isCorrect = false;
      _hasAnswered = false;
      _hasAutoPlayed = false;
    }
  }

  void _initializeConcepts() {
    // Clear existing concepts first
    _allConcepts = [];
    
    // Get all concepts from exerciseData
    if (widget.exercise.exerciseData != null) {
      final allConceptsData = widget.exercise.exerciseData!['all_concepts'] as List<dynamic>?;
      if (allConceptsData != null) {
        _allConcepts = allConceptsData
            .map((c) => c as Map<String, dynamic>)
            .where((concept) {
              // Only include concepts that have descriptions
              final learningLemma = concept['learning_lemma'] as Map<String, dynamic>?;
              final description = learningLemma?['description'] as String?;
              return description != null && description.isNotEmpty;
            })
            .toList();
      }
    }
  }

  /// Compare two IDs, handling different types (int, String, etc.)
  bool _compareIds(dynamic id1, dynamic id2) {
    if (id1 == null || id2 == null) return false;
    // Convert both to strings for comparison to handle type mismatches
    return id1.toString() == id2.toString();
  }

  void _handleCardTap(int index) {
    // Don't allow selection after answering (waiting for feedback or next card)
    if (_hasAnswered) return;

    setState(() {
      _selectedCardIndex = index;
      final selectedConcept = _allConcepts[index];
      
      // Check if selected card matches the exercise's concept
      // Ensure proper type comparison for IDs
      final selectedConceptId = _getConceptId(selectedConcept);
      final isCorrect = _compareIds(selectedConceptId, _exerciseConceptId);
      _isCorrect = isCorrect;
      _hasAnswered = true;
    });

    // Only proceed to next card if correct (after 1 second delay)
    if (_isCorrect) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _isCorrect) {
          widget.onComplete();
        }
      });
    } else {
      // If wrong, show feedback and allow retry after a delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_isCorrect) {
          setState(() {
            _selectedCardIndex = null;
            _hasAnswered = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safeguard: Ensure state is reset if exercise concept changed
    final currentConceptId = _getConceptId(widget.exercise.concept);
    if (currentConceptId != _exerciseConceptId) {
      // Exercise changed, reset state synchronously (without setState during build)
      _exerciseConceptId = currentConceptId;
      _initializeConcepts();
      _selectedCardIndex = null;
      _isCorrect = false;
      _hasAnswered = false;
      // Schedule setState for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    
    if (_allConcepts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No concepts with descriptions available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.onComplete,
              child: const Text('Skip'),
            ),
          ],
        ),
      );
    }

    // Get phrase from exercise.concept (the specific concept for this exercise)
    final exerciseConcept = widget.exercise.concept;
    final learningLemma = exerciseConcept['learning_lemma'] as Map<String, dynamic>?;
    if (learningLemma == null) {
      widget.onComplete();
      return const SizedBox.shrink();
    }

    final nativeLemma = exerciseConcept['native_lemma'] as Map<String, dynamic>?;
    final conceptId = _getConceptId(exerciseConcept);
    
    // Determine if we should autoplay for this build
    final shouldAutoPlay = widget.autoPlay && !_hasAutoPlayed;
    if (shouldAutoPlay) {
      _hasAutoPlayed = true;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Concept info section - show phrase (term + IPA + audio) without description
          ConceptContentCardWidget(
            learningLemma: learningLemma,
            nativeLemma: nativeLemma,
            conceptId: conceptId,
            autoPlay: shouldAutoPlay,
            showDescription: false,
          ),

          const SizedBox(height: 12),

          // Description cards - show description cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: _allConcepts.asMap().entries.map((entry) {
                final index = entry.key;
                final concept = entry.value;
                final learningLemma = concept['learning_lemma'] as Map<String, dynamic>?;
                final nativeLemma = concept['native_lemma'] as Map<String, dynamic>?;
                final conceptId = _getConceptId(concept);
                
                if (learningLemma == null) {
                  return const SizedBox.shrink();
                }

                final isSelected = _selectedCardIndex == index;
                final isCorrectAnswer = _compareIds(conceptId, _exerciseConceptId);

                return SelectableConceptCardWidget(
                  learningLemma: learningLemma,
                  nativeLemma: nativeLemma,
                  conceptId: conceptId,
                  isSelected: isSelected,
                  isCorrectAnswer: isCorrectAnswer,
                  hasAnswered: _hasAnswered,
                  isCorrect: _isCorrect,
                  onTap: () => _handleCardTap(index),
                  displayMode: CardDisplayMode.description,
                  autoPlay: false, // Don't autoplay for description cards
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

