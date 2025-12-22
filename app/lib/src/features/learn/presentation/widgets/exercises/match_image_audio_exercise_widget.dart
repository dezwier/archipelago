import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_performance.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:archipelago/src/features/dictionary/data/lemma_audio_service.dart';

/// Widget that displays a Match Image Audio exercise
/// Shows an image at the top and audio buttons in a grid below
/// User selects the matching audio button
class MatchImageAudioExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;
  final Function(Exercise exercise)? onExerciseStart;
  final Function(Exercise exercise, ExerciseOutcome outcome, {int? hintCount, String? failureReason})? onExerciseComplete;

  const MatchImageAudioExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
    this.onExerciseStart,
    this.onExerciseComplete,
  });

  @override
  State<MatchImageAudioExerciseWidget> createState() => _MatchImageAudioExerciseWidgetState();
}

/// Global key type for accessing widget state
typedef MatchImageAudioExerciseWidgetKey = GlobalKey<_MatchImageAudioExerciseWidgetState>;

class _MatchImageAudioExerciseWidgetState extends State<MatchImageAudioExerciseWidget> {
  int? _selectedCardIndex;
  bool _isCorrect = false;
  bool _hasAnswered = false;
  List<Map<String, dynamic>> _allConcepts = [];
  dynamic _exerciseConceptId;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _generatedAudioPath;
  int? _lastSelectedIndex; // Preserve last selection across exercises
  bool _hasStartedTracking = false;
  bool _hasWrongSelection = false;

  /// Get concept ID from a concept map, checking both 'id' and 'concept_id' fields
  dynamic _getConceptId(Map<String, dynamic> concept) {
    return concept['id'] ?? concept['concept_id'];
  }

  @override
  void initState() {
    super.initState();
    _resetState();
    _startTracking();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MatchImageAudioExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when exercise changes (check both ID and concept ID)
    final oldConceptId = _getConceptId(oldWidget.exercise.concept);
    final newConceptId = _getConceptId(widget.exercise.concept);
    if (oldWidget.exercise.id != widget.exercise.id || 
        oldConceptId != newConceptId) {
      _resetState();
      _startTracking();
    }
  }
  
  void _startTracking() {
    if (!_hasStartedTracking && widget.onExerciseStart != null) {
      _hasStartedTracking = true;
      widget.onExerciseStart!(widget.exercise);
    }
  }

  void _resetState() {
    _exerciseConceptId = _getConceptId(widget.exercise.concept);
    _initializeConcepts();
    _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _selectedCardIndex = null;
        _isCorrect = false;
        _hasAnswered = false;
        _hasStartedTracking = false;
        _hasWrongSelection = false;
      });
      // Select the last selected index (or first button if none) after initialization (without playing)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _allConcepts.isNotEmpty) {
          // Use last selected index if valid, otherwise use 0
          final indexToSelect = _lastSelectedIndex != null && 
              _lastSelectedIndex! >= 0 && 
              _lastSelectedIndex! < _allConcepts.length
              ? _lastSelectedIndex!
              : 0;
          setState(() {
            _selectedCardIndex = indexToSelect;
          });
        }
      });
    } else {
      // If not mounted, set directly (shouldn't happen, but safe)
      _selectedCardIndex = null;
      _isCorrect = false;
      _hasAnswered = false;
      _hasStartedTracking = false;
      _hasWrongSelection = false;
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

  /// Play audio for a specific button index
  Future<void> _playAudioForButton(int index) async {
    if (index < 0 || index >= _allConcepts.length) return;
    
    final concept = _allConcepts[index];
    final learningLemma = concept['learning_lemma'] as Map<String, dynamic>?;
    if (learningLemma == null) return;
    
    final learningLemmaId = learningLemma['id'] as int?;
    if (learningLemmaId == null) return;
    
    // Stop any currently playing audio
    await _audioPlayer.stop();
    
    final learningAudioPath = learningLemma['audio_path'] as String?;
    final learningTerm = learningLemma['translation'] as String?;
    final learningDescription = learningLemma['description'] as String?;
    final learningLanguageCode = (learningLemma['language_code'] as String? ?? '').toLowerCase();
    
    // Check if audio already exists
    final audioPath = learningAudioPath ?? _generatedAudioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      // Audio exists, play it
      await _playExistingAudio(audioPath);
    } else {
      // No audio, generate it first
      await _generateAndPlayAudio(learningLemmaId, learningTerm, learningDescription, learningLanguageCode);
    }
  }

  Future<void> _playExistingAudio(String audioPath) async {
    try {
      final audioUrl = LemmaAudioService.getAudioUrl(audioPath);
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
      }
    } catch (e) {
      // Silently fail - don't show errors for audio playback
    }
  }

  Future<void> _generateAndPlayAudio(int lemmaId, String? term, String? description, String? languageCode) async {
    try {
      final result = await LemmaAudioService.generateAudio(
        lemmaId: lemmaId,
        term: term,
        description: description,
        languageCode: languageCode,
      );

      if (!result['success']) {
        return;
      }

      final audioUrl = result['audioUrl'] as String?;
      if (audioUrl == null) {
        return;
      }

      _generatedAudioPath = audioUrl;
      await _playExistingAudio(audioUrl);
    } catch (e) {
      // Silently fail - don't show errors for audio generation
    }
  }

  void _handleButtonTap(int index) {
    // Don't allow selection after answering
    if (_hasAnswered) return;

    setState(() {
      _selectedCardIndex = index;
      _lastSelectedIndex = index; // Save the selection for next exercise
    });

    // Play audio for the selected button
    _playAudioForButton(index);
  }

  /// Check answer if selection is made but not answered yet
  /// Called by carousel's Next button
  bool checkAnswerIfNeeded() {
    if (_selectedCardIndex == null || _hasAnswered) {
      return false;
    }

    // Validate the selection
    final selectedConcept = _allConcepts[_selectedCardIndex!];
    final selectedConceptId = _getConceptId(selectedConcept);
    final isCorrect = _compareIds(selectedConceptId, _exerciseConceptId);

    setState(() {
      _isCorrect = isCorrect;
      _hasAnswered = true;
      
      // Track wrong selection
      if (!isCorrect) {
        _hasWrongSelection = true;
      }
    });

    if (_isCorrect) {
      // Report completion
      if (widget.onExerciseComplete != null) {
        final outcome = _hasWrongSelection ? ExerciseOutcome.failed : ExerciseOutcome.succeeded;
        widget.onExerciseComplete!(
          widget.exercise,
          outcome,
          failureReason: _hasWrongSelection ? 'Wrong answer selected first' : null,
        );
      }
      
      // Show green feedback, wait 1 second, then proceed
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isCorrect) {
          widget.onComplete();
        }
      });
    } else {
      // Show red feedback, allow retry after a delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && !_isCorrect) {
          setState(() {
            _selectedCardIndex = null;
            _hasAnswered = false;
          });
        }
      });
    }

    return true; // Answer was checked
  }

  @override
  Widget build(BuildContext context) {
    // Safeguard: Ensure state is reset if exercise concept changed
    final currentConceptId = _getConceptId(widget.exercise.concept);
    if (currentConceptId != _exerciseConceptId) {
      // Exercise changed, reset state synchronously (without setState during build)
      _exerciseConceptId = currentConceptId;
      _initializeConcepts();
      _audioPlayer.stop();
      _selectedCardIndex = null;
      _isCorrect = false;
      _hasAnswered = false;
      _hasStartedTracking = false;
      _hasWrongSelection = false;
      // Schedule setState for next frame and restore last selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _allConcepts.isNotEmpty) {
          // Use last selected index if valid, otherwise use 0
          final indexToSelect = _lastSelectedIndex != null && 
              _lastSelectedIndex! >= 0 && 
              _lastSelectedIndex! < _allConcepts.length
              ? _lastSelectedIndex!
              : 0;
          setState(() {
            _selectedCardIndex = indexToSelect;
          });
          _startTracking();
        }
      });
    } else {
      // Ensure tracking is started
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _startTracking();
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

          // Audio buttons in a grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 78.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 1.0,
              ),
              itemCount: _allConcepts.length,
              itemBuilder: (context, index) {
                final concept = _allConcepts[index];
                final learningLemma = concept['learning_lemma'] as Map<String, dynamic>?;
                
                if (learningLemma == null) {
                  return const SizedBox.shrink();
                }

                final learningLemmaId = learningLemma['id'] as int?;
                final learningAudioPath = learningLemma['audio_path'] as String?;
                final conceptId = _getConceptId(concept);
                
                final isSelected = _selectedCardIndex == index;
                final isCorrectAnswer = _compareIds(conceptId, _exerciseConceptId);
                final hasAudio = learningLemmaId != null && 
                    (learningAudioPath != null && learningAudioPath.isNotEmpty);

                // Determine border color based on state
                Color borderColor;
                Color backgroundColor;
                
                final defaultBorderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
                final defaultBackgroundColor = Theme.of(context).colorScheme.surface;
                
                if (_hasAnswered) {
                  if (_isCorrect) {
                    // After correct answer, only highlight the correct one
                    if (isCorrectAnswer) {
                      borderColor = Colors.green;
                      backgroundColor = Colors.green.withValues(alpha: 0.1);
                    } else {
                      borderColor = defaultBorderColor;
                      backgroundColor = defaultBackgroundColor;
                    }
                  } else {
                    // After wrong answer, only show red on selected wrong one
                    if (isSelected) {
                      borderColor = Colors.red;
                      backgroundColor = Colors.red.withValues(alpha: 0.1);
                    } else {
                      borderColor = defaultBorderColor;
                      backgroundColor = defaultBackgroundColor;
                    }
                  }
                } else if (isSelected) {
                  // Before answering, show primary color for selected
                  borderColor = Theme.of(context).colorScheme.primary;
                  backgroundColor = Theme.of(context).colorScheme.primaryContainer;
                } else {
                  borderColor = defaultBorderColor;
                  backgroundColor = defaultBackgroundColor;
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border.all(
                      color: borderColor,
                      width: (_hasAnswered && (isCorrectAnswer || (isSelected && !_isCorrect))) ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleButtonTap(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Audio button icon
                          Center(
                            child: Icon(
                              hasAudio ? Icons.volume_up : Icons.volume_off,
                              size: 24,
                              color: hasAudio
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                          // Feedback icon (green for correct, red for incorrect)
                          if (_hasAnswered && isSelected)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _isCorrect 
                                      ? Colors.green.withValues(alpha: 0.9)
                                      : Colors.red.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isCorrect ? Icons.check : Icons.close,
                                  color: Colors.white,
                                  size: 20,
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

          // Description of selected button
          if (_selectedCardIndex != null && _selectedCardIndex! < _allConcepts.length)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56.0, vertical: 26.0),
              child: Builder(
                builder: (context) {
                  final selectedConcept = _allConcepts[_selectedCardIndex!];
                  final learningLemma = selectedConcept['learning_lemma'] as Map<String, dynamic>?;
                  final description = learningLemma?['description'] as String?;
                  
                  if (description == null || description.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  
                  return Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
