import 'package:flutter/material.dart';
import 'dart:io';
import 'package:archipelago/src/features/create/domain/topic.dart';
import 'package:archipelago/src/features/create/presentation/controllers/create_concept_controller.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'image_selector_widget.dart';
import 'create_selectors_widget.dart';
import 'package:archipelago/src/common_widgets/concept_drawer/concept_drawer.dart';

class CreateConceptSection extends StatefulWidget {
  final Function(Function())? onRefreshCallbackReady;
  
  const CreateConceptSection({
    super.key,
    this.onRefreshCallbackReady,
  });

  @override
  State<CreateConceptSection> createState() => _CreateConceptSectionState();
}

class _CreateConceptSectionState extends State<CreateConceptSection> {
  final _formKey = GlobalKey<FormState>();
  final _termController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _termFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  
  late final CreateConceptController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CreateConceptController();
    
    // Initialize controller
    _controller.initialize();
    
    // Register refresh callback with parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRefreshCallbackReady?.call(_controller.loadTopics);
    });
    
    // Prevent fields from requesting focus automatically
    _termFocusNode.canRequestFocus = false;
    _descriptionFocusNode.canRequestFocus = false;
    
    // Reset canRequestFocus when focus is lost
    _termFocusNode.addListener(() {
      if (!_termFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_termFocusNode.hasFocus) {
            _termFocusNode.canRequestFocus = false;
          }
        });
      }
    });
    _descriptionFocusNode.addListener(() {
      if (!_descriptionFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_descriptionFocusNode.hasFocus) {
            _descriptionFocusNode.canRequestFocus = false;
          }
        });
      }
    });
    
    // Sync text controllers with controller state
    _termController.addListener(() {
      _controller.setTerm(_termController.text);
    });
    _descriptionController.addListener(() {
      _controller.setDescription(_descriptionController.text);
    });
  }

  @override
  void dispose() {
    _termController.dispose();
    _descriptionController.dispose();
    _termFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCreateConcept() async {
    if (_formKey.currentState!.validate()) {
      final result = await _controller.createConcept();
      
      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Failed to create concept'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Show warning message if any (e.g., image upload failed)
      if (result.warningMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.warningMessage!),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Show the concept drawer with the newly created concept
      if (mounted && result.conceptId != null) {
        // Show the drawer after a short delay to let the snackbar appear first
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            showConceptDrawer(
              context,
              conceptId: result.conceptId!,
              languageVisibility: result.languageVisibility,
              languagesToShow: result.languagesToShow,
            );
          }
        });
      }
      
      // Clear form after successful creation
      _termController.clear();
      _descriptionController.clear();
      _controller.clearForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Create Concepts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image selector with selectors on the right
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image selector on the left
                      Expanded(
                        flex: 1,
                        child: ImageSelectorWidget(
                          initialImage: _controller.selectedImage,
                          onImageChanged: (File? image) {
                            _controller.setSelectedImage(image);
                          },
                          term: _controller.term,
                          description: _controller.description.isNotEmpty 
                              ? _controller.description 
                              : null,
                          topicDescription: _controller.selectedTopic?.description,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Selectors on the right
                      Expanded(
                        flex: 1,
                        child: CreateSelectorsWidget(
                          topics: _controller.topics,
                          isLoadingTopics: _controller.isLoadingTopics,
                          selectedTopic: _controller.selectedTopic,
                          userId: _controller.userId,
                          onTopicSelected: (Topic? topic) {
                            _controller.setSelectedTopic(topic);
                          },
                          onTopicCreated: () async {
                            await _controller.loadTopics();
                          },
                          languages: _controller.languages,
                          isLoadingLanguages: _controller.isLoadingLanguages,
                          selectedLanguages: _controller.selectedLanguages,
                          onLanguageSelectionChanged: (List<String> selected) {
                            _controller.setSelectedLanguages(selected);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Word or Phrase field
                  TextFormField(
                    controller: _termController,
                    focusNode: _termFocusNode,
                    autofocus: false,
                    enabled: true,
                    textCapitalization: TextCapitalization.sentences,
                    onTap: () {
                      _termFocusNode.canRequestFocus = true;
                      _termFocusNode.requestFocus();
                    },
                    decoration: InputDecoration(
                      labelText: 'Concept',
                      hintText: 'Enter the word or phrase',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    minLines: 1,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a term';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Description field
                  TextFormField(
                    controller: _descriptionController,
                    focusNode: _descriptionFocusNode,
                    autofocus: false,
                    enabled: true,
                    textCapitalization: TextCapitalization.sentences,
                    onTap: () {
                      _descriptionFocusNode.canRequestFocus = true;
                      _descriptionFocusNode.requestFocus();
                    },
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Enter the core meaning in English (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.light
                              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),

                  // Create Concept button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _controller.isCreatingConcept ? null : _handleCreateConcept,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _controller.isCreatingConcept
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Concept',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  
                  // Status feedback
                  if (_controller.statusMessage != null || _controller.languageStatus.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_controller.statusMessage != null)
                            Row(
                              children: [
                                Icon(
                                  _controller.statusMessage!.contains('✓') 
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                                  size: 16,
                                  color: _controller.statusMessage!.contains('✓')
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _controller.statusMessage!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (_controller.languageStatus.isNotEmpty) ...[
                            if (_controller.statusMessage != null) const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _controller.selectedLanguages.map((langCode) {
                                final isComplete = _controller.languageStatus[langCode] ?? false;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      LanguageEmoji.getEmoji(langCode),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      isComplete ? Icons.check : Icons.hourglass_empty,
                                      size: 14,
                                      color: isComplete
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
