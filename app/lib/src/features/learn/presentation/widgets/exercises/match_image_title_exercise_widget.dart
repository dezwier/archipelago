import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/selectable_concept_card_widget.dart';

/// Widget that displays a Match Image Title exercise
/// Shows an image at the top and all concept cards below
/// User selects the matching concept card
class MatchImageTitleExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;

  const MatchImageTitleExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  State<MatchImageTitleExerciseWidget> createState() => _MatchImageTitleExerciseWidgetState();
}

class _MatchImageTitleExerciseWidgetState extends State<MatchImageTitleExerciseWidget> {
  int? _selectedCardIndex;
  bool _isCorrect = false;
  bool _hasAnswered = false;
  bool _waitingForAudio = false;
  List<Map<String, dynamic>> _allConcepts = [];
  dynamic _exerciseConceptId;

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
  void didUpdateWidget(MatchImageTitleExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when exercise changes (check both ID and concept ID)
    final oldConceptId = _getConceptId(oldWidget.exercise.concept);
    final newConceptId = _getConceptId(widget.exercise.concept);
    if (oldWidget.exercise.id != widget.exercise.id || 
        oldConceptId != newConceptId) {
      _resetState();
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
        _waitingForAudio = false;
      });
    } else {
      // If not mounted, set directly (shouldn't happen, but safe)
      _selectedCardIndex = null;
      _isCorrect = false;
      _hasAnswered = false;
      _waitingForAudio = false;
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

  /// Get the full image URL
  String? _getImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    
    // Build base URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    } else {
      // Otherwise, prepend the API base URL
      final cleanUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
      return '${ApiConfig.baseUrl}/$cleanUrl';
    }
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
      // If correct, we'll wait for audio to finish
      _waitingForAudio = isCorrect;
    });

    // Only proceed to next card if correct (and after audio finishes)
    if (_isCorrect) {
      // Audio will autoplay, and we'll wait for onPlaybackComplete callback
      // Add a timeout fallback in case audio doesn't play or fails (e.g., no audio available)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _isCorrect && _waitingForAudio) {
          // Audio didn't complete within timeout, proceed anyway
          setState(() {
            _waitingForAudio = false;
          });
          widget.onComplete();
        }
      });
    } else {
      // If wrong, show feedback and allow retry after a delay
      // Autoplay will happen automatically since card is selected
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

  void _handleCorrectAnswerAudioComplete() {
    // Only proceed if we're still waiting for audio and answer is still correct
    if (mounted && _isCorrect && _waitingForAudio) {
      setState(() {
        _waitingForAudio = false;
      });
      widget.onComplete();
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
      _waitingForAudio = false;
      // Schedule setState for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    
    // Get the exercise concept (the one we're matching to)
    final exerciseConcept = widget.exercise.concept;
    final imageUrl = _getImageUrl(exerciseConcept['image_url'] as String?);
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No image available for this concept',
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

    if (_allConcepts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No concepts available',
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image at the top (centered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 78.0, vertical: 24.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Concept cards grid (selectable)
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
                  // Only listen to playback complete for the correct answer when it's selected
                  onPlaybackComplete: (isSelected && isCorrectAnswer && _isCorrect && _waitingForAudio)
                      ? _handleCorrectAnswerAudioComplete
                      : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

