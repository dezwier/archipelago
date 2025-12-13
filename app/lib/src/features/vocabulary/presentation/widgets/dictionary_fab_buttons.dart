import 'package:flutter/material.dart';

class DictionaryFabButtons extends StatelessWidget {
  final VoidCallback onFilterPressed;
  final VoidCallback onFilteringPressed;
  final VoidCallback? onGenerateLemmasPressed;
  final bool isLoadingConcepts;

  const DictionaryFabButtons({
    super.key,
    required this.onFilterPressed,
    required this.onFilteringPressed,
    this.onGenerateLemmasPressed,
    this.isLoadingConcepts = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Generate lemmas button
        FloatingActionButton.small(
          heroTag: 'generate_lemmas_fab',
          onPressed: isLoadingConcepts ? null : onGenerateLemmasPressed,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: isLoadingConcepts
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.auto_awesome),
          tooltip: 'Generate Lemmas',
        ),
        const SizedBox(height: 8),
        // Filtering button
        FloatingActionButton.small(
          heroTag: 'filtering_fab',
          onPressed: onFilteringPressed,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: const Icon(Icons.filter_list),
          tooltip: 'Filter',
        ),
        const SizedBox(height: 8),
        // Filter button
        FloatingActionButton.small(
          heroTag: 'filter_fab',
          onPressed: onFilterPressed,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: const Icon(Icons.visibility),
          tooltip: 'Show/Hide',
        ),
      ],
    );
  }
}

