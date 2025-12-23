import 'package:flutter/material.dart';
import 'package:archipelago/src/features/learn/presentation/controllers/learn_controller.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/lesson_start_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/exercise_carousel_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/lesson_report_card_widget.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/create/domain/topic.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final LearnController _controller;
  List<Topic> _topics = [];
  bool _isLoadingTopics = false;
  Map<String, dynamic> Function()? _getCurrentWidgetSettings;

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

  Future<void> _handleRefresh() async {
    // Get current widget settings if available, otherwise use controller's current state
    if (_getCurrentWidgetSettings != null) {
      final settings = _getCurrentWidgetSettings!();
      return _controller.refresh(
        cardsToLearn: settings['cardsToLearn'] as int,
        includeNewCards: settings['includeNewCards'] as bool,
        includeLearnedCards: settings['includeLearnedCards'] as bool,
      );
    } else {
      return _controller.refresh();
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

  void _showDismissConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Leave Lesson?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'You will lose all progress in this lesson. Are you sure you want to leave?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _controller.dismissLesson();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Leave Lesson'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          // Show loading state only on initial load (not when refreshing)
          if (_controller.isLoading && !_controller.isRefreshing) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            );
          }

          if (_controller.errorMessage != null) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _controller.errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Show empty state if no concepts
          if (_controller.concepts.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No new cards available',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          // Show report card if lesson finished
          if (_controller.showReportCard) {
            return LessonReportCardWidget(
              performances: _controller.exercisePerformances,
              onDone: () {
                _controller.dismissReportCard();
              },
            );
          }

          // Show exercise carousel if lesson is active
          if (_controller.isLessonActive) {
            return ExerciseCarouselWidget(
              exercises: _controller.exercises,
              currentIndex: _controller.currentLessonIndex,
              nativeLanguage: _controller.nativeLanguage,
              learningLanguage: _controller.learningLanguage,
              onPrevious: _controller.previousCard,
              onNext: _controller.nextCard,
              onFinish: _controller.finishLesson,
              onDismiss: _showDismissConfirmation,
              onExerciseStart: _controller.startExerciseTracking,
              onExerciseComplete: _controller.completeExerciseTracking,
            );
          }

          // Show start screen if lesson is not active
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: LessonStartWidget(
              cardCount: _controller.concepts.length,
              totalConceptsCount: _controller.totalConceptsCount,
              filteredConceptsCount: _controller.filteredConceptsCount,
              conceptsWithBothLanguagesCount: _controller.conceptsWithBothLanguagesCount,
              conceptsWithoutCardsCount: _controller.conceptsWithoutCardsCount,
              cardsToLearn: _controller.cardsToLearn,
              includeNewCards: _controller.includeNewCards,
              includeLearnedCards: _controller.includeLearnedCards,
              isGenerating: _controller.isRefreshing,
              onCardsToLearnChanged: _controller.setCardsToLearn,
              onFilterPressed: _showFilterSheet,
              onStartLesson: _controller.startLesson,
              onGenerateWorkout: (cardsToLearn, includeNewCards, includeLearnedCards) {
                _controller.generateWorkout(
                  cardsToLearn: cardsToLearn,
                  includeNewCards: includeNewCards,
                  includeLearnedCards: includeLearnedCards,
                );
              },
              onGetCurrentSettingsReady: (getCurrentSettings) {
                _getCurrentWidgetSettings = getCurrentSettings;
              },
            ),
          );
        },
      ),
    );
  }
}
