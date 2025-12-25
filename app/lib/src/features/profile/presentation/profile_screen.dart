import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:archipelago/src/features/profile/data/statistics_service.dart';
import 'package:archipelago/src/features/shared/domain/topic.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/providers/topics_provider.dart';
import 'package:archipelago/src/features/shared/providers/languages_provider.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/presentation/widgets/exercises_daily_chart_card.dart';
import 'package:archipelago/src/features/profile/presentation/profile_filter_state.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/constants/api_config.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'register_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  List<Language> _languages = [];

  // Statistics state
  SummaryStats? _summaryStats;
  LeitnerDistribution? _leitnerDistribution;
  PracticeDaily? _practiceDaily;
  String _practiceMetricType = 'exercises';
  bool _isLoadingStats = false;
  bool _isRefreshingStats = false;
  String? _statsError;

  // Filter state
  final _filterState = ProfileFilterState();
  List<Topic> _topics = [];
  bool _isLoadingTopics = false;

  // Login form controllers
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    
    // Load languages and topics from providers
    _loadLanguages(languagesProvider);
    _loadTopics(topicsProvider);
    
    // Listen to provider changes
    topicsProvider.addListener(_onTopicsChanged);
    languagesProvider.addListener(_onLanguagesChanged);
    
    // Listen to auth provider changes
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.addListener(_onAuthChanged);
    
    // Load statistics if user is already logged in
    if (authProvider.isLoggedIn) {
      _loadStatistics();
    }
  }
  
  void _onAuthChanged() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      _loadTopics(topicsProvider);
      _loadStatistics();
    } else {
      // Clear statistics when logged out
      setState(() {
        _summaryStats = null;
        _leitnerDistribution = null;
        _practiceDaily = null;
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
  
  @override
  void dispose() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    authProvider.removeListener(_onAuthChanged);
    topicsProvider.removeListener(_onTopicsChanged);
    languagesProvider.removeListener(_onLanguagesChanged);
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _loadTopics(TopicsProvider topicsProvider) {
    setState(() {
      _isLoadingTopics = topicsProvider.isLoading;
      _topics = topicsProvider.topics;
      // Set all topics as selected by default if nothing is selected
      if (_topics.isNotEmpty && _filterState.selectedTopicIds.isEmpty) {
        final topicIds = _topics.map((t) => t.id).toSet();
        _filterState.updateFilters(topicIds: topicIds);
        // Reload statistics after initializing topics
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentUser != null) {
          _loadStatistics();
        }
      }
    });
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    showFilterSheet(
      context: context,
      filterState: _filterState,
      availableBins: _getAvailableBins(),
      userId: authProvider.currentUser?.id,
      maxBins: authProvider.currentUser?.leitnerMaxBins ?? 7,
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
      }) {
        // Update filter state
        _filterState.updateFilters(
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
        // Reload statistics with new filters
        _loadStatistics();
      },
      topics: _topics,
      isLoadingTopics: _isLoadingTopics,
    );
  }

  void _loadLanguages(LanguagesProvider languagesProvider) {
    setState(() {
      _languages = languagesProvider.languages;
    });
  }



  Future<void> _handleLogin() async {
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.login(username, password);

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      _showSuccess(result['message'] as String);
      // Load topics and statistics after successful login
      final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
      _loadTopics(topicsProvider);
      _loadStatistics();
    } else {
      _showError(result['message'] as String);
    }
  }

  void _showRegisterScreen() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return RegisterScreen(
          onRegisterSuccess: () {
            // User is already saved by AuthProvider
            // Topics and statistics will be loaded via _onAuthChanged
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SlideTransition(
              position: animation.drive(tween),
              child: child,
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Get the full image URL from a relative path
  String _getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    } else {
      // Otherwise, prepend the API base URL
      final cleanUrl = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
      return '${ApiConfig.baseUrl}/$cleanUrl';
    }
  }

  /// Pick image from gallery and upload
  Future<void> _pickProfileImage() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null || _isUploadingImage) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        // User cancelled
        return;
      }

      setState(() {
        _isUploadingImage = true;
      });

      final result = await authProvider.uploadProfileImage(File(image.path));

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _isUploadingImage = false;
        });
        _showSuccess(result['message'] as String? ?? 'Profile image uploaded successfully');
      } else {
        setState(() {
          _isUploadingImage = false;
        });
        _showError(result['message'] as String? ?? 'Failed to upload profile image');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    if (!mounted) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _loginUsernameController.clear();
    _loginPasswordController.clear();
    await authProvider.logout();
  }

  void _fillTestLoginData(int userNumber) {
    final testUsers = [
      {'username': 'dezwier', 'password': 'password123'},
      {'username': 'testuser2', 'password': 'password123'},
      {'username': 'testuser3', 'password': 'password123'},
    ];

    if (userNumber >= 1 && userNumber <= 3) {
      final user = testUsers[userNumber - 1];
      // Use value setter which is more explicit and persists across rebuilds (same as register screen)
      final username = user['username']!;
      final password = user['password']!;
      _loginUsernameController.value = TextEditingValue(
        text: username,
        selection: TextSelection.collapsed(offset: username.length),
      );
      _loginPasswordController.value = TextEditingValue(
        text: password,
        selection: TextSelection.collapsed(offset: password.length),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while initializing
        if (authProvider.isInitializing) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // If user is logged in, show profile
        if (authProvider.isLoggedIn) {
          return _buildProfileView(authProvider);
        }

        // Otherwise show login/register
        return _buildAuthView();
      },
    );
  }

  Future<void> _refreshProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Refresh user data from API if logged in
    if (authProvider.currentUser != null) {
      try {
        // Use update-languages endpoint to get fresh user data (it returns full user object)
        await authProvider.updateUserLanguages(
          null, // Don't change native language
          null, // Don't change learning language
        );
      } catch (e) {
        // If refresh fails, just continue
      }
    }
    
    final topicsProvider = Provider.of<TopicsProvider>(context, listen: false);
    _loadTopics(topicsProvider);
    await _loadStatistics(isRefresh: true);
  }

  Widget _buildProfileView(AuthProvider authProvider) {
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return _buildAuthView();
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _isUploadingImage ? null : _pickProfileImage,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: _isUploadingImage
                              ? Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                )
                              : currentUser.imageUrl != null && currentUser.imageUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        _getImageUrl(currentUser.imageUrl!),
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.person,
                                            size: 48,
                                            color: Theme.of(context).colorScheme.primary,
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            width: 48,
                                            height: 48,
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                        loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser.fullName ?? currentUser.username,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '@${currentUser.username}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  LanguageEmoji.getEmoji(currentUser.langNative),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  // Summary statistics
                  if (_isLoadingStats && !_isRefreshingStats && _summaryStats == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_statsError != null && !_isRefreshingStats && _summaryStats == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Error loading statistics',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statsError!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadStatistics,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (_summaryStats != null)
                    _buildSummaryStatistics(_summaryStats!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Statistics cards
          if (_isLoadingStats && !_isRefreshingStats && _practiceDaily == null && (_leitnerDistribution == null || currentUser?.langLearning == null))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_statsError != null && !_isRefreshingStats && _practiceDaily == null && (_leitnerDistribution == null || currentUser?.langLearning == null))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Error loading statistics',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statsError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadStatistics,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            ExercisesDailyChartCard(
              key: ValueKey('practice-daily-${_practiceMetricType}'),
              practiceDaily: _practiceDaily,
              languages: _languages,
              initialMetricType: _practiceMetricType,
              onMetricTypeChanged: (String newMetricType) {
                setState(() {
                  _practiceMetricType = newMetricType;
                });
                _loadPracticeDaily();
              },
            ),
          ],
        ],
      ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'profile_filter_fab',
        onPressed: _showFilterSheet,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        child: const Icon(Icons.filter_list),
        tooltip: 'Filter',
      ),
    );
  }

  Widget _buildSummaryStatistics(SummaryStats stats) {
    if (stats.languageStats.isEmpty) {
      return Text(
        'No learning data available',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...stats.languageStats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final isLast = index == stats.languageStats.length - 1;
          final emoji = LanguageEmoji.getEmoji(stat.languageCode);
          final minutes = (stat.totalTimeSeconds / 60).round();
          final timeValue = minutes >= 60 
              ? '${(minutes / 60).round()}'
              : minutes.toString();
          final timeLabel = minutes >= 60 ? 'Hours' : 'Minutes';
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 0.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 0, bottom: 12),
                          child: Text(
                            emoji,
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildInlineStatItem(
                        value: stat.lemmaCount.toString(),
                        label: 'Lemmas',
                      ),
                    ),
                    Expanded(
                      child: _buildInlineStatItem(
                        value: stat.lessonCount.toString(),
                        label: 'Lessons',
                      ),
                    ),
                    Expanded(
                      child: _buildInlineStatItem(
                        value: stat.exerciseCount.toString(),
                        label: 'Exercises',
                      ),
                    ),
                    Expanded(
                      child: _buildInlineStatItem(
                        value: timeValue,
                        label: timeLabel,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  ),
                ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInlineStatItem({required String value, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
      ],
    );
  }


  Future<void> _loadStatistics({bool isRefresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    setState(() {
      if (isRefresh) {
        _isRefreshingStats = true;
      } else {
        _isLoadingStats = true;
      }
      _statsError = null;
    });

    try {
      // Get maxBins from user
      final maxBins = currentUser.leitnerMaxBins;

      // Load summary stats with current filter state
      final summaryResult = await StatisticsService.getLanguageSummaryStats(
        userId: currentUser.id,
        includeLemmas: _filterState.includeLemmas,
        includePhrases: _filterState.includePhrases,
        topicIds: _filterState.topicIdsParam,
        includeWithoutTopic: _filterState.showLemmasWithoutTopic,
        levels: _filterState.levelsParam,
        partOfSpeech: _filterState.partOfSpeechParam,
        hasImages: _filterState.hasImagesParam,
        hasAudio: _filterState.hasAudioParam,
        isComplete: _filterState.isCompleteParam,
        leitnerBins: _filterState.getLeitnerBinsParam(maxBins),
        learningStatus: _filterState.getLearningStatusParam(),
      );

      // Load Leitner distribution for learning language
      LeitnerDistribution? leitnerDist;
      if (currentUser.langLearning != null && currentUser.langLearning!.isNotEmpty) {
        final leitnerResult = await StatisticsService.getLeitnerDistribution(
          userId: currentUser.id,
          languageCode: currentUser.langLearning!,
          includeLemmas: _filterState.includeLemmas,
          includePhrases: _filterState.includePhrases,
          topicIds: _filterState.topicIdsParam,
          includeWithoutTopic: _filterState.showLemmasWithoutTopic,
          levels: _filterState.levelsParam,
          partOfSpeech: _filterState.partOfSpeechParam,
          hasImages: _filterState.hasImagesParam,
          hasAudio: _filterState.hasAudioParam,
          isComplete: _filterState.isCompleteParam,
          leitnerBins: _filterState.getLeitnerBinsParam(maxBins),
          learningStatus: _filterState.getLearningStatusParam(),
        );

        if (leitnerResult['success'] == true) {
          leitnerDist = leitnerResult['data'] as LeitnerDistribution;
        }
      }

      // Load practice daily data
      final practiceDailyResult = await StatisticsService.getPracticeDaily(
        userId: currentUser.id,
        metricType: _practiceMetricType,
        includeLemmas: _filterState.includeLemmas,
        includePhrases: _filterState.includePhrases,
        topicIds: _filterState.topicIdsParam,
        includeWithoutTopic: _filterState.showLemmasWithoutTopic,
        levels: _filterState.levelsParam,
        partOfSpeech: _filterState.partOfSpeechParam,
        hasImages: _filterState.hasImagesParam,
        hasAudio: _filterState.hasAudioParam,
        isComplete: _filterState.isCompleteParam,
        leitnerBins: _filterState.getLeitnerBinsParam(maxBins),
        learningStatus: _filterState.getLearningStatusParam(),
      );

      PracticeDaily? practiceDaily;
      if (practiceDailyResult['success'] == true) {
        practiceDaily = practiceDailyResult['data'] as PracticeDaily;
      }

      if (mounted) {
        setState(() {
          if (summaryResult['success'] == true) {
            _summaryStats = summaryResult['data'] as SummaryStats;
          } else {
            _statsError = summaryResult['message'] as String? ?? 'Failed to load statistics';
          }
          _leitnerDistribution = leitnerDist;
          _practiceDaily = practiceDaily;
          _isLoadingStats = false;
          _isRefreshingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsError = 'Error loading statistics: ${e.toString()}';
          _isLoadingStats = false;
          _isRefreshingStats = false;
        });
      }
    }
  }

  Future<void> _loadPracticeDaily() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    try {
      // Load only practice daily data
      final practiceDailyResult = await StatisticsService.getPracticeDaily(
        userId: currentUser.id,
        metricType: _practiceMetricType,
        includeLemmas: _filterState.includeLemmas,
        includePhrases: _filterState.includePhrases,
        topicIds: _filterState.topicIdsParam,
        includeWithoutTopic: _filterState.showLemmasWithoutTopic,
        levels: _filterState.levelsParam,
        partOfSpeech: _filterState.partOfSpeechParam,
        hasImages: _filterState.hasImagesParam,
        hasAudio: _filterState.hasAudioParam,
        isComplete: _filterState.isCompleteParam,
      );

      PracticeDaily? practiceDaily;
      if (practiceDailyResult['success'] == true) {
        practiceDaily = practiceDailyResult['data'] as PracticeDaily;
      }

      if (mounted) {
        setState(() {
          _practiceDaily = practiceDaily;
        });
      }
    } catch (e) {
      // Silently fail - don't show error for chart refresh
      if (mounted) {
        setState(() {
          // Keep existing data on error
        });
      }
    }
  }

  Widget _buildAuthView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Logo/Icon section
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline,
                size: 40,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              'Welcome Back',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to continue your learning journey',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Form Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildLoginForm(),
              ),
            ),
            const SizedBox(height: 20),
            // Register button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Don\'t have an account? ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _showRegisterScreen,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Register',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginUsernameController,
          decoration: InputDecoration(
            labelText: 'Username or Email',
            hintText: 'Enter your username or email',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          enabled: !_isLoading,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPasswordController,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          obscureText: true,
          enabled: !_isLoading,
          style: Theme.of(context).textTheme.bodyLarge,
          onSubmitted: (_) => _handleLogin(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(
                    'Sign In',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Dev test user buttons
        Text(
          'Test users for development',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _fillTestLoginData(1),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Test 1',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _fillTestLoginData(2),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Test 2',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _fillTestLoginData(3),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Test 3',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
