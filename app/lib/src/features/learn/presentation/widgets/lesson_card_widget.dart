import 'package:flutter/material.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

/// Widget that displays a single lesson card with concept image, terms, IPA, descriptions, and audio
class LessonCardWidget extends StatefulWidget {
  final Map<String, dynamic> concept; // Concept with learning_lemma, native_lemma, and image_url
  final String? nativeLanguage;
  final String? learningLanguage;

  const LessonCardWidget({
    super.key,
    required this.concept,
    this.nativeLanguage,
    this.learningLanguage,
  });

  @override
  State<LessonCardWidget> createState() => _LessonCardWidgetState();
}

class _LessonCardWidgetState extends State<LessonCardWidget> {
  bool _showingLearningLanguage = true; // Start with learning language

  /// Get the full image URL
  String? _getImageUrl() {
    final imageUrl = widget.concept['image_url'] as String?;
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
  Widget build(BuildContext context) {
    final learningLemma = widget.concept['learning_lemma'] as Map<String, dynamic>?;
    final nativeLemma = widget.concept['native_lemma'] as Map<String, dynamic>?;
    final imageUrl = _getImageUrl();
    final canToggle = nativeLemma != null;

    // Debug: Print image URL to help diagnose issues
    if (imageUrl != null) {
      debugPrint('LessonCardWidget: Image URL = $imageUrl');
    } else {
      debugPrint('LessonCardWidget: No image URL found. concept keys: ${widget.concept.keys}');
      debugPrint('LessonCardWidget: image_url value = ${widget.concept['image_url']}');
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
                            lemmaId: learningLemmaId,
                            audioPath: learningAudioPath,
                            term: learningTerm,
                            description: learningDescription,
                            languageCode: learningLanguageCode,
                            iconSize: 18.0,
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

