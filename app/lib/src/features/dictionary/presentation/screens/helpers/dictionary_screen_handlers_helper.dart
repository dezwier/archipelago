import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/sheets/visibility_options_sheet.dart';
import 'package:archipelago/src/features/dictionary/presentation/screens/edit_concept_screen.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_drawer.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_delete.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/profile/data/statistics_service.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';

/// Helper class for event handlers in DictionaryScreen
class DictionaryScreenHandlersHelper {
  final DictionaryController controller;
  final LanguageVisibilityManager languageVisibilityManager;
  List<Language> get allLanguages => _getAllLanguages();
  List<Topic> get allTopics => _getAllTopics();
  bool get isLoadingTopics => _getIsLoadingTopics();
  final List<Language> Function() _getAllLanguages;
  final List<Topic> Function() _getAllTopics;
  final bool Function() _getIsLoadingTopics;
  final bool showDescription;
  final bool showExtraInfo;
  final Function(bool) setShowDescription;
  final Function(bool) setShowExtraInfo;
  final BuildContext context;
  final bool Function() mounted;
  final VoidCallback setState;

  DictionaryScreenHandlersHelper({
    required this.controller,
    required this.languageVisibilityManager,
    required List<Language> Function() getAllLanguages,
    required List<Topic> Function() getAllTopics,
    required bool Function() getIsLoadingTopics,
    required this.showDescription,
    required this.showExtraInfo,
    required this.setShowDescription,
    required this.setShowExtraInfo,
    required this.context,
    required this.mounted,
    required this.setState,
  }) : _getAllLanguages = getAllLanguages,
       _getAllTopics = getAllTopics,
       _getIsLoadingTopics = getIsLoadingTopics;

  Future<void> showFilteringMenu() async {
    // Load Leitner distribution if user and learning language are available
    List<int> availableBins = [];
    if (controller.currentUser?.id != null && 
        controller.currentUser?.langLearning != null &&
        controller.currentUser!.langLearning!.isNotEmpty) {
      try {
        final result = await StatisticsService.getLeitnerDistribution(
          userId: controller.currentUser!.id,
          languageCode: controller.currentUser!.langLearning!,
          includeLemmas: controller.includeLemmas,
          includePhrases: controller.includePhrases,
          topicIds: controller.getEffectiveTopicIds(),
          includeWithoutTopic: controller.showLemmasWithoutTopic,
          levels: controller.getEffectiveLevels(),
          partOfSpeech: controller.getEffectivePartOfSpeech(),
          hasImages: controller.getEffectiveHasImages(),
          hasAudio: controller.getEffectiveHasAudio(),
          isComplete: controller.getEffectiveIsComplete(),
        );
        
        if (result['success'] == true) {
          final distribution = result['data'] as LeitnerDistribution;
          availableBins = distribution.distribution
              .where((binData) => binData.count > 0)
              .map((binData) => binData.bin)
              .toList()
            ..sort();
          // Set available bins in controller
          controller.setAvailableBins(availableBins);
          // Initialize selected bins if empty
          if (controller.selectedLeitnerBins.isEmpty && availableBins.isNotEmpty) {
            controller.batchUpdateFilters(leitnerBins: availableBins.toSet());
          }
        }
      } catch (e) {
        // Silently fail - just don't show bins
      }
    }
    
    showFilterSheet(
      context: context,
      filterState: controller,
      onApplyFilters: ({
        Set<int>? topicIds,
        bool? showLemmasWithoutTopic,
        Set<String>? levels,
        Set<String>? partOfSpeech,
        bool? includeLemmas,
        bool? includePhrases,
        bool? hasImages,
        bool? hasNoImages,
        bool? hasAudio,
        bool? hasNoAudio,
        bool? isComplete,
        bool? isIncomplete,
        Set<int>? leitnerBins,
        Set<String>? learningStatus,
      }) {
        controller.batchUpdateFilters(
          topicIds: topicIds,
          showLemmasWithoutTopic: showLemmasWithoutTopic,
          levels: levels,
          partOfSpeech: partOfSpeech,
          includeLemmas: includeLemmas,
          includePhrases: includePhrases,
          hasImages: hasImages,
          hasNoImages: hasNoImages,
          hasAudio: hasAudio,
          hasNoAudio: hasNoAudio,
          isComplete: isComplete,
          isIncomplete: isIncomplete,
          leitnerBins: leitnerBins,
          learningStatus: learningStatus,
        );
      },
      topics: allTopics,
      isLoadingTopics: isLoadingTopics,
      availableBins: availableBins,
      userId: controller.currentUser?.id,
      maxBins: controller.currentUser?.leitnerMaxBins ?? 7,
    );
  }

  void showFilterMenu() {
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
        setState();
        languageVisibilityManager.toggleLanguageVisibility(languageCode);
        // Update language filter for search (concepts are no longer filtered by visibility)
        controller.setLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
        // Update visible languages - this will refresh dictionary and counts
        controller.setVisibleLanguageCodes(languageVisibilityManager.getVisibleLanguageCodes());
      },
      onShowDescriptionChanged: (value) {
        setState();
        setShowDescription(value);
      },
      onShowExtraInfoChanged: (value) {
        setState();
        setShowExtraInfo(value);
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

    if (result == true && mounted()) {
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
      if (mounted()) {
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

    if (confirmed == true && mounted()) {
      final success = await controller.deleteItem(item);

      if (mounted()) {
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
      onItemUpdated: () => handleItemUpdated(item),
      userId: controller.currentUser?.id,
    );
  }

  Future<void> handleItemUpdated(PairedDictionaryItem item) async {
    // Refresh the dictionary list to get updated item
    await controller.refresh();
    
    // The drawer will reload the concept data itself via its onItemUpdated callback
    // No need to close and reopen - the drawer handles its own refresh
  }
}

