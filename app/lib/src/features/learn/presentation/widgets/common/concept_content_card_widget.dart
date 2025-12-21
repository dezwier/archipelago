import 'package:flutter/material.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

/// Widget that displays concept content (term, IPA, description)
/// with toggle functionality between learning and native language
class ConceptContentCardWidget extends StatefulWidget {
  final Map<String, dynamic> learningLemma;
  final Map<String, dynamic>? nativeLemma;
  final dynamic conceptId;
  final bool autoPlay;
  final bool showNativeByDefault;
  final bool showDescription;

  const ConceptContentCardWidget({
    super.key,
    required this.learningLemma,
    this.nativeLemma,
    this.conceptId,
    this.autoPlay = false,
    this.showNativeByDefault = false,
    this.showDescription = true,
  });

  @override
  State<ConceptContentCardWidget> createState() => _ConceptContentCardWidgetState();
}

class _ConceptContentCardWidgetState extends State<ConceptContentCardWidget> {
  bool _showingLearningLanguage = true;
  bool _hasAutoPlayed = false;

  @override
  void initState() {
    super.initState();
    _showingLearningLanguage = !widget.showNativeByDefault;
  }

  @override
  void didUpdateWidget(ConceptContentCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset autoplay flag if concept changed
    if (widget.conceptId != oldWidget.conceptId) {
      _hasAutoPlayed = false;
    }
    // If autoPlay changed from false to true, reset the flag to allow autoplay
    if (widget.autoPlay && !oldWidget.autoPlay) {
      _hasAutoPlayed = false;
    }
  }

  void _toggleLanguage() {
    if (widget.nativeLemma != null) {
      setState(() {
        _showingLearningLanguage = !_showingLearningLanguage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final learningTerm = widget.learningLemma['translation'] as String? ?? 'Unknown';
    final learningIpa = widget.learningLemma['ipa'] as String?;
    final learningDescription = widget.learningLemma['description'] as String?;
    final learningLanguageCode = (widget.learningLemma['language_code'] as String? ?? '').toLowerCase();
    final learningAudioPath = widget.learningLemma['audio_path'] as String?;
    final learningLemmaId = widget.learningLemma['id'] as int?;

    final nativeTerm = widget.nativeLemma?['translation'] as String?;
    final nativeDescription = widget.nativeLemma?['description'] as String?;
    final nativeIpa = widget.nativeLemma?['ipa'] as String?;
    final nativeLanguageCode = widget.nativeLemma != null
        ? (widget.nativeLemma!['language_code'] as String? ?? '').toLowerCase()
        : null;

    final canToggle = widget.nativeLemma != null;

    // Determine if we should autoplay for this build
    final shouldAutoPlay = widget.autoPlay && !_hasAutoPlayed && _showingLearningLanguage;
    if (shouldAutoPlay) {
      _hasAutoPlayed = true;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 42.0),
      child: InkWell(
        onTap: canToggle ? _toggleLanguage : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Show learning or native language based on state
            if (_showingLearningLanguage) ...[
              // Learning Term with Language Emoji and Audio Button
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${LanguageEmoji.getEmoji(learningLanguageCode)} ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: learningTerm,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                            description: learningDescription,
                            languageCode: learningLanguageCode,
                            iconSize: 18.0,
                            autoPlay: shouldAutoPlay,
                          ),
                        ),
                      ),
                    if (canToggle)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: GestureDetector(
                            onTap: _toggleLanguage,
                            child: Icon(
                              Icons.touch_app,
                              size: 18.0,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              
              // IPA
              if (learningIpa != null && learningIpa.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '/$learningIpa/',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              // Learning Description
              if (widget.showDescription && learningDescription != null && learningDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  learningDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ] else ...[
              // Native Term with Language Emoji
              if (nativeLanguageCode != null)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${LanguageEmoji.getEmoji(nativeLanguageCode)} ',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: nativeTerm ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (canToggle)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: GestureDetector(
                              onTap: _toggleLanguage,
                              child: Icon(
                                Icons.touch_app,
                                size: 18.0,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: nativeTerm ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (canToggle)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: GestureDetector(
                              onTap: _toggleLanguage,
                              child: Icon(
                                Icons.touch_app,
                                size: 18.0,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              
              // Native IPA (if available)
              if (nativeIpa != null && nativeIpa.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '/$nativeIpa/',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              
              // Native Description
              if (widget.showDescription && nativeDescription != null && nativeDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  nativeDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

