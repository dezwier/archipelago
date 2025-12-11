import 'package:flutter/material.dart';
import '../../../../features/profile/domain/language.dart';
import '../../../../utils/language_emoji.dart';

class RegenerateLanguageDialog extends StatefulWidget {
  final List<Language> languages;

  const RegenerateLanguageDialog({
    super.key,
    required this.languages,
  });

  static Future<List<String>?> show(
    BuildContext context,
    List<Language> languages,
  ) async {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => RegenerateLanguageDialog(languages: languages),
    );
  }

  @override
  State<RegenerateLanguageDialog> createState() => _RegenerateLanguageDialogState();
}

class _RegenerateLanguageDialogState extends State<RegenerateLanguageDialog> {
  List<String> _selectedLanguages = [];

  void _toggleLanguage(String languageCode) {
    setState(() {
      if (_selectedLanguages.contains(languageCode)) {
        _selectedLanguages.remove(languageCode);
      } else {
        _selectedLanguages.add(languageCode);
      }
    });
  }

  void _toggleAllLanguages() {
    setState(() {
      if (_selectedLanguages.length == widget.languages.length) {
        _selectedLanguages = [];
      } else {
        _selectedLanguages = widget.languages.map((lang) => lang.code).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const int itemsPerRow = 6;
    final int rowCount = (widget.languages.length / itemsPerRow).ceil();

    return AlertDialog(
      title: const Text('Regenerate Lemmas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _toggleAllLanguages,
                icon: Icon(
                  _selectedLanguages.length == widget.languages.length
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                ),
                label: Text(
                  _selectedLanguages.length == widget.languages.length
                      ? 'All Languages Selected'
                      : 'Select All Languages',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                            row * itemsPerRow + col < widget.languages.length
                                ? widget.languages[row * itemsPerRow + col]
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedLanguages.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedLanguages),
          child: const Text('Regenerate'),
        ),
      ],
    );
  }

  Widget _buildFlagButton(Language? language) {
    if (language == null) {
      return const SizedBox.shrink();
    }

    final isSelected = _selectedLanguages.contains(language.code);

    return AspectRatio(
      aspectRatio: 1.0,
      child: OutlinedButton(
        onPressed: () => _toggleLanguage(language.code),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(4),
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
            style: const TextStyle(fontSize: 28, height: 1.0),
          ),
        ),
      ),
    );
  }
}

