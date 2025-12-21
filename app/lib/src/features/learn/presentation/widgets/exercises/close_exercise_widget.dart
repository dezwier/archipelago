import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';

/// Widget that displays a Close Exercise
/// Shows an image at the top, native phrase below, and learning phrase with random words replaced by input fields
/// User types the missing words to complete the phrase
class CloseExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;

  const CloseExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  State<CloseExerciseWidget> createState() => _CloseExerciseWidgetState();
}

class _CloseExerciseWidgetState extends State<CloseExerciseWidget> {
  List<String> _allWords = [];
  List<int> _blankIndices = []; // Indices of words that should be blank
  List<String> _blankInputs = []; // Current input for each blank word
  int _currentBlankIndex = 0; // Which blank word is currently being filled
  TextEditingController? _inputController;
  FocusNode? _inputFocusNode;
  List<bool> _isCorrect = []; // Track if each word is correct
  int _previousInputLength = 0; // Track previous input length to detect backspace
  String _originalPhrase = '';
  bool _isComplete = false;
  bool _waitingForAudio = false;
  bool _hasAnswered = false;
  dynamic _exerciseConceptId;
  
  // Parameter to control number of blanks (random 1 to 5)
  static const int _minBlanks = 1;
  static const int _maxBlanks = 5;

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
  void didUpdateWidget(CloseExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when exercise changes (check both ID and concept ID)
    final oldConceptId = _getConceptId(oldWidget.exercise.concept);
    final newConceptId = _getConceptId(widget.exercise.concept);
    if (oldWidget.exercise.id != widget.exercise.id || 
        oldConceptId != newConceptId) {
      _resetState();
    }
  }

  @override
  void dispose() {
    _inputController?.dispose();
    _inputFocusNode?.dispose();
    super.dispose();
  }

  void _resetState() {
    _exerciseConceptId = _getConceptId(widget.exercise.concept);
    _initializeWords();
    if (mounted) {
      setState(() {
        _isComplete = false;
        _hasAnswered = false;
        _waitingForAudio = false;
      });
    } else {
      _isComplete = false;
      _hasAnswered = false;
      _waitingForAudio = false;
    }
  }

  void _initializeWords() {
    // Dispose old controller and focus node
    _inputController?.dispose();
    _inputFocusNode?.dispose();
    
    _blankInputs.clear();
    _isCorrect.clear();
    _currentBlankIndex = 0;

    final exerciseConcept = widget.exercise.concept;
    final learningLemma = exerciseConcept['learning_lemma'] as Map<String, dynamic>?;
    
    if (learningLemma == null) {
      _originalPhrase = '';
      _allWords = [];
      _blankIndices = [];
      return;
    }

    final phrase = learningLemma['translation'] as String? ?? '';
    _originalPhrase = phrase.trim();
    
    // Split phrase by spaces to get words, trim each word
    _allWords = _originalPhrase.split(' ').where((w) => w.trim().isNotEmpty).map((w) => w.trim()).toList();
    
    if (_allWords.isEmpty) {
      _blankIndices = [];
      return;
    }

    // Select random indices to blank out (1 to 5, but ensure at least 1 word remains visible)
    final random = Random(widget.exercise.id.hashCode);
    final numBlanks = min(_maxBlanks, max(_minBlanks, _allWords.length - 1));
    final availableIndices = List.generate(_allWords.length, (i) => i);
    availableIndices.shuffle(random);
    _blankIndices = availableIndices.take(numBlanks).toList()..sort();

    // Initialize blank inputs and correctness tracking
    for (int i = 0; i < _blankIndices.length; i++) {
      _blankInputs.add('');
      _isCorrect.add(false);
    }

    // Create single input controller and focus node
    _inputController = TextEditingController();
    _inputFocusNode = FocusNode();
    _previousInputLength = 0;

    // Autofocus input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inputFocusNode != null) {
        _inputFocusNode!.requestFocus();
      }
    });
  }

  /// Normalize text by removing all symbols/punctuation, converting to lowercase, and trimming
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove all symbols/punctuation
        .trim();
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

  void _handleTextChange(String value) {
    if (_hasAnswered || _waitingForAudio || _currentBlankIndex >= _blankIndices.length) return;

    // Ignore empty values (happens when controller is cleared programmatically)
    if (value.isEmpty && _previousInputLength == 0) {
      return;
    }

    // Detect backspace (input length decreased)
    final isBackspace = value.length < _previousInputLength && value.isNotEmpty;
    final wasBackspaceToEmpty = value.isEmpty && _previousInputLength > 0;
    
    if (wasBackspaceToEmpty) {
      // Handle backspace that cleared the field
      if (_blankInputs[_currentBlankIndex].isNotEmpty) {
        setState(() {
          _blankInputs[_currentBlankIndex] = _blankInputs[_currentBlankIndex].substring(
            0,
            _blankInputs[_currentBlankIndex].length - 1
          );
          _isCorrect[_currentBlankIndex] = false;
        });
      } else if (_currentBlankIndex > 0) {
        // Move to previous blank if current is empty
        setState(() {
          _currentBlankIndex--;
        });
      }
      _previousInputLength = 0;
      return;
    }

    if (isBackspace) {
      // Handle backspace (partial deletion)
      if (_blankInputs[_currentBlankIndex].isNotEmpty) {
        setState(() {
          _blankInputs[_currentBlankIndex] = _blankInputs[_currentBlankIndex].substring(
            0,
            _blankInputs[_currentBlankIndex].length - 1
          );
          _isCorrect[_currentBlankIndex] = false;
        });
      }
      _previousInputLength = value.length;
      return;
    }

    // Limit input to the length of the expected word
    final wordIndex = _blankIndices[_currentBlankIndex];
    final expectedWord = _allWords[wordIndex];
    final maxLength = expectedWord.length;
    
    // Only keep characters up to maxLength
    final limitedValue = value.length > maxLength ? value.substring(0, maxLength) : value;
    
    // Update input
    setState(() {
      _blankInputs[_currentBlankIndex] = limitedValue;
    });

    // Check if current word is correct
    final normalizedInput = _normalizeText(limitedValue);
    final normalizedExpected = _normalizeText(expectedWord);
    final isCorrect = normalizedInput == normalizedExpected && limitedValue.length == expectedWord.length;

    setState(() {
      _isCorrect[_currentBlankIndex] = isCorrect;
    });

    _previousInputLength = limitedValue.length;

    // If correct and word is complete, move to next blank
    if (isCorrect && _currentBlankIndex < _blankIndices.length - 1) {
      // Clear input and move to next blank
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _inputController?.clear();
          _previousInputLength = 0;
          if (_currentBlankIndex < _blankIndices.length - 1) {
            setState(() {
              _currentBlankIndex++;
            });
            _inputFocusNode?.requestFocus();
          }
        }
      });
    }

    // Check if all words are completed correctly
    if (isCorrect && _isCorrect.every((correct) => correct == true)) {
      _handleComplete();
    }
  }

  void _handleComplete() {
    if (_hasAnswered || _waitingForAudio) return;

    setState(() {
      _isComplete = true;
      _hasAnswered = true;
      _waitingForAudio = true;
    });

    // Unfocus input field
    _inputFocusNode?.unfocus();

    // Audio will be played by LemmaAudioPlayer widget
    // Add timeout fallback in case audio doesn't play or fails
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isComplete && _waitingForAudio) {
        // Audio didn't complete within timeout, proceed anyway
        setState(() {
          _waitingForAudio = false;
        });
        widget.onComplete();
      }
    });
  }

  /// Get the display text for a blank word (underscores with typed letters, or original word if correct)
  String _getBlankDisplayText(int blankIndex) {
    if (blankIndex >= _blankIndices.length) return '';
    
    final wordIndex = _blankIndices[blankIndex];
    final expectedWord = _allWords[wordIndex];
    final isWordCorrect = blankIndex < _isCorrect.length ? _isCorrect[blankIndex] : false;
    
    // If word is correct, show the original word with case and symbols
    if (isWordCorrect) {
      return expectedWord;
    }
    
    final input = blankIndex < _blankInputs.length ? _blankInputs[blankIndex] : '';
    
    // Build display: typed letters + remaining underscores
    final display = StringBuffer();
    for (int i = 0; i < expectedWord.length; i++) {
      if (i < input.length) {
        display.write(input[i]);
      } else {
        display.write('_');
      }
    }
    return display.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Safeguard: Ensure state is reset if exercise concept changed
    final currentConceptId = _getConceptId(widget.exercise.concept);
    if (currentConceptId != _exerciseConceptId) {
      // Exercise changed, reset state synchronously (without setState during build)
      _exerciseConceptId = currentConceptId;
      _initializeWords();
      _isComplete = false;
      _hasAnswered = false;
      _waitingForAudio = false;
      // Schedule setState for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
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

    if (learningLemma == null || _originalPhrase.isEmpty || _allWords.isEmpty) {
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Learning language phrase with underscores
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete the phrase:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Build phrase with words and underscores
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(_allWords.length, (index) {
                        final isBlank = _blankIndices.contains(index);
                        final blankIndex = isBlank ? _blankIndices.indexOf(index) : -1;

                        if (isBlank && blankIndex >= 0) {
                          // Show blank word with underscores
                          final isWordCorrect = blankIndex < _isCorrect.length ? _isCorrect[blankIndex] : false;
                          final isCurrentBlank = blankIndex == _currentBlankIndex;
                          final displayText = _getBlankDisplayText(blankIndex);
                          
                          return Text(
                            displayText,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isWordCorrect
                                  ? Colors.green
                                  : (isCurrentBlank
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface),
                              fontWeight: isCurrentBlank ? FontWeight.bold : FontWeight.bold,
                              letterSpacing: 1, // Keep same letter spacing whether correct or not
                            ),
                          );
                        } else {
                          // Show word as text
                          return Text(
                            _allWords[index],
                            style: Theme.of(context).textTheme.bodyLarge,
                          );
                        }
                      }),
                    ),
                    // Hidden TextField to capture input
                    if (!_hasAnswered && !_waitingForAudio && _inputController != null && _inputFocusNode != null)
                      SizedBox(
                        width: 0,
                        height: 0,
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          autofocus: true,
                          onChanged: _handleTextChange,
                          style: const TextStyle(color: Colors.transparent),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
        // Hidden audio player for autoplay
        if (learningLemmaId != null && _isComplete && _hasAnswered && _waitingForAudio)
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
                if (mounted && _isComplete && _waitingForAudio) {
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

