import 'package:flutter/material.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/card_generation_state.dart';

class CardGenerationProgressWidget extends StatelessWidget {
  final int? totalConcepts;
  final int currentConceptIndex;
  final String? currentConceptTerm;
  final List<String> currentConceptMissingLanguages;
  final int conceptsProcessed;
  final int cardsCreated;
  final int imagesCreated;
  final List<String> errors;
  final double sessionCostUsd;
  final bool isGenerating;
  final bool isCancelled;
  final GenerationType generationType;
  final VoidCallback? onCancel;
  final VoidCallback? onDismiss;

  const CardGenerationProgressWidget({
    super.key,
    required this.totalConcepts,
    required this.currentConceptIndex,
    required this.currentConceptTerm,
    required this.currentConceptMissingLanguages,
    required this.conceptsProcessed,
    required this.cardsCreated,
    required this.imagesCreated,
    required this.errors,
    required this.sessionCostUsd,
    required this.isGenerating,
    required this.generationType,
    this.isCancelled = false,
    this.onCancel,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Show widget if we have data to display (even after generation completes)
    if (totalConcepts == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGenerating ? Icons.auto_awesome : Icons.check_circle,
                color: isGenerating 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isGenerating 
                      ? (generationType == GenerationType.images 
                          ? 'Generating Images' 
                          : 'Generating Lemmas')
                      : (isCancelled ? 'Generation Cancelled' : 'Generation Complete'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isGenerating && onCancel != null)
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              if (!isGenerating && onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Total concepts info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  generationType == GenerationType.images
                      ? 'Found $totalConcepts concept(s) without images'
                      : 'Found $totalConcepts concept(s) without missing languages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Current concept being processed
          if (currentConceptTerm != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Processing: $currentConceptTerm',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentConceptMissingLanguages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Languages:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        ...currentConceptMissingLanguages.map((lang) {
                          final langCode = lang.toLowerCase();
                          final flagEmoji = LanguageEmoji.getEmoji(langCode);
                          return Text(
                            flagEmoji,
                            style: const TextStyle(fontSize: 20),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Progress bar
          if (totalConcepts != null && totalConcepts! > 0) ...[
            Text(
              isGenerating 
                  ? 'Concept ${currentConceptIndex + 1} of $totalConcepts'
                  : (isCancelled 
                      ? 'Processed $conceptsProcessed of $totalConcepts concepts'
                      : 'Completed $totalConcepts of $totalConcepts concepts'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: totalConcepts! > 0 
                  ? (isGenerating 
                      ? (currentConceptIndex + 1) / totalConcepts!
                      : (isCancelled 
                          ? conceptsProcessed / totalConcepts!
                          : 1.0))
                  : 0,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                isGenerating 
                    ? Theme.of(context).colorScheme.primary
                    : (isCancelled
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$conceptsProcessed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Processed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    generationType == GenerationType.images 
                        ? '$imagesCreated' 
                        : '$cardsCreated',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  Text(
                    generationType == GenerationType.images 
                        ? 'Images Created' 
                        : 'Lemmas Created',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    sessionCostUsd < 0.01
                        ? '\$${sessionCostUsd.toStringAsFixed(6)}'
                        : '\$${sessionCostUsd.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: sessionCostUsd > 0.1
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  Text(
                    'Session Cost',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (errors.isNotEmpty)
                Column(
                  children: [
                    Text(
                      '${errors.length}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Text(
                      'Errors',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

