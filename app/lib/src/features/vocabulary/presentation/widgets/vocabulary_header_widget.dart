import 'package:flutter/material.dart';

enum SortOption {
  alphabetical,
  timeCreatedRecentFirst,
  random,
}

class VocabularyHeaderWidget extends StatelessWidget {
  final int totalItems;
  final SortOption sortOption;
  final ValueChanged<SortOption?> onSortChanged;

  const VocabularyHeaderWidget({
    super.key,
    required this.totalItems,
    required this.sortOption,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$totalItems lemmas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          DropdownButton<SortOption>(
            value: sortOption,
            onChanged: onSortChanged,
            underline: Container(),
            icon: Icon(
              Icons.sort,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            items: [
              DropdownMenuItem(
                value: SortOption.alphabetical,
                child: Text(
                  'Alphabetically',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              DropdownMenuItem(
                value: SortOption.timeCreatedRecentFirst,
                child: Text(
                  'Recent First',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

