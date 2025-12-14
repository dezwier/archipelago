import 'package:flutter/material.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/common_widgets/language_selection_widget.dart';

/// Bottom drawer widget for exporting completed concepts as flashcards
class ExportFlashcardsDrawer extends StatefulWidget {
  final int completedConceptsCount;
  final List<Language> availableLanguages;
  final List<String> visibleLanguageCodes;

  const ExportFlashcardsDrawer({
    super.key,
    required this.completedConceptsCount,
    required this.availableLanguages,
    required this.visibleLanguageCodes,
  });

  @override
  State<ExportFlashcardsDrawer> createState() => _ExportFlashcardsDrawerState();
}

class _ExportFlashcardsDrawerState extends State<ExportFlashcardsDrawer> {
  List<String> _frontLanguageCodes = [];
  List<String> _backLanguageCodes = [];

  @override
  void initState() {
    super.initState();
    // Initialize with first two visible languages if available
    if (widget.visibleLanguageCodes.isNotEmpty) {
      _frontLanguageCodes = [widget.visibleLanguageCodes[0]];
      if (widget.visibleLanguageCodes.length > 1) {
        _backLanguageCodes = [widget.visibleLanguageCodes[1]];
      } else {
        _backLanguageCodes = [widget.visibleLanguageCodes[0]];
      }
    }
  }

  // Get languages that are visible in the dictionary
  List<Language> get _visibleLanguages {
    return widget.availableLanguages
        .where((lang) => widget.visibleLanguageCodes.contains(lang.code))
        .toList();
  }

  // Get languages available for front side (exclude back side selections)
  List<Language> get _frontAvailableLanguages {
    return _visibleLanguages
        .where((lang) => !_backLanguageCodes.contains(lang.code))
        .toList();
  }

  // Get languages available for back side (exclude front side selections)
  List<Language> get _backAvailableLanguages {
    return _visibleLanguages
        .where((lang) => !_frontLanguageCodes.contains(lang.code))
        .toList();
  }

  void _onFrontLanguageChanged(List<String> selectedLanguages) {
    setState(() {
      // Ensure at least one language is selected
      if (selectedLanguages.isEmpty) {
        return; // Prevent empty selection
      }
      
      // Remove any languages that are now selected on front from back side
      final newBackCodes = _backLanguageCodes
          .where((code) => !selectedLanguages.contains(code))
          .toList();
      
      // If removing languages from back would leave it empty, find a replacement
      if (newBackCodes.isEmpty) {
        // Find first available language for back that's not in front selection
        final availableForBack = _visibleLanguages
            .where((lang) => !selectedLanguages.contains(lang.code))
            .toList();
        if (availableForBack.isNotEmpty) {
          _backLanguageCodes = [availableForBack.first.code];
        } else {
          // If no replacement available, prevent the change
          return;
        }
      } else {
        _backLanguageCodes = newBackCodes;
      }
      
      _frontLanguageCodes = selectedLanguages;
    });
  }

  void _onBackLanguageChanged(List<String> selectedLanguages) {
    setState(() {
      // Ensure at least one language is selected
      if (selectedLanguages.isEmpty) {
        return; // Prevent empty selection
      }
      
      // Remove any languages that are now selected on back from front side
      final newFrontCodes = _frontLanguageCodes
          .where((code) => !selectedLanguages.contains(code))
          .toList();
      
      // If removing languages from front would leave it empty, find a replacement
      if (newFrontCodes.isEmpty) {
        // Find first available language for front that's not in back selection
        final availableForFront = _visibleLanguages
            .where((lang) => !selectedLanguages.contains(lang.code))
            .toList();
        if (availableForFront.isNotEmpty) {
          _frontLanguageCodes = [availableForFront.first.code];
        } else {
          // If no replacement available, prevent the change
          return;
        }
      } else {
        _frontLanguageCodes = newFrontCodes;
      }
      
      _backLanguageCodes = selectedLanguages;
    });
  }

  void _onExportPressed() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality coming soon'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 0.0),
            child: Row(
              children: [
                Text(
                  'Export Flashcards',
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
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Completed concepts count
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Text(
                      '${widget.completedConceptsCount} ${widget.completedConceptsCount == 1 ? 'concept' : 'concepts'} will be exported',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Front language selector
                  Text(
                    'Front Side Language',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LanguageSelectionWidget(
                    languages: _frontAvailableLanguages,
                    selectedLanguages: _frontLanguageCodes,
                    isLoading: false,
                    onSelectionChanged: _onFrontLanguageChanged,
                    itemsPerRow: 8,
                  ),
                  const SizedBox(height: 24),
                  // Back language selector
                  Text(
                    'Back Side Language',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LanguageSelectionWidget(
                    languages: _backAvailableLanguages,
                    selectedLanguages: _backLanguageCodes,
                    isLoading: false,
                    onSelectionChanged: _onBackLanguageChanged,
                    itemsPerRow: 8,
                  ),
                  const SizedBox(height: 32),
                  // Export button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_frontLanguageCodes.isNotEmpty && _backLanguageCodes.isNotEmpty)
                          ? _onExportPressed
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Export',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  // Bottom padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the export flashcards bottom drawer
void showExportFlashcardsDrawer({
  required BuildContext context,
  required int completedConceptsCount,
  required List<Language> availableLanguages,
  required List<String> visibleLanguageCodes,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => ExportFlashcardsDrawer(
      completedConceptsCount: completedConceptsCount,
      availableLanguages: availableLanguages,
      visibleLanguageCodes: visibleLanguageCodes,
    ),
  );
}
