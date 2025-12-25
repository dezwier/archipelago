import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/create/presentation/screens/create_screen.dart';
import 'features/learn/presentation/screens/learn_screen.dart';
import 'features/dictionary/presentation/screens/dictionary_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/shared/providers/auth_provider.dart';
import 'features/shared/providers/languages_provider.dart';
import 'common_widgets/top_app_bar.dart';
import 'common_widgets/language_button.dart';

class ArchipelagoApp extends StatefulWidget {
  const ArchipelagoApp({super.key});

  @override
  State<ArchipelagoApp> createState() => _ArchipelagoAppState();
}

class _ArchipelagoAppState extends State<ArchipelagoApp> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  bool _isDarkMode = false;
  bool _isDeletingData = false;

  @override
  void initState() {
    super.initState();
    // Cache screens so they persist across rebuilds - no callbacks needed
    _screens = [
      const GenerateFlashcardsScreen(),
      const DictionaryScreen(),
      const LearnScreen(),
      const ProfileScreen(key: ValueKey('profile_screen')),
    ];
    _loadThemePreference();
  }

  Future<void> _updateUserLanguage(String type, String? languageCode, AuthProvider authProvider) async {
    if (authProvider.currentUser == null) return;

    final result = await authProvider.updateUserLanguages(
      type == 'native' ? languageCode : null,
      type == 'learning' ? languageCode : null,
    );

    if (result['success'] != true) {
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

  Future<void> _handleLogout(AuthProvider authProvider) async {
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
    await authProvider.logout();
  }

  Future<void> _handleDeleteUserDataWithContext(BuildContext buttonContext, AuthProvider authProvider) async {
    if (authProvider.currentUser == null || !mounted) {
      return;
    }

    // Close drawer first
    try {
      if (Navigator.canPop(buttonContext)) {
        Navigator.of(buttonContext).pop();
        // Wait a bit for drawer to close
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      // Ignore if Navigator is not available
    }

    if (!mounted) return;

    setState(() {
      _isDeletingData = true;
    });

    try {
      final result = await authProvider.deleteUserData();

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingData = false;
        });
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
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          // Fixed colors for top bars - same in light and dark theme
          const topBarColor = Color(0xFF1E3A5F);
          const topBarTextColor = Colors.white;
          final surfaceColor = Theme.of(context).colorScheme.surface;
          
          // Determine title based on current screen
          final List<String> screenTitles = ['Create', 'Dictionary', 'Learn', 'Profile'];
          final currentTitle = screenTitles[_currentIndex];
          final isLoggedIn = authProvider.isLoggedIn;
          final currentUser = authProvider.currentUser;
          
          return Scaffold(
            appBar: TopAppBar(title: currentTitle),
            drawer: Drawer(
              key: ValueKey('drawer_$isLoggedIn'),
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
                          if (isLoggedIn && currentUser != null)
                            Consumer<LanguagesProvider>(
                              builder: (context, languagesProvider, _) {
                                final languages = languagesProvider.languages;
                                final isLoadingLanguages = languagesProvider.isLoading;
                                return Column(
                                  children: [
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
                                              for (int i = 0; i < languages.length; i += 2)
                                                Padding(
                                                  padding: EdgeInsets.only(bottom: i + 2 < languages.length ? 2 : 0),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: LanguageButton(
                                                          language: languages[i],
                                                          isSelected: languages[i].code == currentUser.langNative,
                                                          onPressed: isLoadingLanguages
                                                              ? null
                                                              : () {
                                                                  if (languages[i].code != currentUser.langNative) {
                                                                    _updateUserLanguage('native', languages[i].code, authProvider);
                                                                  }
                                                                },
                                                        ),
                                                      ),
                                                      if (i + 1 < languages.length) ...[
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: LanguageButton(
                                                            language: languages[i + 1],
                                                            isSelected: languages[i + 1].code == currentUser.langNative,
                                                            onPressed: isLoadingLanguages
                                                                ? null
                                                                : () {
                                                                    if (languages[i + 1].code != currentUser.langNative) {
                                                                      _updateUserLanguage('native', languages[i + 1].code, authProvider);
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
                                              for (int i = 0; i < languages.length; i += 2)
                                                Padding(
                                                  padding: EdgeInsets.only(bottom: i + 2 < languages.length ? 2 : 0),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: LanguageButton(
                                                          language: languages[i],
                                                          isSelected: languages[i].code == currentUser.langLearning,
                                                          onPressed: isLoadingLanguages
                                                              ? null
                                                              : () {
                                                                  _updateUserLanguage('learning', languages[i].code, authProvider);
                                                                },
                                                        ),
                                                      ),
                                                      if (i + 1 < languages.length) ...[
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: LanguageButton(
                                                            language: languages[i + 1],
                                                            isSelected: languages[i + 1].code == currentUser.langLearning,
                                                            onPressed: isLoadingLanguages
                                                                ? null
                                                                : () {
                                                                    _updateUserLanguage('learning', languages[i + 1].code, authProvider);
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
                                  ],
                                );
                              },
                            ),
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
                          if (isLoggedIn) ...[
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
                                      _handleLogout(authProvider);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Delete All Data button
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: Builder(
                                  builder: (buttonContext) {
                                    return OutlinedButton.icon(
                                      onPressed: _isDeletingData
                                          ? null
                                          : () {
                                              print('DEBUG: Button tapped');
                                              _handleDeleteUserDataWithContext(buttonContext, authProvider);
                                            },
                                      icon: _isDeletingData
                                          ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Theme.of(buttonContext).colorScheme.error,
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.delete_forever,
                                              color: Theme.of(buttonContext).colorScheme.error,
                                            ),
                                      label: Text(
                                        _isDeletingData ? 'Deleting...' : 'Delete All Data',
                                        style: TextStyle(
                                          color: Theme.of(buttonContext).colorScheme.error,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: Theme.of(buttonContext).colorScheme.error.withValues(alpha: 0.5),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    );
                                  },
                                ),
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
                  label: 'Learn',
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

