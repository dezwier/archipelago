import 'package:flutter/material.dart';
import '../../../../utils/html_entity_decoder.dart';
import '../../../../utils/language_emoji.dart';
import '../../domain/vocabulary_card.dart';

class VocabularyCardWidget extends StatelessWidget {
  final VocabularyCard card;
  final String languageCode;
  final bool isSource;
  final bool showDescription;
  final bool isFirst;
  final bool isLast;

  const VocabularyCardWidget({
    super.key,
    required this.card,
    required this.languageCode,
    required this.isSource,
    this.showDescription = true,
    this.isFirst = true,
    this.isLast = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        top: isFirst ? 12.0 : 0.0,
        bottom: isLast ? 12.0 : 0.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    fontWeight: isSource ? FontWeight.w400 : FontWeight.w600,
                    fontStyle: isSource ? FontStyle.italic : FontStyle.normal,
                    color: isSource 
                        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                        : null,
                  ),
                ),
              ),
              if (card.gender != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSource
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    card.gender!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSource
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          if (card.description.isNotEmpty && showDescription) ...[
            const SizedBox(height: 2),
            Text(
              HtmlEntityDecoder.decode(card.description),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: isSource ? 0.5 : 0.7,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (card.ipa != null && card.ipa!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '/${card.ipa}/',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: isSource ? 0.4 : 0.6,
                ),
              ),
            ),
          ],
          if (card.notes != null && card.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              HtmlEntityDecoder.decode(card.notes!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: isSource ? 0.4 : 0.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

