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
  List<String> _wordPunctuation = []; // Trailing punctuation for each word
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
      _wordPunctuation = [];
      _blankIndices = [];
      return;
    }

    final phrase = learningLemma['translation'] as String? ?? '';
    _originalPhrase = phrase.trim();
    
    // Split phrase by spaces and separate words from trailing punctuation
    _allWords = [];
    _wordPunctuation = [];
    final wordParts = _originalPhrase.split(' ').where((w) => w.trim().isNotEmpty);
    
    for (final wordPart in wordParts) {
      // Match word characters followed by optional punctuation
      final match = RegExp(r'^(\w+)([^\w\s]*)$').firstMatch(wordPart.trim());
      if (match != null) {
        _allWords.add(match.group(1) ?? ''); // Word without punctuation
        _wordPunctuation.add(match.group(2) ?? ''); // Trailing punctuation
      } else {
        // Fallback: if no match, treat entire part as word
        _allWords.add(wordPart.trim());
        _wordPunctuation.add('');
      }
    }
    
    if (_allWords.isEmpty) {
      _blankIndices = [];
      return;
    }

    // Get min/max blanks from exerciseData, with defaults
    final exerciseData = widget.exercise.exerciseData;
    final minBlanks = exerciseData?['minBlanks'] as int? ?? 1;
    final maxBlanks = exerciseData?['maxBlanks'] as int? ?? 3;

    // Select random indices to blank out (but ensure at least 1 word remains visible)
    final random = Random(widget.exercise.id.hashCode);
    final numBlanks = min(maxBlanks, max(minBlanks, _allWords.length - 1));
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
        // Update the input controller with the current value for this blank
        _inputController?.text = _blankInputs[_currentBlankIndex];
        _previousInputLength = _blankInputs[_currentBlankIndex].length;
      }
      _previousInputLength = value.length;
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

    // If correct and word is complete, move to next blank or complete exercise
    if (isCorrect) {
      _handleWordComplete(_currentBlankIndex);
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

  /// Handle tap on a blank word
  void _handleBlankTap(int blankIndex) {
    if (_hasAnswered || _waitingForAudio || blankIndex >= _blankIndices.length) return;

    // If tapping on the currently focused blank, add a hint
    if (blankIndex == _currentBlankIndex) {
      _addHint(blankIndex);
    } else {
      // Switch focus to the tapped blank
      setState(() {
        _currentBlankIndex = blankIndex;
      });
      // Update the input controller with the current value for this blank
      _inputController?.text = _blankInputs[blankIndex];
      _previousInputLength = _blankInputs[blankIndex].length;
      // Focus the input field
      _inputFocusNode?.requestFocus();
    }
  }

  /// Add the next correct letter as a hint
  void _addHint(int blankIndex) {
    if (blankIndex >= _blankIndices.length) return;
    
    // Don't add hints if word is already correct
    if (blankIndex < _isCorrect.length && _isCorrect[blankIndex]) return;

    final wordIndex = _blankIndices[blankIndex];
    final expectedWord = _allWords[wordIndex];
    final currentInput = blankIndex < _blankInputs.length ? _blankInputs[blankIndex] : '';
    
    // Find the next position that needs a hint
    final normalizedExpected = _normalizeText(expectedWord);
    final normalizedInput = _normalizeText(currentInput);
    
    // Find the next missing letter
    int nextIndex = normalizedInput.length;
    if (nextIndex < normalizedExpected.length) {
      final nextLetter = normalizedExpected[nextIndex];
      final newInput = currentInput + nextLetter;
      
      // Add the hint letter directly to the input
      setState(() {
        if (blankIndex < _blankInputs.length) {
          _blankInputs[blankIndex] = newInput;
        } else {
          _blankInputs.add(newInput);
        }
      });
      
      // Update the input controller to reflect the new input
      if (blankIndex == _currentBlankIndex && _inputController != null) {
        _inputController!.text = newInput;
        _previousInputLength = newInput.length;
      }
      
      // Check if the hint makes the word correct using the same logic as typing
      final normalizedNewInput = _normalizeText(newInput);
      final isCorrect = normalizedNewInput == normalizedExpected && newInput.length == expectedWord.length;
      
      if (isCorrect) {
        setState(() {
          _isCorrect[blankIndex] = true;
        });
        
        // Move to next blank or complete exercise
        _handleWordComplete(blankIndex);
      }
    }
  }
  
  /// Handle completion of a word - move to next blank or complete exercise
  void _handleWordComplete(int blankIndex) {
    // Check if all words are completed correctly
    if (_isCorrect.every((correct) => correct == true)) {
      _handleComplete();
      return;
    }
    
    // Move to next blank if available
    if (blankIndex < _blankIndices.length - 1) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _inputController?.clear();
          _previousInputLength = 0;
          setState(() {
            // Move to next blank
            final nextIndex = blankIndex + 1;
            _currentBlankIndex = nextIndex;
          });
          _inputFocusNode?.requestFocus();
        }
      });
    }
  }

  /// Get the color for a letter at a specific position in a completed word
  /// Returns: Colors.green for correct position, Colors.orange for wrong position but present, Colors.red for not present
  Color _getLetterColor(int blankIndex, int letterIndex) {
    if (blankIndex >= _blankIndices.length) return Colors.red;
    
    final wordIndex = _blankIndices[blankIndex];
    final expectedWord = _allWords[wordIndex];
    final input = blankIndex < _blankInputs.length ? _blankInputs[blankIndex] : '';
    
    final expectedNormalized = _normalizeText(expectedWord);
    final inputNormalized = _normalizeText(input);
    
    if (letterIndex >= inputNormalized.length || letterIndex >= expectedNormalized.length) {
      return Colors.red;
    }
    
    final inputChar = inputNormalized[letterIndex];
    final expectedChar = expectedNormalized[letterIndex];
    
    // Green: letter in correct spot
    if (inputChar == expectedChar) {
      return Colors.green;
    }
    
    // Check if letter exists in the expected word
    if (!expectedNormalized.contains(inputChar)) {
      return Colors.red;
    }
    
    // Orange: letter is present in word but in wrong position
    // Mark greens first, then assign orange to remaining letters
    final greenPositions = <int>{};
    for (int i = 0; i < inputNormalized.length && i < expectedNormalized.length; i++) {
      if (inputNormalized[i] == expectedNormalized[i]) {
        greenPositions.add(i);
      }
    }
    
    // Count available orange slots for this letter (excluding green positions)
    int availableForOrange = 0;
    for (int i = 0; i < expectedNormalized.length; i++) {
      if (expectedNormalized[i] == inputChar && !greenPositions.contains(i)) {
        availableForOrange++;
      }
    }
    
    // Count orange slots used before current position
    int orangeUsedBefore = 0;
    for (int i = 0; i < letterIndex && i < inputNormalized.length; i++) {
      if (inputNormalized[i] == inputChar && !greenPositions.contains(i)) {
        orangeUsedBefore++;
      }
    }
    
    // If there are still available orange slots, this letter should be orange
    if (orangeUsedBefore < availableForOrange) {
      return Colors.orange;
    }
    
    // Otherwise, this letter occurrence exceeds what's available, so it's red
    return Colors.red;
  }

  /// Build a RichText widget for a completed word with colored letters
  /// Only shows colors when word is fully typed (same number of letters)
  Widget _buildColoredWord(int blankIndex) {
    if (blankIndex >= _blankIndices.length) return const SizedBox.shrink();
    
    final wordIndex = _blankIndices[blankIndex];
    final expectedWord = _allWords[wordIndex];
    final punctuation = wordIndex < _wordPunctuation.length ? _wordPunctuation[wordIndex] : '';
    final input = blankIndex < _blankInputs.length ? _blankInputs[blankIndex] : '';
    final isWordCorrect = blankIndex < _isCorrect.length ? _isCorrect[blankIndex] : false;
    final isCurrentBlank = blankIndex == _currentBlankIndex;
    
    // Create base style once - use exact same style for all cases
    final baseTextStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.bold,
      letterSpacing: 1,
    ) ?? const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1);
    
    // Build the widget
    Widget wordWidget;
    
    // Only show colors when word is fully typed (same number of letters)
    if (input.length != expectedWord.length) {
      // Not fully typed yet, show normal display with underscores
      // Build with TextSpan to style underscores differently
      final spans = <TextSpan>[];
      for (int i = 0; i < expectedWord.length; i++) {
        if (i < input.length) {
          // Show typed letter (including hints which are now part of input)
          spans.add(TextSpan(
            text: input[i],
            style: baseTextStyle.copyWith(
              color: isWordCorrect
                  ? Colors.green
                  : (isCurrentBlank
                      ? Colors.grey[800] // Dark gray for focused
                      : Theme.of(context).colorScheme.onSurface),
            ),
          ));
        } else {
          // Show underscore with focus-based styling
          spans.add(TextSpan(
            text: '_',
            style: baseTextStyle.copyWith(
              color: isCurrentBlank
                  ? Colors.grey[800] // Dark gray for focused
                  : Colors.grey[800], // Light gray for unfocused
              fontWeight: isCurrentBlank
                  ? FontWeight.w500 // Thicker for focused
                  : FontWeight.w200, // Thin (1px equivalent) for unfocused
            ),
          ));
        }
      }
      wordWidget = DefaultTextStyle(
        style: baseTextStyle,
        child: Text.rich(
          TextSpan(children: spans),
        ),
      );
    } else {
      // Word is fully typed, show colored letters
      // If word is correct, show all green
      if (isWordCorrect) {
        wordWidget = Text(
          expectedWord,
          style: baseTextStyle.copyWith(
            color: Colors.green,
          ),
        );
      } else {
        // Build text spans with colors for each letter (keep same style, only change color)
        final spans = <TextSpan>[];
        for (int i = 0; i < expectedWord.length; i++) {
          final color = _getLetterColor(blankIndex, i);
          spans.add(TextSpan(
            text: input[i],
            style: baseTextStyle.copyWith(
              color: color,
            ),
          ));
        }
        
        wordWidget = DefaultTextStyle(
          style: baseTextStyle,
          child: Text.rich(
            TextSpan(
              children: spans,
            ),
          ),
        );
      }
    }
    
    // Make the word tappable and include punctuation after it
    return GestureDetector(
      onTap: () => _handleBlankTap(blankIndex),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          wordWidget,
          if (punctuation.isNotEmpty)
            Text(
              punctuation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
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
                padding: const EdgeInsets.fromLTRB(78.0, 24.0, 78.0, 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
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

              const SizedBox(height: 16),

              // Learning language phrase with underscores
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Build phrase with words and underscores
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: List.generate(_allWords.length, (index) {
                        final isBlank = _blankIndices.contains(index);
                        final blankIndex = isBlank ? _blankIndices.indexOf(index) : -1;
                        final punctuation = index < _wordPunctuation.length ? _wordPunctuation[index] : '';

                        if (isBlank && blankIndex >= 0) {
                          // Show blank word - _buildColoredWord handles both incomplete and complete cases
                          return _buildColoredWord(blankIndex);
                        } else {
                          // Show word as text with punctuation
                          return Text(
                            _allWords[index] + punctuation,
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

