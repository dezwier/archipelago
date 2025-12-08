import 'package:flutter/material.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../../../utils/language_emoji.dart';
import '../../domain/vocabulary_card.dart';

class LanguageLemmaWidget extends StatelessWidget {
  final VocabularyCard card;
  final String languageCode;
  final bool showDescription;
  final TextEditingController? translationController;
  final bool isEditing;
  final VoidCallback? onTranslationChanged;
  final String? partOfSpeech;

  const LanguageLemmaWidget({
    super.key,
    required this.card,
    required this.languageCode,
    this.showDescription = true,
    this.translationController,
    this.isEditing = false,
    this.onTranslationChanged,
    this.partOfSpeech,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language flag emoji
        Text(
          LanguageEmoji.getEmoji(languageCode),
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 8),
        // Second column: term, tags, description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Term and IPA
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: isEditing && translationController != null
                        ? TextField(
                            controller: translationController,
                            onChanged: (_) => onTranslationChanged?.call(),
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
                            HtmlEntityDecoder.decode(card.translation),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                  ),
                  if (card.ipa != null && card.ipa!.isNotEmpty && !isEditing) ...[
                    const SizedBox(width: 8),
                    Text(
                      '/${card.ipa}/',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
              // Row 2: Part of speech and Tags (article, plural, formality)
              if (!isEditing) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (partOfSpeech != null && partOfSpeech!.isNotEmpty)
                      _buildDictionaryTag(
                        context,
                        partOfSpeech!,
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                    if (card.article != null && card.article!.isNotEmpty)
                      _buildDictionaryTag(
                        context,
                        card.article!,
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                    if (card.pluralForm != null && card.pluralForm!.isNotEmpty)
                      _buildDictionaryTag(
                        context,
                        'pl. ${card.pluralForm}',
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                    if (card.formalityRegister != null && 
                        card.formalityRegister!.isNotEmpty && 
                        card.formalityRegister!.toLowerCase() != 'neutral')
                      _buildDictionaryTag(
                        context,
                        card.formalityRegister!,
                        const Color(0xFFE0E0E0), // Neutral grey
                        const Color(0xFF424242),
                      ),
                  ],
                ),
              ],
              // Row 3: Description
              if (card.description != null && card.description!.isNotEmpty && showDescription && !isEditing) ...[
                const SizedBox(height: 6),
                Text(
                  HtmlEntityDecoder.decode(card.description!),
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

