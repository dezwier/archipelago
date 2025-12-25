import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

/// A reusable widget that displays language selection buttons in a grid layout.
/// Shows language flags as emoji buttons that can be toggled on/off.
class LanguageSelectionWidget extends StatelessWidget {
  final List<Language> languages;
  final List<String> selectedLanguages;
  final bool isLoading;
  final ValueChanged<List<String>> onSelectionChanged;
  final int itemsPerRow;

  const LanguageSelectionWidget({
    super.key,
    required this.languages,
    required this.selectedLanguages,
    required this.isLoading,
    required this.onSelectionChanged,
    this.itemsPerRow = 4,
  });

  void _toggleLanguage(String languageCode) {
    final newSelection = List<String>.from(selectedLanguages);
    if (newSelection.contains(languageCode)) {
      newSelection.remove(languageCode);
    } else {
      newSelection.add(languageCode);
    }
    onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
            ),
          ),
        ),
      );
    }

    // Calculate number of rows needed
    final int rowCount = (languages.length / itemsPerRow).ceil();

    return Column(
      children: [
        // "Select All" button
        const SizedBox(height: 6),
        // Language buttons in grid
        for (int row = 0; row < rowCount; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row < rowCount - 1 ? 8 : 0),
            child: Row(
              children: [
                for (int col = 0; col < itemsPerRow; col++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: col < itemsPerRow - 1 ? 8 : 8,
                      ),
                      child: _buildFlagButton(
                        context,
                        row * itemsPerRow + col < languages.length
                            ? languages[row * itemsPerRow + col]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFlagButton(BuildContext context, Language? language) {
    if (language == null) {
      return const SizedBox.shrink();
    }

    final isSelected = selectedLanguages.contains(language.code);

    return SizedBox(
      height: 35,
      child: OutlinedButton(
        onPressed: () => _toggleLanguage(language.code),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1 : 1,
          ),
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Center(
          child: Text(
            LanguageEmoji.getEmoji(language.code),
            style: const TextStyle(fontSize: 24, height: 1.0),
          ),
        ),
      ),
    );
  }
}

