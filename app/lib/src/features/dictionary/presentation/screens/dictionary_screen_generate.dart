import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/dictionary_controller.dart'
    show DictionaryController, SortOption;
import 'package:archipelago/src/features/dictionary/presentation/controllers/language_visibility_manager.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/card_generation_state.dart';
import 'package:archipelago/src/features/dictionary/data/dictionary_service.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/dictionary/domain/dictionary_card.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/generate_lemmas_drawer.dart';
import 'package:archipelago/src/features/create/data/card_generation_background_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:archipelago/src/constants/api_config.dart';

/// Mixin for generate lemmas functionality in DictionaryScreen
mixin DictionaryScreenGenerate<T extends StatefulWidget> on State<T> {
  DictionaryController get controller;
  LanguageVisibilityManager get languageVisibilityManager;
  CardGenerationState get cardGenerationState;
  bool get isLoadingConcepts;
  void setIsLoadingConcepts(bool value);
  void onCardGenerationComplete();

  void openGenerateLemmasDrawer(BuildContext context) {
    final visibleLanguages = languageVisibilityManager.getVisibleLanguageCodes();
    
    if (visibleLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one visible language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showGenerateLemmasDrawer(
      context: context,
      cardGenerationState: cardGenerationState,
      onConfirmGenerate: () => handleGenerateLemmas(context),
      onConfirmGenerateImages: () => handleGenerateImages(context),
      visibleLanguageCodes: visibleLanguages,
    );
  }

  Future<void> handleGenerateLemmas(BuildContext context) async {
    // Get visible languages
    final visibleLanguages = languageVisibilityManager.getVisibleLanguageCodes();
    
    if (visibleLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one visible language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
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
      
      // Get effective filters (same logic as controller)
      final effectiveLevels = controller.getEffectiveLevels();
      final effectivePOS = controller.getEffectivePartOfSpeech();
      final effectiveTopicIds = controller.getEffectiveTopicIds();
      
      print('🔵 [Generate] Starting to fetch all pages with filters...');
      print('🔵 [Generate] Using same parameters as controller:');
      print('  - userId: ${controller.currentUser?.id}');
      print('  - visibleLanguageCodes: $visibleLanguages');
      print('  - includeLemmas: ${controller.includeLemmas}');
      print('  - includePhrases: ${controller.includePhrases}');
      print('  - search: ${controller.searchQuery.trim().isNotEmpty ? controller.searchQuery.trim() : null}');
      print('  - topicIds: $effectiveTopicIds');
      print('  - includeWithoutTopic: ${controller.showLemmasWithoutTopic}');
      print('  - levels: $effectiveLevels');
      print('  - partOfSpeech: $effectivePOS');
      
      while (hasMorePages) {
        print('🔵 [Generate] Fetching page $currentPage...');
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
        
        print('🔵 [Generate] Page $currentPage result - success: ${result['success']}, items: ${(result['items'] as List?)?.length ?? 0}');
        
        if (result['success'] == true) {
          final List<dynamic> itemsData = result['items'] as List<dynamic>;
          print('🔵 [Generate] Page $currentPage has ${itemsData.length} items');
          
          // Convert to PairedDictionaryItem
          final items = itemsData
              .map((json) => PairedDictionaryItem.fromJson(json as Map<String, dynamic>))
              .toList();
          
          allFilteredItems.addAll(items);
          
          // Check if there are more pages
          hasMorePages = result['has_next'] as bool? ?? false;
          currentPage++;
          
          print('🔵 [Generate] Has more pages: $hasMorePages');
        } else {
          // Error occurred, break the loop
          final errorMsg = result['message'] as String? ?? 'Failed to load concepts for generation';
          print('🔴 [Generate] Error on page $currentPage: $errorMsg');
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
      
      print('🔵 [Generate] Finished fetching. Total items: ${allFilteredItems.length}');
      
      // For each concept, check which visible languages are missing or incomplete
      final conceptIds = <int>[];
      final conceptTerms = <int, String>{};
      final conceptMissingLanguages = <int, List<String>>{};
      
      // Helper function to check if a field is missing (null, empty, or whitespace only)
      bool isFieldMissing(String? field) {
        return field == null || field.trim().isEmpty;
      }
      
      // Helper function to check if a card is complete (has all 3 required fields)
      bool isCardComplete(DictionaryCard card) {
        return !isFieldMissing(card.translation) &&
               !isFieldMissing(card.ipa) &&
               !isFieldMissing(card.description);
      }
      
      for (final item in allFilteredItems) {
        // Find which visible languages are missing or have incomplete cards
        final missingLanguages = <String>[];
        
        for (final lang in visibleLanguages) {
          // Find card for this language
          final matchingCards = item.cards.where(
            (card) => card.languageCode.toLowerCase() == lang.toLowerCase(),
          );
          
          // If no card exists, or card is incomplete, add to missing languages
          if (matchingCards.isEmpty) {
            missingLanguages.add(lang.toUpperCase());
          } else {
            final card = matchingCards.first;
            if (!isCardComplete(card)) {
              missingLanguages.add(lang.toUpperCase());
            }
          }
        }
        
        // Only include concepts that have at least one missing or incomplete language
        if (missingLanguages.isNotEmpty) {
          conceptIds.add(item.conceptId);
          conceptTerms[item.conceptId] = item.conceptTerm ?? 'Unknown';
          conceptMissingLanguages[item.conceptId] = missingLanguages;
        }
      }
      
      print('🔵 [Generate] Found ${conceptIds.length} concepts with missing languages');
      
      if (conceptIds.isEmpty) {
        setState(() {
          setIsLoadingConcepts(false);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No concepts found that need cards for the visible languages'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }
      
      // Set initial progress state
      setState(() {
        setIsLoadingConcepts(false);
      });
      
      cardGenerationState.startGeneration(
        totalConcepts: conceptIds.length,
        conceptIds: conceptIds,
        conceptTerms: conceptTerms,
        conceptMissingLanguages: conceptMissingLanguages,
      );
      
      // Start the background task
      await CardGenerationBackgroundService.startTask(
        conceptIds: conceptIds,
        conceptTerms: conceptTerms,
        conceptMissingLanguages: conceptMissingLanguages,
        selectedLanguages: visibleLanguages,
      );
      
      // Run the task asynchronously
      CardGenerationBackgroundService.executeTask().catchError((error) {
        print('Error in background task: $error');
        return <String, dynamic>{
          'success': false,
          'message': 'Task failed: $error',
        };
      });
      
      // Start polling for progress updates
      cardGenerationState.startProgressPolling(onCardGenerationComplete);
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

  Future<void> handleGenerateImages(BuildContext context) async {
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
      
      // Get effective filters (same logic as controller)
      final effectiveLevels = controller.getEffectiveLevels();
      final effectivePOS = controller.getEffectivePartOfSpeech();
      final effectiveTopicIds = controller.getEffectiveTopicIds();
      
      print('🟢 [Generate Images] Starting to fetch all pages with filters...');
      print('🟢 [Generate Images] Using same parameters as controller:');
      print('  - userId: ${controller.currentUser?.id}');
      print('  - visibleLanguageCodes: ${languageVisibilityManager.getVisibleLanguageCodes()}');
      print('  - includeLemmas: ${controller.includeLemmas}');
      print('  - includePhrases: ${controller.includePhrases}');
      print('  - search: ${controller.searchQuery.trim().isNotEmpty ? controller.searchQuery.trim() : null}');
      print('  - topicIds: $effectiveTopicIds');
      print('  - includeWithoutTopic: ${controller.showLemmasWithoutTopic}');
      print('  - levels: $effectiveLevels');
      print('  - partOfSpeech: $effectivePOS');
      
      while (hasMorePages) {
        print('🟢 [Generate Images] Fetching page $currentPage...');
        final result = await DictionaryService.getDictionary(
          userId: controller.currentUser?.id,
          page: currentPage,
          pageSize: 100, // Maximum allowed page size
          sortBy: controller.sortOption == SortOption.alphabetical 
              ? 'alphabetical' 
              : (controller.sortOption == SortOption.timeCreatedRecentFirst ? 'recent' : 'random'),
          search: controller.searchQuery.trim().isNotEmpty ? controller.searchQuery.trim() : null,
          visibleLanguageCodes: languageVisibilityManager.getVisibleLanguageCodes(),
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
        
        print('🟢 [Generate Images] Page $currentPage result - success: ${result['success']}, items: ${(result['items'] as List?)?.length ?? 0}');
        
        if (result['success'] == true) {
          final List<dynamic> itemsData = result['items'] as List<dynamic>;
          print('🟢 [Generate Images] Page $currentPage has ${itemsData.length} items');
          
          // Convert to PairedDictionaryItem
          final items = itemsData
              .map((json) => PairedDictionaryItem.fromJson(json as Map<String, dynamic>))
              .toList();
          
          allFilteredItems.addAll(items);
          
          // Check if there are more pages
          hasMorePages = result['has_next'] as bool? ?? false;
          currentPage++;
          
          print('🟢 [Generate Images] Has more pages: $hasMorePages');
        } else {
          // Error occurred, break the loop
          final errorMsg = result['message'] as String? ?? 'Failed to load concepts for image generation';
          print('🔴 [Generate Images] Error on page $currentPage: $errorMsg');
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
      
      print('🟢 [Generate Images] Finished fetching. Total items: ${allFilteredItems.length}');
      
      // Filter to only concepts without images
      final conceptsWithoutImages = allFilteredItems.where((item) {
        final hasImage = item.firstImageUrl != null && item.firstImageUrl!.isNotEmpty;
        return !hasImage;
      }).toList();
      
      print('🟢 [Generate Images] Found ${conceptsWithoutImages.length} concepts without images');
      
      if (conceptsWithoutImages.isEmpty) {
        setState(() {
          setIsLoadingConcepts(false);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No concepts found without images'),
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
      
      // Prepare concept data for progress tracking
      final conceptIds = conceptsWithoutImages.map((item) => item.conceptId).toList();
      final conceptTerms = <int, String>{};
      for (final item in conceptsWithoutImages) {
        conceptTerms[item.conceptId] = item.conceptTerm ?? 'Unknown';
      }
      
      // Start generation state
      cardGenerationState.startGeneration(
        totalConcepts: conceptsWithoutImages.length,
        conceptIds: conceptIds,
        conceptTerms: conceptTerms,
        conceptMissingLanguages: {}, // Not needed for images
        type: GenerationType.images,
      );
      
      // Generate images for each concept in a loop
      int successCount = 0;
      int errorCount = 0;
      final List<String> errors = [];
      
      for (int i = 0; i < conceptsWithoutImages.length; i++) {
        // Check if cancelled
        if (cardGenerationState.isCancelled) {
          print('🟡 [Generate Images] Generation cancelled');
          break;
        }
        
        final item = conceptsWithoutImages[i];
        final term = item.conceptTerm ?? item.sourceCard?.translation ?? '';
        
        // Update progress
        cardGenerationState.updateImageGenerationProgress(
          currentIndex: i,
          currentTerm: term,
          imagesCreated: successCount,
          errors: errors,
        );
        
        if (term.isEmpty) {
          print('🟡 [Generate Images] Skipping concept ${item.conceptId} - no term available');
          errorCount++;
          errors.add('Concept ${item.conceptId}: No term available');
          continue;
        }
        
        print('🟢 [Generate Images] Generating image ${i + 1}/${conceptsWithoutImages.length} for concept ${item.conceptId} ($term)');
        
        try {
          final url = Uri.parse('${ApiConfig.apiBaseUrl}/concept-image/generate');
          
          final requestBody = <String, dynamic>{
            'concept_id': item.conceptId,
            'term': term,
          };
          
          if (item.conceptDescription != null && item.conceptDescription!.isNotEmpty) {
            requestBody['description'] = item.conceptDescription;
          }
          
          if (item.topicId != null) {
            requestBody['topic_id'] = item.topicId;
          }
          
          if (item.topicDescription != null && item.topicDescription!.isNotEmpty) {
            requestBody['topic_description'] = item.topicDescription;
          }
          
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          );
          
          if (response.statusCode == 200) {
            successCount++;
            print('✅ [Generate Images] Successfully generated image for concept ${item.conceptId}');
            
            // Update progress with success
            cardGenerationState.updateImageGenerationProgress(
              currentIndex: i + 1,
              currentTerm: i + 1 < conceptsWithoutImages.length 
                  ? (conceptsWithoutImages[i + 1].conceptTerm ?? 'Unknown')
                  : null,
              imagesCreated: successCount,
              errors: errors,
            );
          } else {
            errorCount++;
            String errorMessage = 'Failed to generate image';
            try {
              final error = jsonDecode(response.body) as Map<String, dynamic>;
              errorMessage = error['detail'] as String? ?? errorMessage;
            } catch (_) {
              errorMessage = 'Failed to generate image: ${response.statusCode}';
            }
            errors.add('Concept ${item.conceptId} ($term): $errorMessage');
            print('❌ [Generate Images] Failed to generate image for concept ${item.conceptId}: $errorMessage');
            
            // Update progress with error
            cardGenerationState.updateImageGenerationProgress(
              currentIndex: i + 1,
              currentTerm: i + 1 < conceptsWithoutImages.length 
                  ? (conceptsWithoutImages[i + 1].conceptTerm ?? 'Unknown')
                  : null,
              imagesCreated: successCount,
              errors: errors,
            );
          }
        } catch (e) {
          errorCount++;
          final errorMsg = 'Error: ${e.toString()}';
          errors.add('Concept ${item.conceptId} ($term): $errorMsg');
          print('❌ [Generate Images] Exception generating image for concept ${item.conceptId}: $e');
          
          // Update progress with error
          cardGenerationState.updateImageGenerationProgress(
            currentIndex: i + 1,
            currentTerm: i + 1 < conceptsWithoutImages.length 
                ? (conceptsWithoutImages[i + 1].conceptTerm ?? 'Unknown')
                : null,
            imagesCreated: successCount,
            errors: errors,
          );
        }
      }
      
      // Mark generation as complete
      cardGenerationState.updateImageGenerationProgress(
        currentIndex: conceptsWithoutImages.length,
        currentTerm: null,
        imagesCreated: successCount,
        errors: errors,
        isComplete: true,
      );
      
      // Show completion message
      if (mounted) {
        final message = 'Generated images: $successCount success, $errorCount errors';
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
                          title: const Text('Image Generation Errors'),
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
      
      print('🟢 [Generate Images] Completed: $successCount success, $errorCount errors');
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

