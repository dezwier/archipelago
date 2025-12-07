import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../../../utils/language_emoji.dart';
import '../../domain/paired_vocabulary_item.dart';
import '../../domain/vocabulary_card.dart';
import '../../../../constants/api_config.dart';

class VocabularyDetailDrawer extends StatefulWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;
  final VoidCallback? onEdit;
  final VoidCallback? onRandomCard;
  final VoidCallback? onRefreshImages;

  const VocabularyDetailDrawer({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
    this.onEdit,
    this.onRandomCard,
    this.onRefreshImages,
  });

  @override
  State<VocabularyDetailDrawer> createState() => _VocabularyDetailDrawerState();
}

class _VocabularyDetailDrawerState extends State<VocabularyDetailDrawer> {
  bool _isPlayingAudio = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<String> get _imageUrls {
    return [
      widget.item.imagePath1,
      widget.item.imagePath2,
      widget.item.imagePath3,
      widget.item.imagePath4,
    ].where((url) => url != null && url.isNotEmpty).cast<String>().toList();
  }

  String? _getFullAudioUrl(String? audioPath) {
    if (audioPath == null || audioPath.isEmpty) return null;
    if (audioPath.startsWith('http://') || audioPath.startsWith('https://')) {
      return audioPath;
    }
    return '${ApiConfig.baseUrl}$audioPath';
  }

  Future<void> _playAudio(VocabularyCard? card) async {
    if (card == null || card.audioPath == null || card.audioPath!.isEmpty) {
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
      final audioUrl = _getFullAudioUrl(card.audioPath);
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
        // Listen for completion
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
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            // Images at top - 4 rectangles, all fully visible
            if (_imageUrls.isNotEmpty) ...[
              _buildImageGrid(context),
              const SizedBox(height: 12),
            ],
            // Action buttons
            _buildActionButtons(context),
            const SizedBox(height: 12),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Source language phrase and description
                  if (widget.item.sourceCard != null && widget.sourceLanguageCode != null)
                    _buildLanguageSection(
                      context,
                      card: widget.item.sourceCard!,
                      languageCode: widget.sourceLanguageCode!,
                      isSource: true,
                    ),
                  // Target language phrase and description
                  if (widget.item.targetCard != null && widget.targetLanguageCode != null) ...[
                    if (widget.item.sourceCard != null) const SizedBox(height: 12),
                    _buildLanguageSection(
                      context,
                      card: widget.item.targetCard!,
                      languageCode: widget.targetLanguageCode!,
                      isSource: false,
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Edit button
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onEdit?.call();
            },
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
          // Play button
          IconButton(
            onPressed: _isPlayingAudio
                ? null
                : () {
                    // Play audio for target card if available, otherwise source
                    final cardToPlay = widget.item.targetCard ?? widget.item.sourceCard;
                    _playAudio(cardToPlay);
                  },
            icon: _isPlayingAudio
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.volume_up),
            tooltip: 'Play',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
          // Refresh images button
          IconButton(
            onPressed: widget.onRefreshImages,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Images',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
          // Random card button
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRandomCard?.call();
            },
            icon: const Icon(Icons.shuffle),
            tooltip: 'Random Card',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context) {
    final images = _imageUrls.take(4).toList();
    if (images.isEmpty) return const SizedBox.shrink();

    // Always show 2x2 grid for up to 4 images
    final crossAxisCount = 2;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogMargin = 32.0; // 16 on each side
    final padding = 32.0; // 16 on each side inside dialog
    final spacing = 8.0;
    final itemSize = (screenWidth - dialogMargin - padding - spacing) / 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        height: itemSize * 2 + spacing, // 2 rows with spacing
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: images.length > 4 ? 4 : images.length,
          itemBuilder: (context, index) => _buildImage(context, images[index]),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String url) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.broken_image,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              size: 24,
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageSection(
    BuildContext context, {
    required VocabularyCard card,
    required String languageCode,
    required bool isSource,
  }) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: isSource
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
            : Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phrase
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LanguageEmoji.getEmoji(languageCode),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  HtmlEntityDecoder.decode(card.translation),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: isSource ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              if (card.gender != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSource
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    card.gender!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSource
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          // Description
          if (card.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              HtmlEntityDecoder.decode(card.description),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],
          // IPA if available
          if (card.ipa != null && card.ipa!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '/${card.ipa}/',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          // Notes if available
          if (card.notes != null && card.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              HtmlEntityDecoder.decode(card.notes!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
