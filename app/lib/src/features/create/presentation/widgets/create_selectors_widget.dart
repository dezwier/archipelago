import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/common_widgets/language_selection_widget.dart';

class CreateSelectorsWidget extends StatelessWidget {
  final List<Topic> topics;
  final bool isLoadingTopics;
  final Topic? selectedTopic; // Deprecated, use selectedTopics
  final List<Topic> selectedTopics;
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
    this.selectedTopic,
    this.selectedTopics = const [],
    required this.userId,
    required this.onTopicSelected,
    required this.onTopicCreated,
    required this.languages,
    required this.isLoadingLanguages,
    required this.selectedLanguages,
    required this.onLanguageSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language selector only (topic selector removed - handled by tags + plus icon)
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
