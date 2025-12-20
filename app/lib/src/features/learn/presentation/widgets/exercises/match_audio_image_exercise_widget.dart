import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';

/// Widget that displays a Match Audio Image exercise
/// Shows description + audio button at top and image grid below
/// User selects the matching image from the grid
class MatchAudioImageExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;

  const MatchAudioImageExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  State<MatchAudioImageExerciseWidget> createState() => _MatchAudioImageExerciseWidgetState();
}

class _MatchAudioImageExerciseWidgetState extends State<MatchAudioImageExerciseWidget> {
  int? _selectedImageIndex;
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
  void didUpdateWidget(MatchAudioImageExerciseWidget oldWidget) {
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
        _selectedImageIndex = null;
        _isCorrect = false;
        _hasAnswered = false;
        _hasAutoPlayed = false;
      });
    } else {
      // If not mounted, set directly (shouldn't happen, but safe)
      _selectedImageIndex = null;
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
              // Only include concepts that have image_url
              final imageUrl = concept['image_url'] as String?;
              return imageUrl != null && imageUrl.isNotEmpty;
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

  void _handleImageTap(int index) {
    // Don't allow selection after answering (waiting for feedback or next card)
    if (_hasAnswered) return;

    setState(() {
      _selectedImageIndex = index;
      final selectedConcept = _allConcepts[index];
      
      // Check if selected image matches the exercise's concept
      // Ensure proper type comparison for IDs
      final selectedConceptId = _getConceptId(selectedConcept);
      final isCorrect = _compareIds(selectedConceptId, _exerciseConceptId);
      _isCorrect = isCorrect;
      _hasAnswered = true;
    });

    // Only proceed to next card if correct
    if (_isCorrect) {
      // Move to next card after a short delay
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
            _selectedImageIndex = null;
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
      _selectedImageIndex = null;
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
              Icons.image_not_supported,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No concepts with images available',
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

    final learningDescription = learningLemma['description'] as String?;
    final learningLanguageCode = (learningLemma['language_code'] as String? ?? '').toLowerCase();
    final learningAudioPath = learningLemma['audio_path'] as String?;
    final learningLemmaId = learningLemma['id'] as int?;
    final learningTerm = learningLemma['translation'] as String? ?? 'Unknown';
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
          // Concept info section - show description at top and bigger centralized audio button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Description at the top
                if (learningDescription != null && learningDescription.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      learningDescription,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                // Bigger centralized audio button
                if (learningLemmaId != null)
                  LemmaAudioPlayer(
                    key: ValueKey('audio_${conceptId}_$learningLemmaId'),
                    lemmaId: learningLemmaId,
                    audioPath: learningAudioPath,
                    term: learningTerm,
                    description: learningDescription,
                    languageCode: learningLanguageCode,
                    iconSize: 32.0, // Bigger icon size
                    autoPlay: shouldAutoPlay,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Image grid (2 columns)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _allConcepts.length,
              itemBuilder: (context, index) {
                final concept = _allConcepts[index];
                final imageUrl = _getImageUrl(concept['image_url'] as String?);
                final isSelected = _selectedImageIndex == index;
                // Check if this concept matches the exercise's concept
                final conceptId = _getConceptId(concept);
                final isCorrectAnswer = _compareIds(conceptId, _exerciseConceptId);
                
                Color? borderColor;
                if (_hasAnswered) {
                  if (_isCorrect) {
                    // After correct answer, only highlight the correct one
                    if (isCorrectAnswer) {
                      borderColor = Colors.green;
                    }
                  } else {
                    // After wrong answer, only show red on selected wrong one
                    if (isSelected) {
                      borderColor = Colors.red;
                    }
                  }
                } else if (isSelected) {
                  // Before answering, show primary color for selected
                  borderColor = Theme.of(context).colorScheme.primary;
                }

                const double borderRadius = 12.0;
                const double borderWidth = 3.0;
                final bool hasBorder = borderColor != null;
                // When border is present, inner content radius should account for border width
                final double imageRadius = hasBorder ? borderRadius - borderWidth : borderRadius;

                return GestureDetector(
                  onTap: () => _handleImageTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(
                        color: borderColor ?? Colors.transparent,
                        width: hasBorder ? borderWidth : 0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(imageRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 32,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 32,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                  ),
                                ),
                          // Overlay for selected state (only when not answered or answered incorrectly)
                          if (isSelected && (!_hasAnswered || (_hasAnswered && !_isCorrect)))
                            Container(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          // Feedback icon (green for correct, red for incorrect)
                          if (_hasAnswered && isSelected)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _isCorrect 
                                      ? Colors.green.withValues(alpha: 0.8)
                                      : Colors.red.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isCorrect ? Icons.check : Icons.close,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

