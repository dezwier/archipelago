import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/sheets/dictionary_filter_sheet.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/sheets/visibility_options_sheet.dart';
import 'package:archipelago/src/features/dictionary/presentation/screens/edit_concept_screen.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_drawer.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_delete.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';

/// Mixin for event handlers in DictionaryScreen
mixin DictionaryScreenHandlers<T extends StatefulWidget> on State<T> {
  DictionaryController get controller;
  LanguageVisibilityManager get languageVisibilityManager;
  List<Language> get allLanguages;
  List<Topic> get allTopics;
  bool get isLoadingTopics;
  bool get showDescription;
  bool get showExtraInfo;
  void setShowDescription(bool value);
  void setShowExtraInfo(bool value);

  void showFilteringMenu(BuildContext context) {
    showDictionaryFilterSheet(
      context: context,
      controller: controller,
      topics: allTopics,
      isLoadingTopics: isLoadingTopics,
    );
  }

  void showFilterMenu(BuildContext context) {
    // Get the first visible language for alphabetical sorting
    final firstVisibleLanguage = languageVisibilityManager.languagesToShow.isNotEmpty 
        ? languageVisibilityManager.languagesToShow.first 
        : null;
    showVisibilityOptionsSheet(
      context: context,
      allLanguages: allLanguages,
      languageVisibility: languageVisibilityManager.languageVisibility,
      showDescription: showDescription,
      showExtraInfo: showExtraInfo,
      controller: controller,
      firstVisibleLanguage: firstVisibleLanguage,
      onLanguageVisibilityToggled: (languageCode) {
        setState(() {
          languageVisibilityManager.toggleLanguageVisibility(languageCode);
          // Update language filter for search (concepts are no longer filtered by visibility)
          controller.setLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
          // Update visible languages - this will refresh dictionary and counts
          controller.setVisibleLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
        });
      },
      onShowDescriptionChanged: (value) {
        setState(() {
          setShowDescription(value);
        });
      },
      onShowExtraInfoChanged: (value) {
        setState(() {
          setShowExtraInfo(value);
        });
      },
    );
  }

  Future<void> handleEdit(PairedDictionaryItem item) async {
    // Navigate to edit concept screen
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditConceptScreen(item: item),
      ),
    );

    if (result == true && mounted) {
      // Refresh the dictionary list to show updated concept
      await controller.refresh();
      
      // Refresh the detail drawer if it's still open
      // Find the updated item in the list
      final updatedItems = controller.filteredItems;
      final updatedItem = updatedItems.firstWhere(
        (i) => i.conceptId == item.conceptId,
        orElse: () => item,
      );
      
      // Close current drawer and reopen with updated item
      if (mounted) {
        Navigator.of(context).pop(); // Close current drawer
        handleItemTap(updatedItem); // Reopen with updated item
      }
    }
  }

  Future<void> handleDelete(PairedDictionaryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteDictionaryDialog(),
    );

    if (confirmed == true && mounted) {
      final success = await controller.deleteItem(item);

      if (mounted) {
        // Close the detail drawer if deletion was successful
        if (success) {
          Navigator.of(context).pop();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Translation deleted successfully'
                  : controller.errorMessage ?? 'Failed to delete translation',
            ),
            backgroundColor: success
                ? null
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void handleItemTap(PairedDictionaryItem item) {
    showConceptDrawer(
      context,
      conceptId: item.conceptId,
      languageVisibility: languageVisibilityManager.languageVisibility,
      languagesToShow: languageVisibilityManager.languagesToShow,
      onEdit: () => handleEdit(item),
      onDelete: () => handleDelete(item),
      onItemUpdated: () => handleItemUpdated(context, item),
    );
  }

  Future<void> handleItemUpdated(BuildContext context, PairedDictionaryItem item) async {
    // Refresh the dictionary list to get updated item
    await controller.refresh();
    
    // The drawer will reload the concept data itself via its onItemUpdated callback
    // No need to close and reopen - the drawer handles its own refresh
  }
}

