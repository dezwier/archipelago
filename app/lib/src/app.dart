import 'package:flutter/material.dart';
import 'features/generate_flashcards/presentation/generate_flashcards_screen.dart';
import 'features/practice_flashcards/presentation/practice_flashcards_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'common_widgets/top_app_bar.dart';

class ArchipelagoApp extends StatefulWidget {
  const ArchipelagoApp({super.key});

  @override
  State<ArchipelagoApp> createState() => _ArchipelagoAppState();
}

class _ArchipelagoAppState extends State<ArchipelagoApp> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GenerateFlashcardsScreen(),
    const PracticeFlashcardsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archipelago',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: const TopAppBar(),
        body: _screens[_currentIndex],
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
              label: 'Generate',
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
      ),
    );
  }
}

