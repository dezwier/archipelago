import 'package:flutter/material.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/common_widgets/language_selection_widget.dart';
import 'package:archipelago/src/features/dictionary/data/flashcard_export_service.dart';

/// Bottom drawer widget for exporting completed concepts as flashcards
class ExportFlashcardsDrawer extends StatefulWidget {
  final List<int> conceptIds;
  final int completedConceptsCount;
  final List<Language> availableLanguages;
  final List<String> visibleLanguageCodes;

  const ExportFlashcardsDrawer({
    super.key,
    required this.conceptIds,
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
  bool _isExporting = false;
  
  // Layout selection: 'a4' or 'a6'
  String _layout = 'a4';
  
  // Front side options
  bool _includeImageFront = true;
  bool _includePhraseFront = true;
  bool _includeIpaFront = true;
  bool _includeDescriptionFront = true;
  
  // Back side options
  bool _includeImageBack = true;
  bool _includePhraseBack = true;
  bool _includeIpaBack = true;
  bool _includeDescriptionBack = true;

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

  // Get languages available for front side (all visible languages)
  List<Language> get _frontAvailableLanguages {
    return _visibleLanguages;
  }

  // Get languages available for back side (all visible languages)
  List<Language> get _backAvailableLanguages {
    return _visibleLanguages;
  }

  void _onFrontLanguageChanged(List<String> selectedLanguages) {
    setState(() {
      // Ensure at least one language is selected
      if (selectedLanguages.isEmpty) {
        return; // Prevent empty selection
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
      _backLanguageCodes = selectedLanguages;
    });
  }

  Future<void> _onExportPressed() async {
    if (widget.conceptIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No concepts to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isExporting) return; // Prevent multiple simultaneous exports

    setState(() {
      _isExporting = true;
    });

    try {
      final result = await FlashcardExportService.exportFlashcardsPdf(
        conceptIds: widget.conceptIds,
        languagesFront: _frontLanguageCodes,
        languagesBack: _backLanguageCodes,
        layout: _layout,
        includeImageFront: _includeImageFront,
        includePhraseFront: _includePhraseFront,
        includeIpaFront: _includeIpaFront,
        includeDescriptionFront: _includeDescriptionFront,
        includeImageBack: _includeImageBack,
        includePhraseBack: _includePhraseBack,
        includeIpaBack: _includeIpaBack,
        includeDescriptionBack: _includeDescriptionBack,
      );

      if (!mounted) return;

      // Always reset the exporting state before closing drawer or showing messages
      setState(() {
        _isExporting = false;
      });

      if (result['success'] == true) {
        // Show success message first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flashcards exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Close the drawer after a brief delay to ensure state is updated
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Failed to export flashcards'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isExporting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                  // Layout selection buttons
                  Text(
                    'Layout',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // A4 button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _layout = 'a4';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _layout == 'a4'
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _layout == 'a4'
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'A4',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _layout == 'a4'
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // A6 button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _layout = 'a6';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _layout == 'a6'
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _layout == 'a6'
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'A6',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _layout == 'a6'
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // A8 button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _layout = 'a8';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _layout == 'a8'
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _layout == 'a8'
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'A8',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _layout == 'a8'
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Front language selector
                  Text(
                    'Front Side',
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
                  const SizedBox(height: 16),
                  // Front side options
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Image button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includeImageFront = !_includeImageFront;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includeImageFront
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includeImageFront
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Image',
                            style: TextStyle(
                              color: _includeImageFront
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // Phrase button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includePhraseFront = !_includePhraseFront;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includePhraseFront
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includePhraseFront
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Phrase',
                            style: TextStyle(
                              color: _includePhraseFront
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // IPA button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includeIpaFront = !_includeIpaFront;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includeIpaFront
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includeIpaFront
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'IPA',
                            style: TextStyle(
                              color: _includeIpaFront
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // Description button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includeDescriptionFront = !_includeDescriptionFront;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includeDescriptionFront
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includeDescriptionFront
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Description',
                            style: TextStyle(
                              color: _includeDescriptionFront
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Back language selector
                  Text(
                    'Back Side',
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
                  const SizedBox(height: 16),
                  // Back side options
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Image button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includeImageBack = !_includeImageBack;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includeImageBack
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includeImageBack
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Image',
                            style: TextStyle(
                              color: _includeImageBack
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // Phrase button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includePhraseBack = !_includePhraseBack;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includePhraseBack
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includePhraseBack
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Phrase',
                            style: TextStyle(
                              color: _includePhraseBack
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // IPA button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includeIpaBack = !_includeIpaBack;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includeIpaBack
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includeIpaBack
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'IPA',
                            style: TextStyle(
                              color: _includeIpaBack
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      // Description button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _includeDescriptionBack = !_includeDescriptionBack;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _includeDescriptionBack
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _includeDescriptionBack
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Description',
                            style: TextStyle(
                              color: _includeDescriptionBack
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Export button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_frontLanguageCodes.isNotEmpty && 
                                  _backLanguageCodes.isNotEmpty && 
                                  !_isExporting)
                          ? _onExportPressed
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isExporting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
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
  required List<int> conceptIds,
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
      conceptIds: conceptIds,
      completedConceptsCount: completedConceptsCount,
      availableLanguages: availableLanguages,
      visibleLanguageCodes: visibleLanguageCodes,
    ),
  );
}
