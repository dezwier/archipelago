import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archipelago/src/features/learn/presentation/controllers/learn_controller.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/lesson_start_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/common/exercise_carousel_widget.dart';
import 'package:archipelago/src/features/learn/presentation/widgets/lesson_report_card_widget.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/profile/data/statistics_service.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';
import 'package:archipelago/src/features/shared/providers/languages_provider.dart';

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
  
  // Leitner distribution state
  LeitnerDistribution? _leitnerDistribution;
  bool _isLoadingLeitner = false;
  List<Language> _languages = [];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    _controller = LearnController(authProvider);
    _controller.addListener(_onControllerChanged);
    
    // Load topics and languages from providers
    _loadTopics(topicsProvider);
    _loadLanguages(languagesProvider);
    
    // Listen to provider changes
    topicsProvider.addListener(_onTopicsChanged);
    languagesProvider.addListener(_onLanguagesChanged);
    
    // Wait for auth provider to finish initializing, then initialize controller
    if (authProvider.isInitializing) {
      // Wait for initialization to complete
      authProvider.addListener(_onAuthInitialized);
    } else {
      _initializeController();
    }
  }

  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    authProvider.removeListener(_onAuthInitialized);
    topicsProvider.removeListener(_onTopicsChanged);
    languagesProvider.removeListener(_onLanguagesChanged);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onAuthInitialized() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isInitializing) {
      authProvider.removeListener(_onAuthInitialized);
      _initializeController();
    }
  }

  void _initializeController() {
    _controller.initialize().then((_) {
      _loadLeitnerDistribution();
    });
  }

  Future<void> _handleRefresh() async {
    // Get current widget settings if available, otherwise use controller's current state
    // Refresh uses current filter state (including Leitner bins and learning status)
    if (_getCurrentWidgetSettings != null) {
      final settings = _getCurrentWidgetSettings!();
      await _controller.refresh(
        cardsToLearn: settings['cardsToLearn'] as int,
        cardMode: settings['cardMode'] as String,
      );
    } else {
      await _controller.refresh();
    }
    // Also refresh Leitner distribution when refreshing (with current filters)
    await _loadLeitnerDistribution();
  }

  Future<void> _handleConfigUpdated() async {
    // Reload user data from SharedPreferences to get updated Leitner config
    await _controller.refreshUser();
    // Refresh Leitner distribution with new config
    await _loadLeitnerDistribution();
    // Trigger UI update
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleFinishLesson() async {
    // Finish the lesson
    await _controller.finishLesson();
    // Refresh user data to ensure we have the latest Leitner config
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.refreshUser();
    // Refresh controller's user-dependent state
    await _controller.refreshUser();
    // Refresh Leitner distribution after lesson completion to show updated bin counts
    await _loadLeitnerDistribution();
    // Trigger UI update
    if (mounted) {
      setState(() {});
    }
  }

  void _loadTopics(TopicsProvider topicsProvider) {
    final wasEmpty = _controller.selectedTopicIds.isEmpty;
    
    setState(() {
      _isLoadingTopics = topicsProvider.isLoading;
      _topics = topicsProvider.topics;
    });
    
    // Initialize all topics as selected by default if no topics are currently selected
    // This ensures all topics are ON by default
    // Check after setState to ensure we have the latest topics
    if (_topics.isNotEmpty && wasEmpty) {
      final allTopicIds = _topics.map((t) => t.id).toSet();
      _controller.batchUpdateFilters(topicIds: allTopicIds);
    }
  }

  void _loadLanguages(LanguagesProvider languagesProvider) {
    if (mounted) {
      setState(() {
        _languages = languagesProvider.languages;
      });
    }
  }
  
  void _onTopicsChanged() {
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    _loadTopics(topicsProvider);
  }
  
  void _onLanguagesChanged() {
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    _loadLanguages(languagesProvider);
  }

  Future<void> _loadLeitnerDistribution() async {
    final user = _controller.currentUser;
    final learningLanguage = _controller.learningLanguage;
    
    if (user == null || learningLanguage == null || learningLanguage.isEmpty) {
      if (mounted) {
        setState(() {
          _leitnerDistribution = null;
          _isLoadingLeitner = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingLeitner = true;
    });

    try {
      // Convert LearnController filters to StatisticsService format
      final result = await StatisticsService.getLeitnerDistribution(
        userId: user.id,
        languageCode: learningLanguage,
        includeLemmas: _controller.includeLemmas,
        includePhrases: _controller.includePhrases,
        topicIds: _controller.getEffectiveTopicIds(),
        includeWithoutTopic: _controller.showLemmasWithoutTopic,
        levels: _controller.getEffectiveLevels(),
        partOfSpeech: _controller.getEffectivePartOfSpeech(),
        hasImages: _controller.getEffectiveHasImages(),
        hasAudio: _controller.getEffectiveHasAudio(),
        isComplete: _controller.getEffectiveIsComplete(),
        leitnerBins: _controller.getEffectiveLeitnerBinsForUser(),
        learningStatus: _controller.getEffectiveLearningStatus(),
      );

      if (mounted) {
        if (result['success'] == true) {
          final distribution = result['data'] as LeitnerDistribution;
          // Extract available bins and set them in controller
          final availableBins = distribution.distribution
              .where((binData) => binData.count > 0)
              .map((binData) => binData.bin)
              .toList()
            ..sort();
          _controller.setAvailableBins(availableBins);
          
          // If selected bins is empty, initialize with all available bins
          if (_controller.selectedLeitnerBins.isEmpty && availableBins.isNotEmpty) {
            _controller.batchUpdateFilters(leitnerBins: availableBins.toSet());
          }
          
          setState(() {
            _leitnerDistribution = distribution;
            _isLoadingLeitner = false;
          });
        } else {
          setState(() {
            _leitnerDistribution = null;
            _isLoadingLeitner = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leitnerDistribution = null;
          _isLoadingLeitner = false;
        });
      }
    }
  }

  /// Extract available bins from Leitner distribution
  List<int> _getAvailableBins() {
    if (_leitnerDistribution == null) return [];
    // Get bins that have count > 0
    return _leitnerDistribution!.distribution
        .where((binData) => binData.count > 0)
        .map((binData) => binData.bin)
        .toList()
      ..sort();
  }

  void _showFilterSheet() {
    // Reload topics if they're empty (in case they weren't loaded yet)
    if (_topics.isEmpty && !_isLoadingTopics) {
      final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
      _loadTopics(topicsProvider);
    }
    
    showFilterSheet(
      context: context,
      filterState: _controller,
      availableBins: _getAvailableBins(),
      userId: _controller.currentUser?.id,
      maxBins: _controller.currentUser?.leitnerMaxBins ?? 7,
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
        Set<int>? leitnerBins,
        Set<String>? learningStatus,
      }) async {
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
          leitnerBins: leitnerBins,
          learningStatus: learningStatus,
        );
        // Update counters after filters are applied - reload immediately to reflect filter changes
        if (_getCurrentWidgetSettings != null) {
          final settings = _getCurrentWidgetSettings!();
          await _controller.refresh(
            cardsToLearn: settings['cardsToLearn'] as int,
            cardMode: settings['cardMode'] as String,
          );
        } else {
          await _controller.refresh();
        }
        // Also reload Leitner distribution when filters change (with updated filters)
        await _loadLeitnerDistribution();
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
              onFinish: _handleFinishLesson,
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
              cardMode: _controller.cardMode,
              onCardsToLearnChanged: _controller.setCardsToLearn,
              onFilterPressed: _showFilterSheet,
              onSettingsChanged: (cardsToLearn, cardMode) async {
                await _controller.refresh(
                  cardsToLearn: cardsToLearn,
                  cardMode: cardMode,
                );
              },
              onGenerateAndStartLesson: (cardsToLearn, cardMode) async {
                await _controller.generateWorkout(
                  cardsToLearn: cardsToLearn,
                  cardMode: cardMode,
                );
                _controller.startLesson();
              },
              onGetCurrentSettingsReady: (getCurrentSettings) {
                _getCurrentWidgetSettings = getCurrentSettings;
              },
              leitnerDistribution: _leitnerDistribution,
              languages: _languages,
              userId: _controller.currentUser?.id,
              onRefreshLeitner: () => _loadLeitnerDistribution(),
              isLoadingLeitner: _isLoadingLeitner,
              maxBins: _controller.currentUser?.leitnerMaxBins,
              algorithm: _controller.currentUser?.leitnerAlgorithm,
              intervalStartHours: _controller.currentUser?.leitnerIntervalStart,
              onConfigUpdated: _handleConfigUpdated,
            ),
          );
        },
      ),
    );
  }
}
