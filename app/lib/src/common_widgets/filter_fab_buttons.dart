import 'package:flutter/material.dart';

/// Generic FAB buttons for filter actions
class FilterFabButtons extends StatelessWidget {
  final VoidCallback onFilterPressed;
  final Key? filterButtonKey;

  const FilterFabButtons({
    super.key,
    required this.onFilterPressed,
    this.filterButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      key: filterButtonKey,
      heroTag: 'filter_fab',
      onPressed: onFilterPressed,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      child: const Icon(Icons.filter_list),
      tooltip: 'Filter',
    );
  }
}


