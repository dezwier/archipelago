import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart'
    show DictionaryController, SortOption;
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/drawers/export_flashcards_drawer.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';

/// Helper class for export functionality in DictionaryScreen
class DictionaryScreenExportHelper {
  final DictionaryController controller;
  final LanguageVisibilityManager languageVisibilityManager;
  List<Language> get allLanguages => _getAllLanguages();
  final List<Language> Function() _getAllLanguages;
  final bool Function() getIsLoadingExport;
  final Function(bool) setIsLoadingExport;
  final BuildContext context;
  final bool Function() mounted;
  final VoidCallback setState;

  DictionaryScreenExportHelper({
    required this.controller,
    required this.languageVisibilityManager,
    required List<Language> Function() getAllLanguages,
    required this.getIsLoadingExport,
    required this.setIsLoadingExport,
    required this.context,
    required this.mounted,
    required this.setState,
  }) : _getAllLanguages = getAllLanguages;

  Future<void> showExportDrawer() async {
    if (getIsLoadingExport()) return; // Prevent multiple simultaneous exports
    
    setState();
    setIsLoadingExport(true);
    
    try {
      final visibleLanguageCodes = languageVisibilityManager.getVisibleLanguageCodes();
      
      print('🔵 [Export] Starting export - visibleLanguages: $visibleLanguageCodes');
      
      // Fetch ALL concept IDs that match the current filters (not just visible ones)
      // Use the EXACT same parameters as the controller uses
      // Loop through all pages to get all results
      
      final Set<int> conceptIdSet = {};
      int currentPage = 1;
      bool hasMorePages = true;
      int totalPagesFetched = 0;
      
      // Use the same helper methods as the controller
      final effectiveTopicIds = controller.getEffectiveTopicIds();
      final effectiveLevels = controller.getEffectiveLevels();
      final effectivePartOfSpeech = controller.getEffectivePartOfSpeech();
      
      print('🔵 [Export] Starting to fetch pages with filters...');
      print('🔵 [Export] Using same parameters as controller:');
      print('  - userId: ${controller.currentUser?.id}');
      print('  - visibleLanguageCodes: $visibleLanguageCodes');
      print('  - includeLemmas: ${controller.includeLemmas}');
      print('  - includePhrases: ${controller.includePhrases}');
      print('  - search: ${controller.searchQuery.trim().isNotEmpty ? controller.searchQuery.trim() : null}');
      print('  - topicIds: $effectiveTopicIds');
      print('  - includeWithoutTopic: ${controller.showLemmasWithoutTopic}');
      print('  - levels: $effectiveLevels');
      print('  - partOfSpeech: $effectivePartOfSpeech');
      
      while (hasMorePages) {
        print('🔵 [Export] Fetching page $currentPage...');
        final result = await DictionaryService.getDictionary(
          userId: controller.currentUser?.id,
          page: currentPage,
          pageSize: 100, // Maximum allowed page size
          sortBy: controller.sortOption == SortOption.alphabetical 
              ? 'alphabetical' 
              : (controller.sortOption == SortOption.timeCreatedRecentFirst ? 'recent' : 'random'),
          search: controller.searchQuery.trim().isNotEmpty ? controller.searchQuery.trim() : null,
          visibleLanguageCodes: visibleLanguageCodes,
          includeLemmas: controller.includeLemmas,
          includePhrases: controller.includePhrases,
          topicIds: effectiveTopicIds, // Use helper method
          includeWithoutTopic: controller.showLemmasWithoutTopic,
          levels: effectiveLevels, // Use helper method
          partOfSpeech: effectivePartOfSpeech, // Use helper method
        );
        
        print('🔵 [Export] Page $currentPage result - success: ${result['success']}, items: ${(result['items'] as List?)?.length ?? 0}');
        
        if (result['success'] == true) {
          final List<dynamic> itemsData = result['items'] as List<dynamic>;
          print('🔵 [Export] Page $currentPage has ${itemsData.length} items');
          
          // Extract unique concept IDs from items
          for (final item in itemsData) {
            final conceptId = (item as Map<String, dynamic>)['concept_id'] as int?;
            if (conceptId != null) {
              conceptIdSet.add(conceptId);
            }
          }
          
          print('🔵 [Export] Total unique concept IDs so far: ${conceptIdSet.length}');
          
          // Check if there are more pages
          hasMorePages = result['has_next'] as bool? ?? false;
          totalPagesFetched++;
          currentPage++;
          
          print('🔵 [Export] Has more pages: $hasMorePages');
        } else {
          // Error occurred, break the loop
          final errorMsg = result['message'] as String? ?? 'Failed to load concepts for export';
          print('🔴 [Export] Error on page $currentPage: $errorMsg');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        }
      }
      
      print('🔵 [Export] Finished fetching. Total pages: $totalPagesFetched, Total concept IDs: ${conceptIdSet.length}');
      
      if (!context.mounted) {
        print('🔴 [Export] Context not mounted, cannot show drawer');
        return;
      }
      
      if (conceptIdSet.isEmpty) {
        print('🔴 [Export] No concept IDs found!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No concepts found to export with current filters'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final conceptIds = conceptIdSet.toList();
      print('🔵 [Export] Opening export drawer with ${conceptIds.length} concept IDs');
      
      showExportFlashcardsDrawer(
        context: context,
        conceptIds: conceptIds,
        completedConceptsCount: conceptIds.length,
        availableLanguages: allLanguages,
        visibleLanguageCodes: visibleLanguageCodes,
      );
      
      print('🔵 [Export] Export drawer opened successfully');
    } catch (e, stackTrace) {
      print('🔴 [Export] Exception occurred: $e');
      print('🔴 [Export] Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading concepts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted()) {
        setState();
        setIsLoadingExport(false);
        print('🔵 [Export] Loading state reset');
      }
    }
  }
}

