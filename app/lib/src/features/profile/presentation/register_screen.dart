import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:archipelago/src/features/shared/providers/languages_provider.dart';
import 'package:archipelago/src/common_widgets/language_button.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onRegisterSuccess;

  const RegisterScreen({
    super.key,
    this.onRegisterSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isLoading = false;
  List<Language> _languages = [];
  Language? _selectedLanguage;
  Language? _selectedLearningLanguage;

  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    _loadLanguages(languagesProvider);
    languagesProvider.addListener(_onLanguagesChanged);
  }
  
  void _onLanguagesChanged() {
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    _loadLanguages(languagesProvider);
  }

  void _loadLanguages(LanguagesProvider languagesProvider) {
    final languages = languagesProvider.languages;
    setState(() {
      _languages = languages;
      if (languages.isNotEmpty && _selectedLanguage == null) {
        _selectedLanguage = languages.first;
      }
    });
  }
  

  Future<void> _handleRegister() async {
    final username = _registerUsernameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (_selectedLanguage == null) {
      _showError('Please select a native language');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.register(
      username,
      email,
      password,
      _selectedLanguage!.code,
      _selectedLearningLanguage?.code,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      widget.onRegisterSuccess?.call();
      Navigator.of(context).pop();
      _showSuccess(result['message'] as String);
    } else {
      _showError(result['message'] as String);
    }
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


  void _fillTestRegisterData(int userNumber) {
    final testUsers = [
      {
        'username': 'dezwier',
        'email': 'dezwier@example.com',
        'password': 'password123',
        'language': 'en',
      },
      {
        'username': 'testuser2',
        'email': 'testuser2@example.com',
        'password': 'password123',
        'language': 'fr',
      },
      {
        'username': 'testuser3',
        'email': 'testuser3@example.com',
        'password': 'password123',
        'language': 'es',
      },
    ];

    if (userNumber >= 1 && userNumber <= 3) {
      final user = testUsers[userNumber - 1];
      // Set language
      final langCode = user['language']!;
      final language = _languages.firstWhere(
        (lang) => lang.code == langCode,
        orElse: () => _languages.isNotEmpty
            ? _languages.first
            : Language(code: 'en', name: 'English'),
      );
      // Use value setter which is more explicit and persists across rebuilds
      final username = user['username']!;
      final email = user['email']!;
      final password = user['password']!;
      _registerUsernameController.value = TextEditingValue(
        text: username,
        selection: TextSelection.collapsed(offset: username.length),
      );
      _registerEmailController.value = TextEditingValue(
        text: email,
        selection: TextSelection.collapsed(offset: email.length),
      );
      _registerPasswordController.value = TextEditingValue(
        text: password,
        selection: TextSelection.collapsed(offset: password.length),
      );
      // Update language in setState since it affects the dropdown
      setState(() {
        _selectedLanguage = language;
      });
    }
  }

  @override
  void dispose() {
    final languagesProvider = Provider.of<LanguagesProvider>(context, listen: false);
    languagesProvider.removeListener(_onLanguagesChanged);
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Create Account'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Form Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildRegisterForm(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _registerUsernameController,
          decoration: InputDecoration(
            labelText: 'Username',
            hintText: 'Choose a username',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          enabled: !_isLoading,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _registerEmailController,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email address',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(
              Icons.email_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _registerPasswordController,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Create a password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          obscureText: true,
          enabled: !_isLoading,
          style: Theme.of(context).textTheme.bodyLarge,
          onSubmitted: (_) => _handleRegister(),
        ),
        const SizedBox(height: 16),
        // Native Language
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Native Language',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Language buttons grid - 2 per row
            Column(
              children: [
                for (int i = 0; i < _languages.length; i += 2)
                  Padding(
                    padding: EdgeInsets.only(bottom: i + 2 < _languages.length ? 0 : 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: LanguageButton(
                            language: _languages[i],
                            isSelected: _languages[i].code == _selectedLanguage?.code,
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _selectedLanguage = _languages[i];
                                      // Clear learning language if it's the same as native
                                      if (_selectedLearningLanguage?.code == _languages[i].code) {
                                        _selectedLearningLanguage = null;
                                      }
                                    });
                                  },
                          ),
                        ),
                        if (i + 1 < _languages.length) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: LanguageButton(
                              language: _languages[i + 1],
                              isSelected: _languages[i + 1].code == _selectedLanguage?.code,
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedLanguage = _languages[i + 1];
                                        // Clear learning language if it's the same as native
                                        if (_selectedLearningLanguage?.code == _languages[i + 1].code) {
                                          _selectedLearningLanguage = null;
                                        }
                                      });
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
        const SizedBox(height: 16),
        // Learning Language
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learning Language',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Language buttons grid - 2 per row
            Column(
              children: [
                for (int i = 0; i < _languages.length; i += 2)
                  Padding(
                    padding: EdgeInsets.only(bottom: i + 2 < _languages.length ? 4 : 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: LanguageButton(
                            language: _languages[i],
                            isSelected: _languages[i].code == _selectedLearningLanguage?.code,
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _selectedLearningLanguage = _languages[i].code == _selectedLearningLanguage?.code
                                          ? null
                                          : _languages[i];
                                    });
                                  },
                          ),
                        ),
                        if (i + 1 < _languages.length) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: LanguageButton(
                              language: _languages[i + 1],
                              isSelected: _languages[i + 1].code == _selectedLearningLanguage?.code,
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedLearningLanguage = _languages[i + 1].code == _selectedLearningLanguage?.code
                                            ? null
                                            : _languages[i + 1];
                                      });
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
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
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
                    'Create Account',
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
                onPressed: _isLoading ? null : () => _fillTestRegisterData(1),
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
                onPressed: _isLoading ? null : () => _fillTestRegisterData(2),
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
                onPressed: _isLoading ? null : () => _fillTestRegisterData(3),
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

