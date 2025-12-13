import 'package:flutter/material.dart';
import '../controllers/edit_concept_controller.dart';
import '../../domain/paired_vocabulary_item.dart';

class EditConceptScreen extends StatefulWidget {
  final PairedVocabularyItem item;

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
    _controller = EditConceptController(item: widget.item);
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

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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
                
                // Topic dropdown
                if (_controller.isLoadingTopics)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DropdownButtonFormField<int?>(
                    value: _controller.selectedTopicId,
                    decoration: const InputDecoration(
                      labelText: 'Topic',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No topic'),
                      ),
                      ..._controller.topics.map((topic) {
                        return DropdownMenuItem<int?>(
                          value: topic.id,
                          child: Text(_toTitleCase(topic.name)),
                        );
                      }),
                    ],
                    onChanged: _controller.isLoading
                        ? null
                        : (value) {
                            _controller.setSelectedTopicId(value);
                          },
                  ),
                
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

