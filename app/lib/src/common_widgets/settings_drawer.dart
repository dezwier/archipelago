import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:archipelago/src/features/shared/providers/languages_provider.dart';
import 'package:archipelago/src/common_widgets/language_button.dart';

class SettingsDrawer extends StatefulWidget {
  final bool isLoggedIn;
  final bool isDarkMode;
  final Function(bool) onDarkModeChanged;

  const SettingsDrawer({
    super.key,
    required this.isLoggedIn,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
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

  @override
  Widget build(BuildContext context) {
    // Fixed colors for top bars - same in light and dark theme
    const topBarColor = Color(0xFF1E3A5F);
    const topBarTextColor = Colors.white;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    return Drawer(
      key: ValueKey('drawer_${widget.isLoggedIn}'),
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
                  if (widget.isLoggedIn && currentUser != null)
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
                          value: widget.isDarkMode,
                          onChanged: widget.onDarkModeChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Logout button - only show when logged in
                  if (widget.isLoggedIn)
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
    );
  }
}

