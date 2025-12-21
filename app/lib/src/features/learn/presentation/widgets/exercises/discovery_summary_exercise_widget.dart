import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/learn/domain/exercise.dart';
import 'package:archipelago/src/features/dictionary/data/lemma_audio_service.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

/// Widget that displays a Discovery Summary exercise showing all concepts in a 2x2 grid
class DiscoverySummaryExerciseWidget extends StatefulWidget {
  final Exercise exercise;
  final String? nativeLanguage;
  final String? learningLanguage;
  final bool autoPlay;
  final VoidCallback onComplete;

  const DiscoverySummaryExerciseWidget({
    super.key,
    required this.exercise,
    this.nativeLanguage,
    this.learningLanguage,
    this.autoPlay = false,
    required this.onComplete,
  });

  @override
  State<DiscoverySummaryExerciseWidget> createState() => _DiscoverySummaryExerciseWidgetState();
}

class _DiscoverySummaryExerciseWidgetState extends State<DiscoverySummaryExerciseWidget> {
  final List<AudioPlayer> _audioPlayers = [];

  void _registerAudioPlayer(AudioPlayer player) {
    _audioPlayers.add(player);
  }

  void _stopAllOtherAudio(AudioPlayer currentPlayer) {
    for (final player in _audioPlayers) {
      if (player != currentPlayer) {
        player.stop();
      }
    }
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

  @override
  Widget build(BuildContext context) {
    // Get all concepts from exercise data
    final allConcepts = widget.exercise.exerciseData?['all_concepts'] as List<dynamic>?;
    
    if (allConcepts == null || allConcepts.isEmpty) {
      return const Center(
        child: Text('No concepts available'),
      );
    }

    // Take up to 4 concepts for 2x2 grid
    final conceptsToShow = allConcepts.take(4).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.75,
          ),
          itemCount: conceptsToShow.length,
          itemBuilder: (context, index) {
            final concept = conceptsToShow[index] as Map<String, dynamic>;
            final learningLemma = concept['learning_lemma'] as Map<String, dynamic>?;
            final imageUrl = _getImageUrl(concept['image_url'] as String?);
            
            if (learningLemma == null) {
              return const SizedBox.shrink();
            }

            final learningTerm = learningLemma['translation'] as String? ?? 'Unknown';
            final learningLanguageCode = (learningLemma['language_code'] as String? ?? '').toLowerCase();
            final learningAudioPath = learningLemma['audio_path'] as String?;
            final learningLemmaId = learningLemma['id'] as int?;
            final conceptId = concept['id'] ?? concept['concept_id'];

            return _SummaryConceptCard(
              imageUrl: imageUrl,
              learningTerm: learningTerm,
              learningLanguageCode: learningLanguageCode,
              learningAudioPath: learningAudioPath,
              learningLemmaId: learningLemmaId,
              conceptId: conceptId,
              onAudioPlayerCreated: _registerAudioPlayer,
              onAudioPlayStart: _stopAllOtherAudio,
            );
          },
        ),
      ),
    );
  }
}

/// Individual concept card in the summary grid
class _SummaryConceptCard extends StatefulWidget {
  final String? imageUrl;
  final String learningTerm;
  final String learningLanguageCode;
  final String? learningAudioPath;
  final int? learningLemmaId;
  final dynamic conceptId;
  final void Function(AudioPlayer)? onAudioPlayerCreated;
  final void Function(AudioPlayer)? onAudioPlayStart;

  const _SummaryConceptCard({
    required this.imageUrl,
    required this.learningTerm,
    required this.learningLanguageCode,
    this.learningAudioPath,
    this.learningLemmaId,
    this.conceptId,
    this.onAudioPlayerCreated,
    this.onAudioPlayStart,
  });

  @override
  State<_SummaryConceptCard> createState() => _SummaryConceptCardState();
}

class _SummaryConceptCardState extends State<_SummaryConceptCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  bool _isGeneratingAudio = false;
  String? _generatedAudioPath;

  @override
  void initState() {
    super.initState();
    // Register this audio player with the parent
    widget.onAudioPlayerCreated?.call(_audioPlayer);
    
    // Listen to player state changes to update UI when audio is stopped externally
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted && state == PlayerState.stopped && _isPlayingAudio) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String? _getFullAudioUrl(String? audioPath) {
    return LemmaAudioService.getAudioUrl(audioPath);
  }

  Future<void> _playAudio() async {
    if (widget.learningLemmaId == null) return;

    // Check if audio already exists
    final audioPath = widget.learningAudioPath ?? _generatedAudioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      await _playExistingAudio(audioPath);
    } else {
      await _generateAndPlayAudio();
    }
  }

  Future<void> _playExistingAudio(String audioPath) async {
    // Stop all other audio players before starting this one
    widget.onAudioPlayStart?.call(_audioPlayer);
    
    setState(() {
      _isPlayingAudio = true;
    });

    try {
      final audioUrl = _getFullAudioUrl(audioPath);
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
            });
          }
        });
      } else {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    } catch (e) {
      setState(() {
        _isPlayingAudio = false;
      });
    }
  }

  Future<void> _generateAndPlayAudio() async {
    if (widget.learningLemmaId == null) return;

    setState(() {
      _isGeneratingAudio = true;
    });

    try {
      final result = await LemmaAudioService.generateAudio(
        lemmaId: widget.learningLemmaId!,
        term: widget.learningTerm,
        languageCode: widget.learningLanguageCode,
      );

      if (!result['success']) {
        setState(() {
          _isGeneratingAudio = false;
        });
        return;
      }

      final audioUrl = result['audioUrl'] as String?;
      if (audioUrl == null) {
        setState(() {
          _isGeneratingAudio = false;
        });
        return;
      }

      setState(() {
        _generatedAudioPath = audioUrl;
        _isGeneratingAudio = false;
        _isPlayingAudio = true;
      });

      // Stop all other audio players before starting this one
      widget.onAudioPlayStart?.call(_audioPlayer);

      final fullAudioUrl = _getFullAudioUrl(audioUrl);
      if (fullAudioUrl != null) {
        await _audioPlayer.play(UrlSource(fullAudioUrl));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
            });
          }
        });
      } else {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    } catch (e) {
      setState(() {
        _isGeneratingAudio = false;
        _isPlayingAudio = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isPlayingAudio || _isGeneratingAudio ? null : _playAudio,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Square image with rounded corners
          Flexible(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.imageUrl != null
                        ? Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image,
                                  size: 32,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                  // Loading indicator overlay
                  if (_isGeneratingAudio || _isPlayingAudio)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: _isGeneratingAudio
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.volume_up,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Full title (greyer color)
          Text(
            '${LanguageEmoji.getEmoji(widget.learningLanguageCode)} ${widget.learningTerm}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}

