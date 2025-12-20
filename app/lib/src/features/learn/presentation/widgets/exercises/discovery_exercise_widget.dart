import 'package:flutter/material.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/concept_content_card_widget.dart';

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

    final conceptId = widget.exercise.concept['id'] ?? widget.exercise.concept['concept_id'];

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

          // Content card with toggle functionality
          ConceptContentCardWidget(
            learningLemma: learningLemma,
            nativeLemma: nativeLemma,
            conceptId: conceptId,
            autoPlay: shouldAutoPlay,
          ),
        ],
      ),
    );
  }
}

