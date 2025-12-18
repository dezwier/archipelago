import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:archipelago/src/features/dictionary/data/lemma_audio_service.dart';

/// Widget for playing lemma audio recordings.
/// 
/// Handles the flow:
/// - Checks if lemma already has audio recording stored (audio_url and file)
/// - If yes: plays this recording
/// - If no: calls the TTS endpoint, then plays and stores the recording
class LemmaAudioPlayer extends StatefulWidget {
  /// The lemma ID
  final int lemmaId;
  
  /// The current audio path/URL (may be null if audio hasn't been generated yet)
  final String? audioPath;
  
  /// The lemma term (used for TTS generation if audio doesn't exist)
  final String? term;
  
  /// Optional description (used for TTS context if audio doesn't exist)
  final String? description;
  
  /// The language code (used for TTS generation - helps Google TTS with proper pronunciation)
  final String? languageCode;
  
  /// Callback when audio URL is updated (so parent can refresh lemma data)
  final void Function(String audioUrl)? onAudioUrlUpdated;
  
  /// The icon size
  final double iconSize;
  
  /// Whether to show a loading indicator when generating/playing audio
  final bool showLoadingIndicator;

  const LemmaAudioPlayer({
    super.key,
    required this.lemmaId,
    this.audioPath,
    this.term,
    this.description,
    this.languageCode,
    this.onAudioUrlUpdated,
    this.iconSize = 16.0,
    this.showLoadingIndicator = true,
  });

  @override
  State<LemmaAudioPlayer> createState() => _LemmaAudioPlayerState();
}

class _LemmaAudioPlayerState extends State<LemmaAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  bool _isGeneratingAudio = false;
  String? _generatedAudioPath; // Track generated audio path internally

  @override
  void didUpdateWidget(LemmaAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent updated audioPath, clear internal generated path (parent now has it)
    if (widget.audioPath != null && 
        widget.audioPath!.isNotEmpty && 
        widget.audioPath != oldWidget.audioPath) {
      _generatedAudioPath = null;
    }
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
    // Check if audio already exists (from widget prop or internally generated)
    final audioPath = widget.audioPath ?? _generatedAudioPath;
    if (audioPath != null && audioPath.isNotEmpty) {
      // Audio exists, play it
      await _playExistingAudio();
    } else {
      // No audio, generate it first
      await _generateAndPlayAudio();
    }
  }

  Future<void> _playExistingAudio() async {
    setState(() {
      _isPlayingAudio = true;
    });

    try {
      // Use widget audioPath if available, otherwise use internally generated path
      final audioPath = widget.audioPath ?? _generatedAudioPath;
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No audio available')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isPlayingAudio = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  Future<void> _generateAndPlayAudio() async {
    setState(() {
      _isGeneratingAudio = true;
    });

    try {
      // Call TTS endpoint to generate audio
      final result = await LemmaAudioService.generateAudio(
        lemmaId: widget.lemmaId,
        term: widget.term,
        description: widget.description,
        languageCode: widget.languageCode,
      );

      if (!result['success']) {
        setState(() {
          _isGeneratingAudio = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to generate audio'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get the generated audio URL
      final audioUrl = result['audioUrl'] as String?;
      if (audioUrl == null) {
        setState(() {
          _isGeneratingAudio = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate audio')),
          );
        }
        return;
      }

      // Store the generated audio path internally so we can show volume icon
      setState(() {
        _generatedAudioPath = audioUrl;
        _isGeneratingAudio = false;
        _isPlayingAudio = true;
      });

      // Notify parent that audio URL was updated
      widget.onAudioUrlUpdated?.call(audioUrl);

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to play generated audio')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isGeneratingAudio = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating audio: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show spinner when generating, not when playing
    final isGenerating = _isGeneratingAudio;
    // Button is disabled when generating or playing
    final isDisabled = _isGeneratingAudio || _isPlayingAudio;
    // Check if audio exists (from widget prop or internally generated)
    final hasAudio = (widget.audioPath != null && widget.audioPath!.isNotEmpty) || 
                     (_generatedAudioPath != null && _generatedAudioPath!.isNotEmpty);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : _playAudio,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: isGenerating
              ? SizedBox(
                  width: widget.iconSize,
                  height: widget.iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : Icon(
                  hasAudio ? Icons.volume_up : Icons.auto_awesome,
                  size: widget.iconSize,
                  color: isDisabled
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
        ),
      ),
    );
  }
}

