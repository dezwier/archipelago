import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/dictionary/data/lemma_audio_service.dart';
import 'package:archipelago/src/constants/api_config.dart';

/// Display mode for the selectable concept card
enum CardDisplayMode {
  /// Show phrase (term + IPA)
  phrase,
  /// Show description text
  description,
}

/// A selectable card widget for concept options in exercises
/// Inspired by the topic drawer styling pattern
/// Shows title and IPA in an elegant layout, autoplays audio when selected
class SelectableConceptCardWidget extends StatefulWidget {
  final Map<String, dynamic> learningLemma;
  final Map<String, dynamic>? nativeLemma;
  final dynamic conceptId;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool hasAnswered;
  final bool isCorrect;
  final VoidCallback onTap;
  final VoidCallback? onPlaybackComplete;
  final CardDisplayMode displayMode;
  final bool autoPlay;

  const SelectableConceptCardWidget({
    super.key,
    required this.learningLemma,
    this.nativeLemma,
    this.conceptId,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.hasAnswered,
    required this.isCorrect,
    required this.onTap,
    this.onPlaybackComplete,
    this.displayMode = CardDisplayMode.phrase,
    this.autoPlay = true,
  });

  @override
  State<SelectableConceptCardWidget> createState() => _SelectableConceptCardWidgetState();
}

class _SelectableConceptCardWidgetState extends State<SelectableConceptCardWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasAutoPlayed = false;
  String? _generatedAudioPath;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SelectableConceptCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Play audio when card becomes selected (only if autoPlay is enabled)
    if (widget.autoPlay && widget.isSelected && !oldWidget.isSelected && !_hasAutoPlayed) {
      _hasAutoPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _playAudio();
        }
      });
    }
    // Reset autoplay flag when card becomes unselected
    if (!widget.isSelected && oldWidget.isSelected) {
      _hasAutoPlayed = false;
    }
  }

  String? _getFullAudioUrl(String? audioPath) {
    if (audioPath == null || audioPath.isEmpty) return null;
    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      return audioPath;
    }
    return '${ApiConfig.baseUrl}$audioPath';
  }

  Future<void> _playAudio() async {
    final learningAudioPath = widget.learningLemma['audio_path'] as String?;
    final learningLemmaId = widget.learningLemma['id'] as int?;
    final learningTerm = widget.learningLemma['translation'] as String?;
    final learningLanguageCode = (widget.learningLemma['language_code'] as String? ?? '').toLowerCase();

    if (learningLemmaId == null) return;

    // Check if audio already exists
    final audioPath = learningAudioPath ?? _generatedAudioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      // Audio exists, play it
      await _playExistingAudio(audioPath);
    } else {
      // No audio, generate it first
      await _generateAndPlayAudio(learningLemmaId, learningTerm, learningLanguageCode);
    }
  }

  Future<void> _playExistingAudio(String audioPath) async {
    try {
      final audioUrl = _getFullAudioUrl(audioPath);
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
        _audioPlayer.onPlayerComplete.first.then((_) {
          if (mounted) {
            widget.onPlaybackComplete?.call();
          }
        });
      }
    } catch (e) {
      // Silently fail - don't show errors for audio playback
    }
  }

  Future<void> _generateAndPlayAudio(int lemmaId, String? term, String? languageCode) async {
    try {
      final result = await LemmaAudioService.generateAudio(
        lemmaId: lemmaId,
        term: term,
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

  @override
  Widget build(BuildContext context) {
    // Extract data from learning lemma
    final learningTerm = widget.learningLemma['translation'] as String? ?? 'Unknown';
    final learningIpa = widget.learningLemma['ipa'] as String?;
    final learningDescription = widget.learningLemma['description'] as String?;
    final learningLanguageCode = (widget.learningLemma['language_code'] as String? ?? '').toLowerCase();

    // Determine border color based on state
    Color borderColor;
    Color backgroundColor;
    
    // Default state - subtle border like topic drawer (applies to all unselected cards)
    final defaultBorderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
    final defaultBackgroundColor = Theme.of(context).colorScheme.surface;
    
    if (widget.hasAnswered) {
      if (widget.isCorrect) {
        // After correct answer, only highlight the correct one
        if (widget.isCorrectAnswer) {
          borderColor = Colors.green;
          backgroundColor = Colors.green.withValues(alpha: 0.1);
        } else {
          // Keep default style for other cards
          borderColor = defaultBorderColor;
          backgroundColor = defaultBackgroundColor;
        }
      } else {
        // After wrong answer, only show red on selected wrong one
        if (widget.isSelected) {
          borderColor = Colors.red;
          backgroundColor = Colors.red.withValues(alpha: 0.1);
        } else {
          // Keep default style for other cards
          borderColor = defaultBorderColor;
          backgroundColor = defaultBackgroundColor;
        }
      }
    } else if (widget.isSelected) {
      // Before answering, show primary color for selected
      borderColor = Theme.of(context).colorScheme.primary;
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
    } else {
      // Default state - subtle border like topic drawer
      borderColor = defaultBorderColor;
      backgroundColor = defaultBackgroundColor;
    }


    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SizedBox(
        width: double.infinity,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: borderColor,
                width: widget.isSelected || (widget.hasAnswered && (widget.isCorrectAnswer || (widget.isSelected && !widget.isCorrect))) ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
          child: Stack(
            children: [
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.displayMode == CardDisplayMode.phrase) ...[
                      // Phrase mode: Title with flag inline at start
                      Text.rich(
                        TextSpan(
                          children: [
                            // Flag emoji at start
                            TextSpan(
                              text: '${LanguageEmoji.getEmoji(learningLanguageCode)} ',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: widget.isSelected && !widget.hasAnswered
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            // Title text
                            TextSpan(
                              text: learningTerm,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: widget.isSelected && !widget.hasAnswered
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // IPA text
                      if (learningIpa != null && learningIpa.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '/$learningIpa/',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ] else ...[
                      // Description mode: Flag emoji + description text
                      Text.rich(
                        TextSpan(
                          children: [
                            // Flag emoji at start
                            TextSpan(
                              text: '${LanguageEmoji.getEmoji(learningLanguageCode)} ',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: widget.isSelected && !widget.hasAnswered
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            // Description text
                            TextSpan(
                              text: learningDescription ?? 'No description',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: widget.isSelected && !widget.hasAnswered
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Feedback icon (green for correct, red for incorrect)
              if (widget.hasAnswered && widget.isSelected)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.isCorrect 
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
                      widget.isCorrect ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

