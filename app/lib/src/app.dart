import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'features/generate_flashcards/presentation/generate_flashcards_screen.dart';
import 'features/practice_flashcards/presentation/practice_flashcards_screen.dart';
import 'features/dictionary/presentation/screens/dictionary_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/profile/domain/user.dart';
import 'features/profile/domain/language.dart';
import 'features/profile/data/language_service.dart';
import 'features/profile/data/auth_service.dart';
import 'common_widgets/top_app_bar.dart';
import 'common_widgets/language_button.dart';

class ArchipelagoApp extends StatefulWidget {
  const ArchipelagoApp({super.key});

  @override
  State<ArchipelagoApp> createState() => _ArchipelagoAppState();
}

class _ArchipelagoAppState extends State<ArchipelagoApp> {
  int _currentIndex = 0;
  Future<void> Function()? _logoutCallback;
  Function()? _refreshProfileCallback;
  late final List<Widget> _screens;
  bool _isDarkMode = false;
  bool _isLoggedIn = false;
  User? _currentUser;
  List<Language> _languages = [];
  bool _isLoadingLanguages = false;

  @override
  void initState() {
    super.initState();
    // Cache screens so they persist across rebuilds
    _screens = [
      const GenerateFlashcardsScreen(),
      const DictionaryScreen(),
      const PracticeFlashcardsScreen(),
      ProfileScreen(
        key: const ValueKey('profile_screen'),
        onLogout: () {
          // Logout callback is handled by _handleLogout
        },
        onLogoutCallbackReady: (callback) {
          _logoutCallback = callback;
        },
        onLoginStateChanged: (isLoggedIn) {
          setState(() {
            _isLoggedIn = isLoggedIn;
          });
          if (isLoggedIn) {
            _loadCurrentUser();
          } else {
            setState(() {
              _currentUser = null;
            });
          }
        },
        onRefreshCallbackReady: (callback) {
          _refreshProfileCallback = callback;
        },
      ),
    ];
    _loadThemePreference();
    _checkLoginState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    setState(() {
      _isLoadingLanguages = true;
    });
    final languages = await LanguageService.getLanguages();
    setState(() {
      _languages = languages;
      _isLoadingLanguages = false;
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        setState(() {
          _currentUser = User.fromJson(userMap);
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }


  Future<void> _updateUserLanguage(String type, String? languageCode) async {
    if (_currentUser == null) return;

    setState(() {
      _isLoadingLanguages = true;
    });

    final result = await AuthService.updateUserLanguages(
      _currentUser!.id,
      type == 'native' ? languageCode : null,
      type == 'learning' ? languageCode : null,
    );

    setState(() {
      _isLoadingLanguages = false;
    });

    if (result['success'] == true) {
      final updatedUser = result['user'] as User;
      setState(() {
        _currentUser = updatedUser;
      });
      // Save updated user to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(updatedUser.toJson()));
      } catch (e) {
        // Ignore errors
      }
      // Notify ProfileScreen to refresh
      _refreshProfileCallback?.call();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      setState(() {
        _isLoggedIn = userJson != null;
      });
      if (_isLoggedIn) {
        await _loadCurrentUser();
      }
    } catch (e) {
      // If checking fails, assume not logged in
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }

  Future<void> _handleLogout() async {
    // Close drawer first to avoid context issues
    if (mounted) {
      try {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Close the drawer
        }
      } catch (e) {
        // Ignore if Navigator is not available
      }
    }
    
    // Then perform logout async operation
    if (_logoutCallback != null && mounted) {
      try {
        await _logoutCallback!();
        setState(() {
          _isLoggedIn = false;
        });
      } catch (e) {
        // Ignore errors during logout
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archipelago',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A5F)),
        useMaterial3: true,
      ),
      // Set app icon/logo
      // Note: For actual app icon, update platform-specific files (ios/Runner/Assets.xcassets, android/app/src/main/res, etc.)
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) {
          // Fixed colors for top bars - same in light and dark theme
          const topBarColor = Color(0xFF1E3A5F);
          const topBarTextColor = Colors.white;
          final surfaceColor = Theme.of(context).colorScheme.surface;
          
          // Determine title based on current screen
          final List<String> screenTitles = ['Create', 'Dictionary', 'Practice', 'Profile'];
          final currentTitle = screenTitles[_currentIndex];
          
          return Scaffold(
            appBar: TopAppBar(title: currentTitle),
            drawer: Drawer(
              key: ValueKey('drawer_$_isLoggedIn'),
              width: MediaQuery.of(context).size.width * 0.7,
              backgroundColor: Colors.transparent,
              child: Column(
                children: [
                  // Top section - dark blue (fixed color)
                  Container(
                    height: kToolbarHeight + MediaQuery.of(context).padding.top,
                    decoration: BoxDecoration(
                      color: topBarColor,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/translate_icon.png',
                                height: 32,
                                width: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  color: topBarTextColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Middle section - light
                  Expanded(
                    child: Container(
                      color: surfaceColor,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          const SizedBox(height: 22),
                          // Language settings - only show when logged in
                          if (_isLoggedIn && _currentUser != null) ...[
                            const SizedBox(height: 8),
                            // Native Language
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      Text(
                                        'Native Language',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Language buttons grid - 2 per row
                                  Column(
                                    children: [
                                      for (int i = 0; i < _languages.length; i += 2)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: i + 2 < _languages.length ? 2 : 0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: LanguageButton(
                                                  language: _languages[i],
                                                  isSelected: _languages[i].code == _currentUser!.langNative,
                                                  onPressed: _isLoadingLanguages
                                                      ? null
                                                      : () {
                                                          if (_languages[i].code != _currentUser!.langNative) {
                                                            _updateUserLanguage('native', _languages[i].code);
                                                          }
                                                        },
                                                ),
                                              ),
                                              if (i + 1 < _languages.length) ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: LanguageButton(
                                                    language: _languages[i + 1],
                                                    isSelected: _languages[i + 1].code == _currentUser!.langNative,
                                                    onPressed: _isLoadingLanguages
                                                        ? null
                                                        : () {
                                                            if (_languages[i + 1].code != _currentUser!.langNative) {
                                                              _updateUserLanguage('native', _languages[i + 1].code);
                                                            }
                                                          },
                                                  ),
                                                ),
                                              ] else
                                                const Spacer(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Learning Language
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      Text(
                                        'Learning Language',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Language buttons grid - 2 per row
                                  Column(
                                    children: [
                                      for (int i = 0; i < _languages.length; i += 2)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: i + 2 < _languages.length ? 2 : 0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: LanguageButton(
                                                  language: _languages[i],
                                                  isSelected: _languages[i].code == _currentUser!.langLearning,
                                                  onPressed: _isLoadingLanguages
                                                      ? null
                                                      : () {
                                                          _updateUserLanguage('learning', _languages[i].code);
                                                        },
                                                ),
                                              ),
                                              if (i + 1 < _languages.length) ...[
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: LanguageButton(
                                                    language: _languages[i + 1],
                                                    isSelected: _languages[i + 1].code == _currentUser!.langLearning,
                                                    onPressed: _isLoadingLanguages
                                                        ? null
                                                        : () {
                                                            _updateUserLanguage('learning', _languages[i + 1].code);
                                                          },
                                                  ),
                                                ),
                                              ] else
                                                const Spacer(),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Divider(height: 1),
                          ],
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  'Dark theme',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: _isDarkMode,
                                  onChanged: _toggleDarkMode,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Logout button - only show when logged in
                          if (_isLoggedIn) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    'Logout',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      Icons.logout,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    onPressed: () {
                                      _handleLogout();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Bottom section - matches scaffold background with separator line
                  Container(
                    color: surfaceColor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Thin separation line
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'v1.0.0',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Create',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Dictionary',
                ),
                NavigationDestination(
                  icon: Icon(Icons.school_outlined),
                  selectedIcon: Icon(Icons.school),
                  label: 'Practice',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

