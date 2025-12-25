import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/edit_concept_controller.dart';
import 'package:archipelago/src/features/dictionary/domain/paired_dictionary_item.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:archipelago/src/features/create/presentation/widgets/drawers/topic_drawer.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';

class EditConceptScreen extends StatefulWidget {
  final PairedDictionaryItem item;

  const EditConceptScreen({
    super.key,
    required this.item,
  });

  @override
  State<EditConceptScreen> createState() => _EditConceptScreenState();
}

class _EditConceptScreenState extends State<EditConceptScreen> {
  late EditConceptController _controller;

  @override
  void initState() {
    super.initState();
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    _controller = EditConceptController(item: widget.item, topicsProvider: topicsProvider);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openTopicDrawer(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Topic Selection',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return TopicDrawer(
          topics: _controller.topics,
          initialSelectedTopics: _controller.selectedTopics,
          userId: userId,
          onTopicsChanged: (List<Topic> topics) {
            _controller.setSelectedTopics(topics);
          },
          onTopicCreated: () {
            // Topics will be refreshed automatically by the provider
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final success = await _controller.updateConcept();
    
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Concept updated successfully'),
        ),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _controller.errorMessage ?? 'Failed to update concept',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Concept'),
        actions: [
          if (_controller.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _handleSave,
              tooltip: 'Save',
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Term field
                TextField(
                  controller: _controller.termController,
                  decoration: const InputDecoration(
                    labelText: 'Term',
                    hintText: 'Enter concept term',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_controller.isLoading,
                ),
                const SizedBox(height: 16),
                
                // Description field
                TextField(
                  controller: _controller.descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter concept description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  enabled: !_controller.isLoading,
                ),
                const SizedBox(height: 16),
                
                // Topic selection with tags
                if (_controller.isLoadingTopics)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  // Label
                  Text(
                    'Topic Island',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Selected topics as icon-only tags with plus icon
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ..._controller.selectedTopics.map((topic) {
                        return Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              topic.icon != null && topic.icon!.isNotEmpty
                                  ? topic.icon!
                                  : '📁',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        );
                      }).toList(),
                      // Plus icon to add more topics (always shown, same size)
                      InkWell(
                        onTap: () => _openTopicDrawer(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Error message
                if (_controller.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _controller.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

