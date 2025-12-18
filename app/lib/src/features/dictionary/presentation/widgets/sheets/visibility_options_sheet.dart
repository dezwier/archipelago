import 'package:flutter/material.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';

/// Bottom drawer that exposes visibility-related options (language toggles and
/// card detail switches). Mirrors the look/feel of the filter drawer.
class VisibilityOptionsSheet extends StatefulWidget {
  final List<Language> allLanguages;
  final Map<String, bool> languageVisibility;
  final bool showDescription;
  final bool showExtraInfo;
  final DictionaryController? controller;
  final String? firstVisibleLanguage;
  final ValueChanged<String> onLanguageVisibilityToggled;
  final ValueChanged<bool> onShowDescriptionChanged;
  final ValueChanged<bool> onShowExtraInfoChanged;

  const VisibilityOptionsSheet({
    super.key,
    required this.allLanguages,
    required this.languageVisibility,
    required this.showDescription,
    required this.showExtraInfo,
    required this.controller,
    this.firstVisibleLanguage,
    required this.onLanguageVisibilityToggled,
    required this.onShowDescriptionChanged,
    required this.onShowExtraInfoChanged,
  });

  @override
  State<VisibilityOptionsSheet> createState() => _VisibilityOptionsSheetState();
}

class _VisibilityOptionsSheetState extends State<VisibilityOptionsSheet> {
  late Map<String, bool> _localVisibility;
  late bool _localShowDescription;
  late bool _localShowExtraInfo;
  SortOption? _pendingSortOption;

  @override
  void initState() {
    super.initState();
    _localVisibility = Map<String, bool>.from(widget.languageVisibility);
    _localShowDescription = widget.showDescription;
    _localShowExtraInfo = widget.showExtraInfo;
    _pendingSortOption = widget.controller?.sortOption;
  }

  void _applyPendingChanges() {
    // Apply pending sort changes to the controller
    if (widget.controller != null && 
        _pendingSortOption != null && 
        _pendingSortOption != widget.controller!.sortOption) {
      widget.controller!.setSortOption(
        _pendingSortOption!,
        firstVisibleLanguage: widget.firstVisibleLanguage,
      );
    }
  }

  void _toggleLanguage(String languageCode) {
    final current = _localVisibility[languageCode] ?? true;
    final next = !current;

    // Prevent disabling the last visible language
    if (current && !next) {
      final visibleCount =
          _localVisibility.values.where((isVisible) => isVisible).length;
      if (visibleCount <= 1) {
        return;
      }
    }

    setState(() {
      _localVisibility[languageCode] = next;
    });
    widget.onLanguageVisibilityToggled(languageCode);
  }

  void _toggleDescription(bool value) {
    setState(() {
      _localShowDescription = value;
    });
    widget.onShowDescriptionChanged(value);
  }

  void _toggleExtraInfo(bool value) {
    setState(() {
      _localShowExtraInfo = value;
    });
    widget.onShowExtraInfoChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Apply pending changes when the sheet is dismissed
          _applyPendingChanges();
        }
      },
      child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 0.0),
            child: Row(
              children: [
                Text(
                  'Visibility',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _applyPendingChanges();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort options (only show if controller is provided)
                  if (widget.controller != null)
                    StatefulBuilder(
                      builder: (context, setMenuState) {
                        final currentSortOption = _pendingSortOption ?? widget.controller!.sortOption;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                            child: Text(
                              'Sort',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              children: [
                                // Alphabetical button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setMenuState(() {
                                        _pendingSortOption = SortOption.alphabetical;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: currentSortOption == SortOption.alphabetical
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: currentSortOption == SortOption.alphabetical
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                          width: currentSortOption == SortOption.alphabetical ? 1 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.sort_by_alpha,
                                            size: 18,
                                            color: currentSortOption == SortOption.alphabetical
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Alphabetical',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: currentSortOption == SortOption.alphabetical
                                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Recent button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setMenuState(() {
                                        _pendingSortOption = SortOption.timeCreatedRecentFirst;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: currentSortOption == SortOption.timeCreatedRecentFirst
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: currentSortOption == SortOption.timeCreatedRecentFirst
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                          width: currentSortOption == SortOption.timeCreatedRecentFirst ? 1 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 18,
                                            color: currentSortOption == SortOption.timeCreatedRecentFirst
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Recent',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: currentSortOption == SortOption.timeCreatedRecentFirst
                                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Random button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setMenuState(() {
                                        _pendingSortOption = SortOption.random;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: currentSortOption == SortOption.random
                                            ? Theme.of(context).colorScheme.primaryContainer
                                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: currentSortOption == SortOption.random
                                              ? Theme.of(context).colorScheme.primary
                                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                          width: currentSortOption == SortOption.random ? 1 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.shuffle,
                                            size: 18,
                                            color: currentSortOption == SortOption.random
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Random',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: currentSortOption == SortOption.random
                                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                                    : Theme.of(context).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    ),
                  const SizedBox(height: 4),
                  if (widget.controller != null) const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'Languages',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.allLanguages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No languages available',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.allLanguages
                          .map((language) => _LanguageChip(
                                language: language,
                                isVisible:
                                    _localVisibility[language.code] ?? true,
                                onTap: () => _toggleLanguage(language.code),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Extra info'),
                    value: _localShowExtraInfo,
                    onChanged: _toggleExtraInfo,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Description'),
                    value: _localShowDescription,
                    onChanged: _toggleDescription,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final Language language;
  final bool isVisible;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.language,
    required this.isVisible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isVisible
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isVisible
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LanguageEmoji.getEmoji(language.code),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 6),
            Text(
              language.code.toUpperCase(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to open the visibility options drawer.
void showVisibilityOptionsSheet({
  required BuildContext context,
  required List<Language> allLanguages,
  required Map<String, bool> languageVisibility,
  required bool showDescription,
  required bool showExtraInfo,
  DictionaryController? controller,
  String? firstVisibleLanguage,
  required ValueChanged<String> onLanguageVisibilityToggled,
  required ValueChanged<bool> onShowDescriptionChanged,
  required ValueChanged<bool> onShowExtraInfoChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => VisibilityOptionsSheet(
      allLanguages: allLanguages,
      languageVisibility: languageVisibility,
      showDescription: showDescription,
      showExtraInfo: showExtraInfo,
      controller: controller,
      firstVisibleLanguage: firstVisibleLanguage,
      onLanguageVisibilityToggled: onLanguageVisibilityToggled,
      onShowDescriptionChanged: onShowDescriptionChanged,
      onShowExtraInfoChanged: onShowExtraInfoChanged,
    ),
  );
}

