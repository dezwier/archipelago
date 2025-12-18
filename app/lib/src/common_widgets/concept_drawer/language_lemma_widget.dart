import 'package:flutter/material.dart';
import 'package:archipelago/src/utils/html_entity_decoder.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/dictionary/domain/dictionary_card.dart';
import 'package:archipelago/src/common_widgets/lemma_audio_player.dart';

class LanguageLemmaWidget extends StatefulWidget {
  final DictionaryCard card;
  final String languageCode;
  final bool showDescription;
  final bool showExtraInfo;
  final TextEditingController? translationController;
  final bool isEditing;
  final VoidCallback? onTranslationChanged;
  final String? partOfSpeech;
  final String? topicName;

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
    this.topicName,
  });

  @override
  State<LanguageLemmaWidget> createState() => _LanguageLemmaWidgetState();
}

class _LanguageLemmaWidgetState extends State<LanguageLemmaWidget> {

  TextStyle _getTitleTextStyle(BuildContext context) {
    // Count how many sections are hidden
    int hiddenCount = 0;
    if (!widget.showExtraInfo) hiddenCount++;
    if (!widget.showDescription) hiddenCount++;

    // Determine text style based on hidden count
    TextStyle? baseStyle;
    if (hiddenCount == 0) {
      // Both visible - use titleLarge but make it a tiny bit smaller
      final titleLarge = Theme.of(context).textTheme.titleLarge;
      baseStyle = titleLarge?.copyWith(
        fontSize: (titleLarge.fontSize ?? 22) * 0.85, // Make it ~8% smaller
      );
    } else if (hiddenCount == 1) {
      // One hidden - use titleMedium (bit smaller)
      baseStyle = Theme.of(context).textTheme.titleMedium;
    } else {
      // Both hidden - use titleSmall (more smaller)
      baseStyle = Theme.of(context).textTheme.titleSmall;
    }

    return baseStyle?.copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    ) ?? TextStyle(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = HtmlEntityDecoder.decode(widget.card.translation);
    final titleLength = titleText.length;
    final shouldShowInline = titleLength < 12 && !widget.isEditing && widget.showExtraInfo;

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
              // Row 1: Term with inline topic tag, audio symbol, and optionally IPA/tags
              widget.isEditing && widget.translationController != null
                  ? TextField(
                      controller: widget.translationController,
                      onChanged: (_) => widget.onTranslationChanged?.call(),
                      style: _getTitleTextStyle(context),
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
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: titleText,
                            style: _getTitleTextStyle(context),
                          ),
                          // Add space before tag/audio
                          const TextSpan(text: ' '),
                          // Topic tag - inline after text
                          if (widget.topicName != null && widget.topicName!.isNotEmpty)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: _buildTopicTag(context),
                              ),
                            ),
                          // Add space before audio
                          const TextSpan(text: ' '),
                          // Play audio button - inline after text/tag
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 0),
                              child: LemmaAudioPlayer(
                                lemmaId: widget.card.id,
                                audioPath: widget.card.audioPath,
                                term: widget.card.translation,
                                description: widget.card.description,
                                languageCode: widget.languageCode,
                                iconSize: 16.0,
                                showLoadingIndicator: true,
                              ),
                            ),
                          ),
                          // If title is short, add IPA and tags inline
                          if (shouldShowInline) ...[
                            const TextSpan(text: ' '),
                            if (widget.card.ipa != null && widget.card.ipa!.isNotEmpty)
                              TextSpan(
                                text: '/${widget.card.ipa}/',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            if (widget.partOfSpeech != null && widget.partOfSpeech!.isNotEmpty) ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: _buildDictionaryTag(
                                  context,
                                  widget.partOfSpeech!,
                                  const Color(0xFFE0E0E0),
                                  const Color(0xFF424242),
                                ),
                              ),
                            ],
                            if (widget.card.article != null && widget.card.article!.isNotEmpty) ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: _buildDictionaryTag(
                                  context,
                                  widget.card.article!,
                                  const Color(0xFFE0E0E0),
                                  const Color(0xFF424242),
                                ),
                              ),
                            ],
                            if (widget.card.pluralForm != null && widget.card.pluralForm!.isNotEmpty) ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: _buildDictionaryTag(
                                  context,
                                  'pl. ${widget.card.pluralForm}',
                                  const Color(0xFFE0E0E0),
                                  const Color(0xFF424242),
                                ),
                              ),
                            ],
                            if (widget.card.formalityRegister != null && 
                                widget.card.formalityRegister!.isNotEmpty && 
                                widget.card.formalityRegister!.toLowerCase() != 'neutral') ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: _buildDictionaryTag(
                                  context,
                                  widget.card.formalityRegister!,
                                  const Color(0xFFE0E0E0),
                                  const Color(0xFF424242),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
              // Row 2: IPA and Tags (only if title is 12+ characters)
              if (!widget.isEditing && widget.showExtraInfo && !shouldShowInline) ...[
                const SizedBox(height: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.card.ipa != null && widget.card.ipa!.isNotEmpty)
                      Text(
                        '/${widget.card.ipa}/',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                    if (widget.card.ipa != null && widget.card.ipa!.isNotEmpty) const SizedBox(height: 4),
                    Wrap(
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

  Widget _buildTopicTag(BuildContext context) {
    final topicName = widget.topicName!;
    final capitalizedName = topicName.isNotEmpty
        ? topicName[0].toUpperCase() + topicName.substring(1)
        : topicName;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        capitalizedName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
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

