import 'package:flutter/material.dart';
import '../../../../utils/language_emoji.dart';
import '../../../profile/domain/language.dart';

class DictionaryFilterMenu {
  static List<PopupMenuEntry<void>> buildMenuItems({
    required BuildContext context,
    required List<Language> allLanguages,
    required Map<String, bool> languageVisibility,
    required List<String> languagesToShow,
    required bool showDescription,
    required bool showExtraInfo,
    required ValueChanged<String> onLanguageVisibilityToggled,
    required ValueChanged<bool> onShowDescriptionChanged,
    required ValueChanged<bool> onShowExtraInfoChanged,
  }) {
    return [
      // Language visibility buttons
      PopupMenuItem<void>(
        child: StatefulBuilder(
          builder: (context, setMenuState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Languages',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allLanguages.map((language) {
                    final isVisible = languageVisibility[language.code] ?? true;
                    return GestureDetector(
                      onTap: () {
                        setMenuState(() {
                          final wasVisible = languageVisibility[language.code] ?? true;
                          final willBeVisible = !isVisible;
                          
                          // Prevent disabling if this is the last visible language
                          if (wasVisible && !willBeVisible) {
                            final visibleCount = languageVisibility.values.where((v) => v == true).length;
                            if (visibleCount <= 1) {
                              return; // Don't proceed with the change
                            }
                          }
                          
                          onLanguageVisibilityToggled(language.code);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isVisible
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isVisible
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          LanguageEmoji.getEmoji(language.code),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<void>(
        child: StatefulBuilder(
          builder: (context, setMenuState) {
            return Row(
              children: [
                Checkbox(
                  value: showExtraInfo,
                  onChanged: (value) {
                    setMenuState(() {
                      onShowExtraInfoChanged(value ?? true);
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text('Extra Info'),
              ],
            );
          },
        ),
      ),
      PopupMenuItem<void>(
        child: StatefulBuilder(
          builder: (context, setMenuState) {
            return Row(
              children: [
                Checkbox(
                  value: showDescription,
                  onChanged: (value) {
                    setMenuState(() {
                      onShowDescriptionChanged(value ?? true);
                    });
                  },
                ),
                const SizedBox(width: 8),
                const Text('Description'),
              ],
            );
          },
        ),
      ),
    ];
  }
}

