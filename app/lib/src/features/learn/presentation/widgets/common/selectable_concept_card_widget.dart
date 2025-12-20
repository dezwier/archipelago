import 'package:flutter/material.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

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
  });

  @override
  State<SelectableConceptCardWidget> createState() => _SelectableConceptCardWidgetState();
}

class _SelectableConceptCardWidgetState extends State<SelectableConceptCardWidget> {

  @override
  Widget build(BuildContext context) {
    // Extract data from learning lemma
    final learningTerm = widget.learningLemma['translation'] as String? ?? 'Unknown';
    final learningIpa = widget.learningLemma['ipa'] as String?;
    final learningLanguageCode = (widget.learningLemma['language_code'] as String? ?? '').toLowerCase();
    final learningAudioPath = widget.learningLemma['audio_path'] as String?;
    final learningLemmaId = widget.learningLemma['id'] as int?;

    // Determine border color based on state
    Color? borderColor;
    Color? backgroundColor;
    
    if (widget.hasAnswered) {
      if (widget.isCorrect) {
        // After correct answer, only highlight the correct one
        if (widget.isCorrectAnswer) {
          borderColor = Colors.green;
          backgroundColor = Colors.green.withValues(alpha: 0.1);
        }
      } else {
        // After wrong answer, only show red on selected wrong one
        if (widget.isSelected) {
          borderColor = Colors.red;
          backgroundColor = Colors.red.withValues(alpha: 0.1);
        }
      }
    } else if (widget.isSelected) {
      // Before answering, show primary color for selected
      borderColor = Theme.of(context).colorScheme.primary;
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
    } else {
      // Default state - subtle border like topic drawer
      borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
      backgroundColor = Theme.of(context).colorScheme.surface;
    }

    // Autoplay anytime when selected (including after answering)
    final shouldAutoPlay = widget.isSelected;

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
                color: borderColor ?? Colors.transparent,
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
                    // Title with flag inline at start and audio button inline at end
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
                    // IPA with audio button inline at end
                    if (learningIpa != null && learningIpa.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            // IPA text
                            TextSpan(
                              text: '/$learningIpa/',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            // Audio player inline at end
                            if (learningLemmaId != null)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: LemmaAudioPlayer(
                                    key: ValueKey('audio_${widget.conceptId}_$learningLemmaId'),
                                    lemmaId: learningLemmaId,
                                    audioPath: learningAudioPath,
                                    term: learningTerm,
                                    languageCode: learningLanguageCode,
                                    iconSize: 16.0,
                                    autoPlay: shouldAutoPlay,
                                    showLoadingIndicator: false,
                                    onPlaybackComplete: widget.onPlaybackComplete,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ] else if (learningLemmaId != null) ...[
                      // If no IPA, show audio button on its own line
                      const SizedBox(height: 3),
                      LemmaAudioPlayer(
                        key: ValueKey('audio_${widget.conceptId}_$learningLemmaId'),
                        lemmaId: learningLemmaId,
                        audioPath: learningAudioPath,
                        term: learningTerm,
                        languageCode: learningLanguageCode,
                        iconSize: 16.0,
                        autoPlay: shouldAutoPlay,
                        showLoadingIndicator: false,
                        onPlaybackComplete: widget.onPlaybackComplete,
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

