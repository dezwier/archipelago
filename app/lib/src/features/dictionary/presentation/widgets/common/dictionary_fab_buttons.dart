import 'package:flutter/material.dart';

class DictionaryFabButtons extends StatelessWidget {
  final VoidCallback onFilterPressed;
  final VoidCallback onFilteringPressed;
  final VoidCallback? onGenerateLemmasPressed;
  final VoidCallback? onExportPressed;
  final bool isLoadingConcepts;
  final bool isLoadingExport;
  final Key? filterButtonKey;

  const DictionaryFabButtons({
    super.key,
    required this.onFilterPressed,
    required this.onFilteringPressed,
    this.onGenerateLemmasPressed,
    this.onExportPressed,
    this.isLoadingConcepts = false,
    this.isLoadingExport = false,
    this.filterButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Generate lemmas button (always enabled to allow viewing progress)
        FloatingActionButton.small(
          heroTag: 'generate_lemmas_fab',
          onPressed: onGenerateLemmasPressed,
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
        // Export button
        FloatingActionButton.small(
          heroTag: 'export_fab',
          onPressed: (isLoadingConcepts || isLoadingExport) ? null : onExportPressed,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: isLoadingExport
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.file_download),
          tooltip: 'Export Flashcards',
        ),
        const SizedBox(height: 8),
        // Visibility button
        FloatingActionButton.small(
          key: filterButtonKey,
          heroTag: 'filter_fab',
          onPressed: onFilterPressed,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          child: const Icon(Icons.visibility),
          tooltip: 'Show/Hide',
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
      ],
    );
  }
}

