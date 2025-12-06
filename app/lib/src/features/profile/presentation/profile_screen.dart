import 'package:flutter/material.dart';
import '../data/auth_service.dart';
import '../data/language_service.dart';
import '../domain/user.dart';
import '../domain/language.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoginMode = true;
  bool _isLoading = false;
  User? _currentUser;
  List<Language> _languages = [];
  Language? _selectedLanguage;

  // Login form controllers
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register form controllers
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final languages = await LanguageService.getLanguages();
    setState(() {
      _languages = languages;
      if (languages.isNotEmpty) {
        _selectedLanguage = languages.first;
      }
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

    final result = await AuthService.login(username, password);

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        _currentUser = result['user'] as User;
        _isLoginMode = false; // Switch to profile view
      });
      _showSuccess(result['message'] as String);
    } else {
      _showError(result['message'] as String);
    }
  }

  Future<void> _handleRegister() async {
    final username = _registerUsernameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;
    final confirmPassword = _registerConfirmPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match');
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

    final result = await AuthService.register(
      username,
      email,
      password,
      _selectedLanguage!.code,
    );

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      setState(() {
        _currentUser = result['user'] as User;
        _isLoginMode = false; // Switch to profile view
      });
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

  void _logout() {
    setState(() {
      _currentUser = null;
      _isLoginMode = true;
      _loginUsernameController.clear();
      _loginPasswordController.clear();
      _registerUsernameController.clear();
      _registerEmailController.clear();
      _registerPasswordController.clear();
      _registerConfirmPasswordController.clear();
    });
  }

  void _fillTestLoginData(int userNumber) {
    final testUsers = [
      {'username': 'testuser1', 'password': 'password123'},
      {'username': 'testuser2', 'password': 'password123'},
      {'username': 'testuser3', 'password': 'password123'},
    ];
    
    if (userNumber >= 1 && userNumber <= 3) {
      final user = testUsers[userNumber - 1];
      _loginUsernameController.text = user['username']!;
      _loginPasswordController.text = user['password']!;
    }
  }

  void _fillTestRegisterData(int userNumber) {
    final testUsers = [
      {
        'username': 'testuser1_new',
        'email': 'testuser1@example.com',
        'password': 'password123',
        'language': 'en',
      },
      {
        'username': 'testuser2_new',
        'email': 'testuser2@example.com',
        'password': 'password123',
        'language': 'fr',
      },
      {
        'username': 'testuser3_new',
        'email': 'testuser3@example.com',
        'password': 'password123',
        'language': 'es',
      },
    ];
    
    if (userNumber >= 1 && userNumber <= 3) {
      final user = testUsers[userNumber - 1];
      _registerUsernameController.text = user['username']!;
      _registerEmailController.text = user['email']!;
      _registerPasswordController.text = user['password']!;
      _registerConfirmPasswordController.text = user['password']!;
      
      // Set language
      final langCode = user['language']!;
      final language = _languages.firstWhere(
        (lang) => lang.code == langCode,
        orElse: () => _languages.isNotEmpty ? _languages.first : Language(code: 'en', name: 'English'),
      );
      setState(() {
        _selectedLanguage = language;
      });
    }
  }

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If user is logged in, show profile
    if (_currentUser != null) {
      return _buildProfileView();
    }

    // Otherwise show login/register
    return _buildAuthView();
  }

  Widget _buildProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
          const SizedBox(height: 32),
          Card(
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
                  _buildProfileItem('Native Language', _currentUser!.langNative),
                  if (_currentUser!.langLearning != null &&
                      _currentUser!.langLearning!.isNotEmpty)
                    _buildProfileItem(
                        'Learning Language', _currentUser!.langLearning!),
                  _buildProfileItem('Member since',
                      _formatDate(_currentUser!.createdAt)),
                ],
              ),
            ),
          ),
        ],
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
            width: 120,
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

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
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
              _isLoginMode ? 'Welcome Back' : 'Create Account',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _isLoginMode
                  ? 'Sign in to continue your learning journey'
                  : 'Start learning languages today',
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
                child: _isLoginMode ? _buildLoginForm() : _buildRegisterForm(),
              ),
            ),
            const SizedBox(height: 20),
            // Toggle button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLoginMode
                      ? 'Don\'t have an account? '
                      : 'Already have an account? ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLoginMode = !_isLoginMode;
                          });
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isLoginMode ? 'Register' : 'Login',
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
          'Dev: Test Users',
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            helperText: 'Minimum 6 characters',
            helperMaxLines: 1,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          obscureText: true,
          enabled: !_isLoading,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _registerConfirmPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Re-enter your password',
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
          onSubmitted: (_) => _handleRegister(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Language>(
          value: _selectedLanguage,
          decoration: InputDecoration(
            labelText: 'Native Language',
            hintText: 'Select your native language',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: Icon(
              Icons.language_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: _languages.map((language) {
            return DropdownMenuItem<Language>(
              value: language,
              child: Text(
                language.name,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }).toList(),
          onChanged: _isLoading
              ? null
              : (Language? value) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                },
          style: Theme.of(context).textTheme.bodyLarge,
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
          'Dev: Test Users',
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
