import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../../../utils/language_emoji.dart';
import '../../../../constants/api_config.dart';
import '../../domain/vocabulary_card.dart';

class LanguageLemmaWidget extends StatefulWidget {
  final VocabularyCard card;
  final String languageCode;
  final bool showDescription;
  final bool showExtraInfo;
  final TextEditingController? translationController;
  final bool isEditing;
  final VoidCallback? onTranslationChanged;
  final String? partOfSpeech;

  const LanguageLemmaWidget({
    super.key,
    required this.card,
    required this.languageCode,
    this.showDescription = true,
    this.showExtraInfo = true,
    this.translationController,
    this.isEditing = false,
    this.onTranslationChanged,
    this.partOfSpeech,
  });

  @override
  State<LanguageLemmaWidget> createState() => _LanguageLemmaWidgetState();
}

class _LanguageLemmaWidgetState extends State<LanguageLemmaWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  String? _getFullAudioUrl(String? audioPath) {
    if (audioPath == null || audioPath.isEmpty) return null;
    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      return audioPath;
    }
    return '${ApiConfig.baseUrl}$audioPath';
  }

  Future<void> _playAudio() async {
    if (widget.card.audioPath == null || widget.card.audioPath!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio available')),
        );
      }
      return;
    }

    setState(() {
      _isPlayingAudio = true;
    });

    try {
      final audioUrl = _getFullAudioUrl(widget.card.audioPath);
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language flag emoji
        Text(
          LanguageEmoji.getEmoji(widget.languageCode),
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 8),
        // Second column: term, tags, description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Term and Play button
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: widget.isEditing && widget.translationController != null
                        ? TextField(
                            controller: widget.translationController,
                            onChanged: (_) => widget.onTranslationChanged?.call(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                          )
                        : Text(
                            HtmlEntityDecoder.decode(widget.card.translation),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                  ),
                  // Play audio button - always show
                  if (!widget.isEditing) ...[
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isPlayingAudio 
                            ? null 
                            : () {
                                if (widget.card.audioPath == null || 
                                    widget.card.audioPath!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('No audio available')),
                                  );
                                } else {
                                  _playAudio();
                                }
                              },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: _isPlayingAudio
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.volume_up,
                                  size: 16,
                                  color: (widget.card.audioPath == null || 
                                          widget.card.audioPath!.isEmpty)
                                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Row 2: IPA and Tags
              if (!widget.isEditing && widget.showExtraInfo) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (widget.card.ipa != null && widget.card.ipa!.isNotEmpty) ...[
                      Text(
                        '/${widget.card.ipa}/',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                    if (widget.partOfSpeech != null && widget.partOfSpeech!.isNotEmpty)
                      _buildDictionaryTag(
                        context,
                        widget.partOfSpeech!,
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                    if (widget.card.article != null && widget.card.article!.isNotEmpty)
                      _buildDictionaryTag(
                        context,
                        widget.card.article!,
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                    if (widget.card.pluralForm != null && widget.card.pluralForm!.isNotEmpty)
                      _buildDictionaryTag(
                        context,
                        'pl. ${widget.card.pluralForm}',
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                    if (widget.card.formalityRegister != null && 
                        widget.card.formalityRegister!.isNotEmpty && 
                        widget.card.formalityRegister!.toLowerCase() != 'neutral')
                      _buildDictionaryTag(
                        context,
                        widget.card.formalityRegister!,
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              // Row 3: Description
              if (widget.card.description != null && 
                  widget.card.description!.isNotEmpty && 
                  widget.showDescription && 
                  !widget.isEditing) ...[
                const SizedBox(height: 6),
                Text(
                  HtmlEntityDecoder.decode(widget.card.description!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDictionaryTag(
    BuildContext context,
    String text,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

