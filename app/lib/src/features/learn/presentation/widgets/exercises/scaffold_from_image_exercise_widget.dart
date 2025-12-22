import 'dart:math';
import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/domain/exercise_performance.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';

/// Widget that displays a Scaffold From Image exercise
/// Shows an image at the top, phrase builder in the middle, and shuffled word buttons at the bottom
/// User builds the phrase by selecting words in the correct order
class ScaffoldFromImageExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;
  final Function(Exercise exercise)? onExerciseStart;
  final Function(Exercise exercise, ExerciseOutcome outcome, {int? hintCount, String? failureReason})? onExerciseComplete;

  const ScaffoldFromImageExerciseWidget({
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
  State<ScaffoldFromImageExerciseWidget> createState() => _ScaffoldFromImageExerciseWidgetState();
}

class _ScaffoldFromImageExerciseWidgetState extends State<ScaffoldFromImageExerciseWidget> {
  List<String> _selectedWords = [];
  List<String> _availableWords = [];
  List<String> _expectedWords = []; // The correct order of words
  List<bool?> _wordCorrectness = []; // null = not checked, true = correct, false = incorrect
  String _originalPhrase = '';
  bool _isCorrect = false;
  bool _waitingForAudio = false;
  bool _hasAnswered = false;
  dynamic _exerciseConceptId;
  bool _hasStartedTracking = false;
  bool _hasWrongOrder = false;

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
  void didUpdateWidget(ScaffoldFromImageExerciseWidget oldWidget) {
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
    _initializeWords();
    if (mounted) {
      setState(() {
        _selectedWords = [];
        _wordCorrectness = [];
        _isCorrect = false;
        _hasAnswered = false;
        _waitingForAudio = false;
        _hasStartedTracking = false;
        _hasWrongOrder = false;
      });
    } else {
      _selectedWords = [];
      _wordCorrectness = [];
      _isCorrect = false;
      _hasAnswered = false;
      _waitingForAudio = false;
      _hasStartedTracking = false;
      _hasWrongOrder = false;
    }
  }

  void _initializeWords() {
    final exerciseConcept = widget.exercise.concept;
    final learningLemma = exerciseConcept['learning_lemma'] as Map<String, dynamic>?;
    
    if (learningLemma == null) {
      _originalPhrase = '';
      _availableWords = [];
      _expectedWords = [];
      return;
    }

    final phrase = learningLemma['translation'] as String? ?? '';
    _originalPhrase = phrase.trim();
    
    // Split phrase by spaces to get words, trim each word
    final words = _originalPhrase.split(' ').where((w) => w.trim().isNotEmpty).map((w) => w.trim()).toList();
    _expectedWords = words;
    
    // Shuffle words using exercise ID as seed for consistency
    final random = Random(widget.exercise.id.hashCode);
    _availableWords = List<String>.from(words)..shuffle(random);
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

  void _handleWordButtonTap(String word) {
    if (_hasAnswered || _waitingForAudio) return;
    
    final selectedIndex = _selectedWords.length;
    bool isCorrect = false;
    
    if (selectedIndex < _expectedWords.length) {
      // Normalize both words for comparison (case-insensitive, trimmed)
      final expectedWord = _expectedWords[selectedIndex].toLowerCase().trim();
      final tappedWord = word.toLowerCase().trim();
      isCorrect = expectedWord == tappedWord;
    }
    
    setState(() {
      _selectedWords.add(word);
      _wordCorrectness.add(isCorrect);
      _availableWords.remove(word);
      
      // Track wrong order
      if (!isCorrect && !_hasWrongOrder) {
        _hasWrongOrder = true;
      }
    });

    // Check if all words are selected and all are correct
    if (_availableWords.isEmpty) {
      final allCorrect = _wordCorrectness.every((correct) => correct == true);
      if (allCorrect) {
        _handleComplete();
      }
    }
  }

  void _handlePhraseWordTap(int index) {
    if (_hasAnswered || _waitingForAudio) return;
    
    final word = _selectedWords[index];
    setState(() {
      _selectedWords.removeAt(index);
      _wordCorrectness.removeAt(index);
      _availableWords.add(word);
      
      // Re-check all remaining words after removal
      _recheckAllWords();
    });
  }

  void _recheckAllWords() {
    // Re-evaluate correctness of all selected words
    _wordCorrectness.clear();
    for (int i = 0; i < _selectedWords.length; i++) {
      if (i < _expectedWords.length) {
        final expectedWord = _expectedWords[i].toLowerCase().trim();
        final selectedWord = _selectedWords[i].toLowerCase().trim();
        final isCorrect = expectedWord == selectedWord;
        _wordCorrectness.add(isCorrect);
        
        // Track wrong order
        if (!isCorrect && !_hasWrongOrder) {
          _hasWrongOrder = true;
        }
      } else {
        _wordCorrectness.add(false);
        if (!_hasWrongOrder) {
          _hasWrongOrder = true;
        }
      }
    }
  }

  void _handleResetAll() {
    if (_hasAnswered || _waitingForAudio) return;
    
    setState(() {
      // Move all selected words back to available
      _availableWords.addAll(_selectedWords);
      _selectedWords.clear();
      _wordCorrectness.clear();
      // Re-shuffle available words
      final random = Random(widget.exercise.id.hashCode);
      _availableWords.shuffle(random);
    });
  }

  void _handleComplete() {
    setState(() {
      _isCorrect = true;
      _hasAnswered = true;
      _waitingForAudio = true;
    });

    // Determine outcome
    final outcome = _hasWrongOrder ? ExerciseOutcome.failed : ExerciseOutcome.succeeded;
    
    // Report completion
    if (widget.onExerciseComplete != null) {
      widget.onExerciseComplete!(
        widget.exercise,
        outcome,
        failureReason: _hasWrongOrder ? 'Wrong order at some point' : null,
      );
    }

    // Audio will be played by LemmaAudioPlayer widget
    // Add timeout fallback in case audio doesn't play or fails
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isCorrect && _waitingForAudio) {
        // Audio didn't complete within timeout, proceed anyway
        setState(() {
          _waitingForAudio = false;
        });
        widget.onComplete();
      }
    });
  }


  Widget _buildWordButton(String word, bool isDisabled) {
    return GestureDetector(
      onTap: isDisabled ? null : () => _handleWordButtonTap(word),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDisabled
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDisabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          word,
          style: TextStyle(
            color: isDisabled
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildPhraseWordButton(String word, int index) {
    final isCorrect = index < _wordCorrectness.length ? _wordCorrectness[index] : null;
    final showFeedback = isCorrect != null;
    
    Color borderColor;
    Color backgroundColor;
    Color textColor;
    
    if (showFeedback) {
      if (isCorrect == true) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green.shade700;
      } else {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red.shade700;
      }
    } else {
      borderColor = Theme.of(context).colorScheme.primary;
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
      textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    }
    
    return GestureDetector(
      onTap: () => _handlePhraseWordTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Text(
          word,
          style: TextStyle(
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safeguard: Ensure state is reset if exercise concept changed
    final currentConceptId = _getConceptId(widget.exercise.concept);
    if (currentConceptId != _exerciseConceptId) {
      // Exercise changed, reset state synchronously (without setState during build)
      _exerciseConceptId = currentConceptId;
      _initializeWords();
      _selectedWords = [];
      _wordCorrectness = [];
      _isCorrect = false;
      _hasAnswered = false;
      _waitingForAudio = false;
      _hasStartedTracking = false;
      _hasWrongOrder = false;
      // Schedule setState for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
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
    
    // Get the exercise concept
    final exerciseConcept = widget.exercise.concept;
    final imageUrl = _getImageUrl(exerciseConcept['image_url'] as String?);
    final learningLemma = exerciseConcept['learning_lemma'] as Map<String, dynamic>?;
    final nativeLemma = exerciseConcept['native_lemma'] as Map<String, dynamic>?;
    
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

    if (learningLemma == null || _originalPhrase.isEmpty) {
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
              'No phrase available for this concept',
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

    // Hidden audio player for autoplay when correct
    final learningLemmaId = learningLemma['id'] as int?;
    final learningAudioPath = learningLemma['audio_path'] as String?;
    final learningTerm = learningLemma['translation'] as String?;
    final learningLanguageCode = (learningLemma['language_code'] as String? ?? '').toLowerCase();

    return Stack(
      children: [
        SingleChildScrollView(
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

              // Native language phrase below image
              if (nativeLemma != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Text(
                      nativeLemma['translation'] as String? ?? '',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Phrase builder section (middle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Build the phrase:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        if (_selectedWords.isNotEmpty && !_hasAnswered && !_waitingForAudio)
                          TextButton(
                            onPressed: _handleResetAll,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Reset',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                decorationColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_selectedWords.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Tap words below to build the phrase',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedWords.asMap().entries.map((entry) {
                          return _buildPhraseWordButton(entry.value, entry.key);
                        }).toList(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // Word buttons section (bottom)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available words:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableWords.map((word) {
                        return _buildWordButton(word, false);
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
        // Hidden audio player for autoplay
        if (learningLemmaId != null && _isCorrect && _hasAnswered && _waitingForAudio)
          Positioned(
            left: -1000,
            top: -1000,
            child: LemmaAudioPlayer(
              lemmaId: learningLemmaId,
              audioPath: learningAudioPath,
              term: learningTerm,
              languageCode: learningLanguageCode,
              autoPlay: true,
              onPlaybackComplete: () {
                if (mounted && _isCorrect && _waitingForAudio) {
                  setState(() {
                    _waitingForAudio = false;
                  });
                  widget.onComplete();
                }
              },
            ),
          ),
      ],
    );
  }
}

