import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:archipelago/src/features/profile/data/auth_service.dart';
import 'package:archipelago/src/features/profile/data/language_service.dart';
import 'package:archipelago/src/features/profile/data/statistics_service.dart';
import 'package:archipelago/src/features/create/data/topic_service.dart';
import 'package:archipelago/src/features/create/domain/topic.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/presentation/widgets/language_summary_card.dart';
import 'package:archipelago/src/features/profile/presentation/widgets/leitner_distribution_card.dart';
import 'package:archipelago/src/features/profile/presentation/widgets/exercises_daily_chart_card.dart';
import 'package:archipelago/src/features/profile/presentation/profile_filter_state.dart';
import 'package:archipelago/src/common_widgets/filter_sheet.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'register_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final Function(Future<void> Function())? onLogoutCallbackReady;
  final Function(bool)? onLoginStateChanged;
  final Function(Function())? onRefreshCallbackReady;
  
  const ProfileScreen({
    super.key, 
    this.onLogout, 
    this.onLogoutCallbackReady,
    this.onLoginStateChanged,
    this.onRefreshCallbackReady,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  bool _isInitializing = true; // Track if we're still loading saved user
  User? _currentUser;
  List<Language> _languages = [];

  // Statistics state
  SummaryStats? _summaryStats;
  LeitnerDistribution? _leitnerDistribution;
  ExercisesDaily? _exercisesDaily;
  bool _isLoadingStats = false;
  String? _statsError;

  // Filter state
  final _filterState = ProfileFilterState();
  List<Topic> _topics = [];
  bool _isLoadingTopics = false;

  // Login form controllers
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load saved user data
    _loadSavedUser();
    // Load languages
    _loadLanguages();
    // Load topics
    _loadTopics();
    // Register logout callback with parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLogoutCallbackReady?.call(logout);
      widget.onRefreshCallbackReady?.call(() {
        _loadSavedUser(force: true);
        _loadTopics();
        _loadStatistics();
      });
    });
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoadingTopics = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      int? userId;
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = User.fromJson(userMap);
        userId = user.id;
      }

      final topics = await TopicService.getTopics(userId: userId);

      if (mounted) {
        setState(() {
          _topics = topics;
          _isLoadingTopics = false;
          // Set all topics as selected by default if nothing is selected
          if (topics.isNotEmpty && _filterState.selectedTopicIds.isEmpty) {
            final topicIds = topics.map((t) => t.id).toSet();
            _filterState.updateFilters(topicIds: topicIds);
            // Reload statistics after initializing topics
            if (_currentUser != null) {
              _loadStatistics();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTopics = false;
        });
      }
    }
  }

  void _showFilterSheet() {
    showFilterSheet(
      context: context,
      filterState: _filterState,
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
        );
        // Reload statistics with new filters
        _loadStatistics();
      },
      topics: _topics,
      isLoadingTopics: _isLoadingTopics,
    );
  }

  Future<void> _loadLanguages() async {
    final languages = await LanguageService.getLanguages();
    setState(() {
      _languages = languages;
    });
  }

  String _getLanguageName(String code) {
    final language = _languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Language(code: code, name: code.toUpperCase()),
    );
    return language.name;
  }

  Future<void> _loadSavedUser({bool force = false}) async {
    // Don't reload if user is already loaded (unless forced)
    if (_currentUser != null && !_isInitializing && !force) {
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentUser = User.fromJson(userMap);
            _isInitializing = false;
          });
          widget.onLoginStateChanged?.call(true);
          // Load statistics when user is loaded
          _loadStatistics();
        }
      } else {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
          widget.onLoginStateChanged?.call(false);
        }
      }
    } catch (e) {
      // If loading fails, just continue without user
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));
    } catch (e) {
      // If saving fails, continue anyway
    }
  }

  Future<void> _clearSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
    } catch (e) {
      // If clearing fails, continue anyway
    }
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

    final result = await AuthService.login(username, password);

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      final user = result['user'] as User;
      setState(() {
        _currentUser = user;
      });
      await _saveUser(user);
      widget.onLoginStateChanged?.call(true);
      // Load topics and statistics after successful login
      _loadTopics();
      _loadStatistics();
      _showSuccess(result['message'] as String);
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
          onRegisterSuccess: (user) async {
            setState(() {
              _currentUser = user;
            });
            await _saveUser(user);
            widget.onLoginStateChanged?.call(true);
            // Load topics and statistics after successful registration
            _loadTopics();
            _loadStatistics();
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

  Future<void> logout() async {
    if (!mounted) return;
    
    setState(() {
      _currentUser = null;
      _loginUsernameController.clear();
      _loginPasswordController.clear();
    });
    await _clearSavedUser();
    widget.onLoginStateChanged?.call(false);
    
    if (mounted) {
      widget.onLogout?.call();
    }
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
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking for saved user
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // If user is logged in, show profile
    if (_currentUser != null) {
      return _buildProfileView();
    }

    // Otherwise show login/register
    return _buildAuthView();
  }

  Widget _buildProfileView() {
    return Scaffold(
      body: SingleChildScrollView(
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
                      Icon(
                        Icons.person,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser!.username,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentUser!.email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildLanguageProfileItem('Native Language', _currentUser!.langNative),
                  if (_currentUser!.langLearning != null &&
                      _currentUser!.langLearning!.isNotEmpty)
                    _buildLanguageProfileItem(
                        'Learning Language', _currentUser!.langLearning!),
                  _buildProfileItem('Member since',
                      _formatDate(_currentUser!.createdAt)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Statistics cards
          if (_isLoadingStats)
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
          else if (_statsError != null)
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
            if (_summaryStats != null)
              LanguageSummaryCard(
                stats: _summaryStats!,
                languages: _languages,
              ),
            const SizedBox(height: 16),
            if (_exercisesDaily != null)
              ExercisesDailyChartCard(
                exercisesDaily: _exercisesDaily!,
                languages: _languages,
              ),
            const SizedBox(height: 16),
            if (_leitnerDistribution != null && _currentUser!.langLearning != null)
              LeitnerDistributionCard(
                distribution: _leitnerDistribution!,
                languages: _languages,
              ),
          ],
        ],
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

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageProfileItem(String label, String languageCode) {
    final languageName = _getLanguageName(languageCode);
    final emoji = LanguageEmoji.getEmoji(languageCode);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  emoji,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  languageName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> _loadStatistics() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoadingStats = true;
      _statsError = null;
    });

    try {
      // Load summary stats with current filter state
      final summaryResult = await StatisticsService.getLanguageSummaryStats(
        userId: _currentUser!.id,
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

      // Load Leitner distribution for learning language
      LeitnerDistribution? leitnerDist;
      if (_currentUser!.langLearning != null && _currentUser!.langLearning!.isNotEmpty) {
        final leitnerResult = await StatisticsService.getLeitnerDistribution(
          userId: _currentUser!.id,
          languageCode: _currentUser!.langLearning!,
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

        if (leitnerResult['success'] == true) {
          leitnerDist = leitnerResult['data'] as LeitnerDistribution;
        }
      }

      // Load exercises daily data
      final exercisesDailyResult = await StatisticsService.getExercisesDaily(
        userId: _currentUser!.id,
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

      ExercisesDaily? exercisesDaily;
      if (exercisesDailyResult['success'] == true) {
        exercisesDaily = exercisesDailyResult['data'] as ExercisesDaily;
      }

      if (mounted) {
        setState(() {
          if (summaryResult['success'] == true) {
            _summaryStats = summaryResult['data'] as SummaryStats;
          } else {
            _statsError = summaryResult['message'] as String? ?? 'Failed to load statistics';
          }
          _leitnerDistribution = leitnerDist;
          _exercisesDaily = exercisesDaily;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statsError = 'Error loading statistics: ${e.toString()}';
          _isLoadingStats = false;
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
