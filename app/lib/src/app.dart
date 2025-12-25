import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/create/presentation/screens/create_screen.dart';
import 'features/learn/presentation/screens/learn_screen.dart';
import 'features/dictionary/presentation/screens/dictionary_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/shared/providers/auth_provider.dart';
import 'common_widgets/top_app_bar.dart';
import 'common_widgets/settings_drawer.dart';

class ArchipelagoApp extends StatefulWidget {
  const ArchipelagoApp({super.key});

  @override
  State<ArchipelagoApp> createState() => _ArchipelagoAppState();
}

class _ArchipelagoAppState extends State<ArchipelagoApp> {
  int _currentIndex = 0;
  late final List<Widget> _screens;
  bool _isDarkMode = false;

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
          // Determine title based on current screen
          final List<String> screenTitles = ['Create', 'Dictionary', 'Learn', 'Profile'];
          final currentTitle = screenTitles[_currentIndex];
          final isLoggedIn = authProvider.isLoggedIn;
          
          return Scaffold(
            appBar: TopAppBar(title: currentTitle),
            drawer: SettingsDrawer(
              isLoggedIn: isLoggedIn,
              isDarkMode: _isDarkMode,
              onDarkModeChanged: _toggleDarkMode,
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
