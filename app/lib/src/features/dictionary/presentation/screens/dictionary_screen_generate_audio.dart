import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart'
    show DictionaryController, SortOption;
import 'package:archipelago/src/features/dictionary/presentation/controllers/card_generation_state.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/dictionary/domain/dictionary_card.dart';
import 'package:archipelago/src/features/dictionary/data/lemma_audio_service.dart';

/// Mixin for generate audio functionality in DictionaryScreen
mixin DictionaryScreenGenerateAudio<T extends StatefulWidget> on State<T> {
  DictionaryController get controller;
  CardGenerationState get cardGenerationState;
  bool get isLoadingConcepts;
  void setIsLoadingConcepts(bool value);

  Future<void> handleGenerateAudio(BuildContext context) async {
    // Set loading state
    setState(() {
      setIsLoadingConcepts(true);
    });
    
    try {
      // Get all concepts from DictionaryResponse with current filters applied
      // Loop through all pages to get all concepts that match the filters
      final List<PairedDictionaryItem> allFilteredItems = [];
      int currentPage = 1;
      bool hasMorePages = true;
      
      // Get visible languages - use controller's visible language codes to ensure consistency
      final visibleLanguages = controller.visibleLanguageCodes;
      
      // Get effective filters (same logic as controller)
      final effectiveLevels = controller.getEffectiveLevels();
      final effectivePOS = controller.getEffectivePartOfSpeech();
      final effectiveTopicIds = controller.getEffectiveTopicIds();
      
      print('🔊 [Generate Audio] Starting to fetch all pages with filters...');
      print('🔊 [Generate Audio] Using same parameters as controller:');
      print('  - userId: ${controller.currentUser?.id}');
      print('  - visibleLanguageCodes: $visibleLanguages');
      print('  - includeLemmas: ${controller.includeLemmas}');
      print('  - includePhrases: ${controller.includePhrases}');
      print('  - search: ${controller.searchQuery.trim().isNotEmpty ? controller.searchQuery.trim() : null}');
      print('  - topicIds: $effectiveTopicIds');
      print('  - includeWithoutTopic: ${controller.showLemmasWithoutTopic}');
      print('  - levels: $effectiveLevels');
      print('  - partOfSpeech: $effectivePOS');
      print('  - hasImages: ${controller.getEffectiveHasImages()}');
      print('  - hasAudio: ${controller.getEffectiveHasAudio()}');
      print('  - isComplete: ${controller.getEffectiveIsComplete()}');
      
      while (hasMorePages) {
        print('🔊 [Generate Audio] Fetching page $currentPage...');
        final result = await DictionaryService.getDictionary(
          userId: controller.currentUser?.id,
          page: currentPage,
          pageSize: 100, // Maximum allowed page size
          sortBy: controller.sortOption == SortOption.alphabetical 
              ? 'alphabetical' 
              : (controller.sortOption == SortOption.timeCreatedRecentFirst ? 'recent' : 'random'),
          search: controller.searchQuery.trim().isNotEmpty ? controller.searchQuery.trim() : null,
          visibleLanguageCodes: visibleLanguages,
          includeLemmas: controller.includeLemmas,
          includePhrases: controller.includePhrases,
          topicIds: effectiveTopicIds,
          includeWithoutTopic: controller.showLemmasWithoutTopic,
          levels: effectiveLevels,
          partOfSpeech: effectivePOS,
          hasImages: controller.getEffectiveHasImages(),
          hasAudio: controller.getEffectiveHasAudio(),
          isComplete: controller.getEffectiveIsComplete(),
        );
        
        print('🔊 [Generate Audio] Page $currentPage result - success: ${result['success']}, items: ${(result['items'] as List?)?.length ?? 0}');
        
        if (result['success'] == true) {
          final List<dynamic> itemsData = result['items'] as List<dynamic>;
          print('🔊 [Generate Audio] Page $currentPage has ${itemsData.length} items');
          
          // Convert to PairedDictionaryItem
          final items = itemsData
              .map((json) => PairedDictionaryItem.fromJson(json as Map<String, dynamic>))
              .toList();
          
          allFilteredItems.addAll(items);
          
          // Check if there are more pages
          hasMorePages = result['has_next'] as bool? ?? false;
          currentPage++;
          
          print('🔊 [Generate Audio] Has more pages: $hasMorePages');
        } else {
          // Error occurred, break the loop
          final errorMsg = result['message'] as String? ?? 'Failed to load concepts for audio generation';
          print('🔴 [Generate Audio] Error on page $currentPage: $errorMsg');
          setState(() {
            setIsLoadingConcepts(false);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
      
      print('🔊 [Generate Audio] Finished fetching. Total items: ${allFilteredItems.length}');
      
      // Collect all lemmas (cards) that don't have audio
      final lemmasWithoutAudio = <DictionaryCard>[];
      final lemmaToConceptTerm = <DictionaryCard, String>{};
      
      for (final item in allFilteredItems) {
        for (final card in item.cards) {
          // Check if card has no audio (audioPath is null or empty)
          if (card.audioPath == null || card.audioPath!.isEmpty) {
            lemmasWithoutAudio.add(card);
            lemmaToConceptTerm[card] = item.conceptTerm ?? 'Unknown';
          }
        }
      }
      
      print('🔊 [Generate Audio] Found ${lemmasWithoutAudio.length} lemmas without audio');
      
      if (lemmasWithoutAudio.isEmpty) {
        setState(() {
          setIsLoadingConcepts(false);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No lemmas found without audio'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }
      
      // Set loading state to false before starting generation
      setState(() {
        setIsLoadingConcepts(false);
      });
      
      // Prepare data for progress tracking
      final conceptIds = lemmasWithoutAudio.map((card) => card.conceptId).toList();
      final conceptTerms = <int, String>{};
      for (final card in lemmasWithoutAudio) {
        conceptTerms[card.conceptId] = lemmaToConceptTerm[card] ?? 'Unknown';
      }
      
      // Start generation state
      cardGenerationState.startGeneration(
        totalConcepts: lemmasWithoutAudio.length,
        conceptIds: conceptIds,
        conceptTerms: conceptTerms,
        conceptMissingLanguages: {}, // Not needed for audio
        type: GenerationType.audio,
      );
      
      // Generate audio for each lemma in a loop
      int successCount = 0;
      int errorCount = 0;
      final List<String> errors = [];
      
      for (int i = 0; i < lemmasWithoutAudio.length; i++) {
        // Check if cancelled
        if (cardGenerationState.isCancelled) {
          print('🟡 [Generate Audio] Generation cancelled');
          break;
        }
        
        final card = lemmasWithoutAudio[i];
        final term = card.translation;
        final conceptTerm = lemmaToConceptTerm[card] ?? 'Unknown';
        
        // Update progress
        cardGenerationState.updateAudioGenerationProgress(
          currentIndex: i,
          currentTerm: '$conceptTerm - $term',
          audioCreated: successCount,
          errors: errors,
        );
        
        if (term.isEmpty) {
          print('🟡 [Generate Audio] Skipping lemma ${card.id} - no term available');
          errorCount++;
          errors.add('Lemma ${card.id}: No term available');
          continue;
        }
        
        print('🔊 [Generate Audio] Generating audio ${i + 1}/${lemmasWithoutAudio.length} for lemma ${card.id} ($term)');
        
        try {
          final result = await LemmaAudioService.generateAudio(
            lemmaId: card.id,
            term: term,
            description: card.description,
            languageCode: card.languageCode,
          );
          
          if (result['success'] == true) {
            successCount++;
            print('✅ [Generate Audio] Successfully generated audio for lemma ${card.id}');
            
            // Update progress with success
            cardGenerationState.updateAudioGenerationProgress(
              currentIndex: i + 1,
              currentTerm: i + 1 < lemmasWithoutAudio.length 
                  ? '${lemmaToConceptTerm[lemmasWithoutAudio[i + 1]] ?? "Unknown"} - ${lemmasWithoutAudio[i + 1].translation}'
                  : null,
              audioCreated: successCount,
              errors: errors,
            );
          } else {
            errorCount++;
            final errorMessage = result['message'] as String? ?? 'Failed to generate audio';
            errors.add('Lemma ${card.id} ($term): $errorMessage');
            print('❌ [Generate Audio] Failed to generate audio for lemma ${card.id}: $errorMessage');
            
            // Update progress with error
            cardGenerationState.updateAudioGenerationProgress(
              currentIndex: i + 1,
              currentTerm: i + 1 < lemmasWithoutAudio.length 
                  ? '${lemmaToConceptTerm[lemmasWithoutAudio[i + 1]] ?? "Unknown"} - ${lemmasWithoutAudio[i + 1].translation}'
                  : null,
              audioCreated: successCount,
              errors: errors,
            );
          }
        } catch (e) {
          errorCount++;
          final errorMsg = 'Error: ${e.toString()}';
          errors.add('Lemma ${card.id} ($term): $errorMsg');
          print('❌ [Generate Audio] Exception generating audio for lemma ${card.id}: $e');
          
          // Update progress with error
          cardGenerationState.updateAudioGenerationProgress(
            currentIndex: i + 1,
            currentTerm: i + 1 < lemmasWithoutAudio.length 
                ? '${lemmaToConceptTerm[lemmasWithoutAudio[i + 1]] ?? "Unknown"} - ${lemmasWithoutAudio[i + 1].translation}'
                : null,
            audioCreated: successCount,
            errors: errors,
          );
        }
      }
      
      // Mark generation as complete
      cardGenerationState.updateAudioGenerationProgress(
        currentIndex: lemmasWithoutAudio.length,
        currentTerm: null,
        audioCreated: successCount,
        errors: errors,
        isComplete: true,
      );
      
      // Show completion message
      if (mounted) {
        final message = 'Generated audio: $successCount success, $errorCount errors';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: errorCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
            action: errors.isNotEmpty
                ? SnackBarAction(
                    label: 'Details',
                    textColor: Colors.white,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Audio Generation Errors'),
                          content: SingleChildScrollView(
                            child: Text(errors.join('\n')),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
      
      print('🔊 [Generate Audio] Completed: $successCount success, $errorCount errors');
    } catch (e) {
      setState(() {
        setIsLoadingConcepts(false);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

