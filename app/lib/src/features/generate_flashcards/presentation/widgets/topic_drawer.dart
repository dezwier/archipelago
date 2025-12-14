import 'package:flutter/material.dart';
import 'package:archipelago/src/features/generate_flashcards/data/topic_service.dart' show Topic, TopicService;

class TopicDrawer extends StatefulWidget {
  final List<Topic> topics;
  final Topic? initialSelectedTopic;
  final int? userId;
  final Function(Topic?) onTopicSelected;
  final VoidCallback onTopicCreated;

  const TopicDrawer({
    super.key,
    required this.topics,
    required this.initialSelectedTopic,
    required this.userId,
    required this.onTopicSelected,
    required this.onTopicCreated,
  });

  @override
  State<TopicDrawer> createState() => _TopicDrawerState();
}

class _TopicDrawerState extends State<TopicDrawer> {
  late Topic? _selectedTopic;
  bool _isCreatingNew = false;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _iconController = TextEditingController();
  bool _isCreating = false;
  Topic? _editingTopic;
  final _editTitleController = TextEditingController();
  final _editDescriptionController = TextEditingController();
  final _editIconController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedTopic = widget.initialSelectedTopic;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _editTitleController.dispose();
    _editDescriptionController.dispose();
    _editIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height,
          child: Column(
            children: [
              // Header
              Container(
                height: kToolbarHeight + MediaQuery.of(context).padding.top,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    left: 16.0,
                    right: 16.0,
                    bottom: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Topic Islands',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              // Topics list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: widget.topics.length + 1,
                  itemBuilder: (context, index) {
                    // Show create new topic card at the end
                    if (index == widget.topics.length) {
                      return _buildCreateNewTopicCard();
                    }
                    
                    final topic = widget.topics[index];
                    final isSelected = _selectedTopic?.id == topic.id;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () {
                          // Toggle selection: if already selected, deselect; otherwise select
                          setState(() {
                            _selectedTopic = isSelected ? null : topic;
                            _isCreatingNew = false;
                          });
                          widget.onTopicSelected(_selectedTopic);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Topic content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Topic icon
                                        if (topic.icon != null && topic.icon!.isNotEmpty) ...[
                                          Text(
                                            topic.icon!,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Flexible(
                                          child: Text(
                                            topic.name.isNotEmpty
                                                ? topic.name[0].toUpperCase() + topic.name.substring(1)
                                                : topic.name,
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                                  : Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _showEditDialog(context, topic),
                                          child: Icon(
                                            Icons.edit_outlined,
                                            size: 14,
                                            color: isSelected
                                                ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (topic.description != null && topic.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        topic.description!,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: isSelected
                                              ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNewTopicCard() {
    if (!_isCreatingNew) {
      // Show card to click to create new topic
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: InkWell(
          onTap: () {
            setState(() {
              _isCreatingNew = true;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Create New Topic Island',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show inline form for creating new topic
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Topic Island',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Title field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Enter topic title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            // Icon field
            TextField(
              controller: _iconController,
              decoration: InputDecoration(
                labelText: 'Icon (optional)',
                hintText: 'Enter a single emoji',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            // Description field
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter topic description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCreating ? null : () {
                    setState(() {
                      _isCreatingNew = false;
                      _titleController.clear();
                      _descriptionController.clear();
                      _iconController.clear();
                    });
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isCreating ? null : _handleCreateTopic,
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateTopic() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID is required to create a topic'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final result = await TopicService.createTopic(
      title,
      userId: widget.userId!,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      icon: _iconController.text.trim().isNotEmpty
          ? _iconController.text.trim()
          : null,
    );

    setState(() {
      _isCreating = false;
    });

    if (result['success'] == true) {
      final newTopic = result['topic'] as Topic;
      // Clear form
      _titleController.clear();
      _descriptionController.clear();
      _iconController.clear();
      setState(() {
        _isCreatingNew = false;
        _selectedTopic = newTopic;
      });
      widget.onTopicSelected(newTopic);
      widget.onTopicCreated();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Topic created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final errorMessage = result['error'] as String? ?? 'Failed to create topic';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditDialog(BuildContext context, Topic topic) {
    _editTitleController.text = topic.name;
    _editDescriptionController.text = topic.description ?? '';
    _editIconController.text = topic.icon ?? '';
    _editingTopic = topic;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Topic Island'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextField(
                controller: _editTitleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter topic title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              // Icon field
              TextField(
                controller: _editIconController,
                decoration: InputDecoration(
                  labelText: 'Icon (optional)',
                  hintText: 'Enter a single emoji',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              // Description field
              TextField(
                controller: _editDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Enter topic description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isUpdating ? null : () {
              Navigator.of(dialogContext).pop();
              _editTitleController.clear();
              _editDescriptionController.clear();
              _editIconController.clear();
              _editingTopic = null;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isUpdating ? null : () => _handleUpdateTopic(dialogContext),
            child: _isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdateTopic(BuildContext dialogContext) async {
    final title = _editTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_editingTopic == null) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    final result = await TopicService.updateTopic(
      _editingTopic!.id,
      name: title,
      description: _editDescriptionController.text.trim().isNotEmpty
          ? _editDescriptionController.text.trim()
          : null,
      icon: _editIconController.text.trim().isNotEmpty
          ? _editIconController.text.trim()
          : null,
    );

    setState(() {
      _isUpdating = false;
    });

    if (result['success'] == true) {
      final updatedTopic = result['topic'] as Topic;
      Navigator.of(dialogContext).pop();
      _editTitleController.clear();
      _editDescriptionController.clear();
      _editIconController.clear();
      _editingTopic = null;
      
      // Update selected topic if it was the one being edited
      if (_selectedTopic?.id == updatedTopic.id) {
        setState(() {
          _selectedTopic = updatedTopic;
        });
        widget.onTopicSelected(updatedTopic);
      }
      
      widget.onTopicCreated(); // Refresh the topics list
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Topic updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final errorMessage = result['error'] as String? ?? 'Failed to update topic';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
