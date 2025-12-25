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
          // Topic tags
          if (item.topics.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                Text(
                  'Topics: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...item.topics.map((topic) {
                  return Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        topic['icon'] != null && (topic['icon'] as String).isNotEmpty
                            ? topic['icon'] as String
                            : '📁',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                }).toList(),
              ],
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

