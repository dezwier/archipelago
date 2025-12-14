import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';

class ConceptInfoWidget extends StatelessWidget {
  final PairedDictionaryItem item;

  const ConceptInfoWidget({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.conceptTerm != null) ...[
            Builder(
              builder: (context) {
                final parts = <String>[item.conceptTerm!];
                if (item.partOfSpeech != null) {
                  parts.add(item.partOfSpeech!);
                }
                if (item.conceptLevel != null) {
                  parts.add(item.conceptLevel!.toUpperCase());
                }
                final conceptText = parts.join(', ');
                
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    Text(
                      'Concept: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      conceptText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      softWrap: true,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
          ],
          if (item.conceptDescription != null) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: item.conceptDescription!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              softWrap: true,
            ),
            const SizedBox(height: 6),
          ],
          if (item.topicName != null) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Topic: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  item.topicName!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  softWrap: true,
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (item.topicDescription != null) ...[
            Text(
              item.topicDescription!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              Text(
                '#',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                item.conceptId.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
                softWrap: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

