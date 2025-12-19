import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/presentation/controllers/learn_controller.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/learn_lemma_list.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/common_widgets/filter_fab_buttons.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/create/domain/topic.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final LearnController _controller;
  List<Topic> _topics = [];
  bool _isLoadingTopics = false;

  @override
  void initState() {
    super.initState();
    _controller = LearnController();
    _controller.addListener(_onControllerChanged);
    
    // Initialize controller and load topics after user is loaded
    _controller.initialize().then((_) {
      _loadTopics();
    });
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

  Future<void> _loadTopics() async {
    setState(() {
      _isLoadingTopics = true;
    });

    final userId = _controller.currentUser?.id;
    final topics = await TopicService.getTopics(userId: userId);

    if (mounted) {
      setState(() {
        _topics = topics;
        _isLoadingTopics = false;
      });
    }
  }

  void _showFilterSheet() {
    // Reload topics if they're empty (in case they weren't loaded yet)
    if (_topics.isEmpty && !_isLoadingTopics) {
      _loadTopics();
    }
    
    showFilterSheet(
      context: context,
      filterState: _controller,
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
      }) {
        _controller.batchUpdateFilters(
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
        );
      },
      topics: _topics,
      isLoadingTopics: _isLoadingTopics,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: LearnLemmaList(
              concepts: _controller.concepts,
              isLoading: _controller.isLoading,
              errorMessage: _controller.errorMessage,
              nativeLanguage: _controller.nativeLanguage,
              learningLanguage: _controller.learningLanguage,
            ),
          );
        },
      ),
      floatingActionButton: FilterFabButtons(
        onFilterPressed: _showFilterSheet,
      ),
    );
  }
}
