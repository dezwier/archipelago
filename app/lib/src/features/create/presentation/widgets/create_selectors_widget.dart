import 'package:flutter/material.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart' show Topic;
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/common_widgets/language_selection_widget.dart';
import 'topic_drawer.dart';

class CreateSelectorsWidget extends StatelessWidget {
  final List<Topic> topics;
  final bool isLoadingTopics;
  final Topic? selectedTopic;
  final int? userId;
  final ValueChanged<Topic?> onTopicSelected;
  final VoidCallback onTopicCreated;
  final List<Language> languages;
  final bool isLoadingLanguages;
  final List<String> selectedLanguages;
  final ValueChanged<List<String>> onLanguageSelectionChanged;

  const CreateSelectorsWidget({
    super.key,
    required this.topics,
    required this.isLoadingTopics,
    required this.selectedTopic,
    required this.userId,
    required this.onTopicSelected,
    required this.onTopicCreated,
    required this.languages,
    required this.isLoadingLanguages,
    required this.selectedLanguages,
    required this.onLanguageSelectionChanged,
  });

  void _openTopicDrawer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Topic Selection',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return TopicDrawer(
          topics: topics,
          initialSelectedTopic: selectedTopic,
          userId: userId,
          onTopicSelected: (Topic? topic) {
            onTopicSelected(topic);
          },
          onTopicCreated: () async {
            onTopicCreated();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic selector
        isLoadingTopics
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            : OutlinedButton(
                onPressed: () => _openTopicDrawer(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedTopic != null
                            ? (selectedTopic!.name.isNotEmpty
                                ? selectedTopic!.name[0].toUpperCase() + selectedTopic!.name.substring(1)
                                : selectedTopic!.name)
                            : 'Select Topic Island',
                        style: TextStyle(
                          color: selectedTopic != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
        const SizedBox(height: 8),

        // Language selector
        LanguageSelectionWidget(
          languages: languages,
          selectedLanguages: selectedLanguages,
          isLoading: isLoadingLanguages,
          onSelectionChanged: onLanguageSelectionChanged,
        ),
      ],
    );
  }
}

