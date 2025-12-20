import 'package:flutter/material.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';

/// Widget that displays a Discovery exercise
/// This reuses the logic from LessonCardWidget - just showing the concept
class DiscoveryExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete; // Called when user is ready to continue

  const DiscoveryExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  State<DiscoveryExerciseWidget> createState() => _DiscoveryExerciseWidgetState();
}

class _DiscoveryExerciseWidgetState extends State<DiscoveryExerciseWidget> {
  bool _showingLearningLanguage = true; // Start with learning language
  bool _hasAutoPlayed = false; // Track if we've autoplayed for this card instance

  /// Get the full image URL
  String? _getImageUrl() {
    final imageUrl = widget.exercise.concept['image_url'] as String?;
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

  void _toggleLanguage() {
    setState(() {
      _showingLearningLanguage = !_showingLearningLanguage;
    });
  }

  @override
  void didUpdateWidget(DiscoveryExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset autoplay flag if we navigated to a different exercise
    if (widget.exercise.id != oldWidget.exercise.id) {
      _hasAutoPlayed = false;
    }
    // If autoPlay changed from false to true, reset the flag to allow autoplay
    if (widget.autoPlay && !oldWidget.autoPlay) {
      _hasAutoPlayed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final learningLemma = widget.exercise.concept['learning_lemma'] as Map<String, dynamic>?;
    final nativeLemma = widget.exercise.concept['native_lemma'] as Map<String, dynamic>?;
    final imageUrl = _getImageUrl();
    final canToggle = nativeLemma != null;
    
    // Determine if we should autoplay for this build
    final shouldAutoPlay = widget.autoPlay && !_hasAutoPlayed;
    if (shouldAutoPlay) {
      _hasAutoPlayed = true;
    }

    if (learningLemma == null) {
      return const Center(
        child: Text('Invalid concept data'),
      );
    }

    final learningTerm = learningLemma['translation'] as String? ?? 'Unknown';
    final learningIpa = learningLemma['ipa'] as String?;
    final learningDescription = learningLemma['description'] as String?;
    final learningLanguageCode = (learningLemma['language_code'] as String? ?? '').toLowerCase();
    final learningAudioPath = learningLemma['audio_path'] as String?;
    final learningLemmaId = learningLemma['id'] as int?;

    final nativeTerm = nativeLemma?['translation'] as String?;
    final nativeDescription = nativeLemma?['description'] as String?;
    final nativeIpa = nativeLemma?['ipa'] as String?;
    final nativeLanguageCode = nativeLemma != null 
        ? (nativeLemma['language_code'] as String? ?? '').toLowerCase()
        : null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Concept Image - Square with rounded corners
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 78.0, vertical: 24.0),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
              ),
            ),
          ),

          // Tappable content area that toggles between learning and native language
          InkWell(
            onTap: canToggle ? _toggleLanguage : null,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show learning or native language based on state
                  if (_showingLearningLanguage) ...[
                    // Learning Term with Language Emoji and Audio Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text.rich(
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
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (learningLemmaId != null) ...[
                          const SizedBox(width: 6),
                          LemmaAudioPlayer(
                            key: ValueKey('audio_${widget.exercise.concept['id']}_$learningLemmaId'),
                            lemmaId: learningLemmaId,
                            audioPath: learningAudioPath,
                            term: learningTerm,
                            description: learningDescription,
                            languageCode: learningLanguageCode,
                            iconSize: 18.0,
                            autoPlay: shouldAutoPlay,
                          ),
                        ],
                      ],
                    ),
                    
                    // IPA
                    if (learningIpa != null && learningIpa.isNotEmpty) ...[
                      const SizedBox(height: 3),
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
                    if (learningDescription != null && learningDescription.isNotEmpty) ...[
                      const SizedBox(height: 16),
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
                          ],
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      Text(
                        nativeTerm ?? 'Unknown',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    
                    // Native IPA (if available)
                    if (nativeIpa != null && nativeIpa.isNotEmpty) ...[
                      const SizedBox(height: 3),
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
                    if (nativeDescription != null && nativeDescription.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        nativeDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                  
                  // Hint text if toggle is available
                  if (canToggle) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tap to switch',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

