import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archipelago/src/features/shared/domain/user.dart';
import 'package:archipelago/src/features/profile/data/auth_service.dart';

/// Global state provider for authentication and user data
class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;

  AuthProvider() {
    _loadSavedUser();
  }

  /// Load user from SharedPreferences
  Future<void> _loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userMap);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      _currentUser = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Save user to SharedPreferences
  Future<void> _saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toJson()));
    } catch (e) {
      // If saving fails, continue anyway
    }
  }

  /// Clear saved user from SharedPreferences
  Future<void> _clearSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
    } catch (e) {
      // If clearing fails, continue anyway
    }
  }

  /// Login with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.login(username, password);
      
      if (result['success'] == true) {
        final user = result['user'] as User;
        _currentUser = user;
        await _saveUser(user);
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error during login: ${e.toString()}',
      };
    }
  }

  /// Register a new user
  Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password,
    String nativeLanguage,
    String? learningLanguage,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.register(
        username,
        email,
        password,
        nativeLanguage,
        learningLanguage,
      );
      
      if (result['success'] == true) {
        final user = result['user'] as User;
        _currentUser = user;
        await _saveUser(user);
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error during registration: ${e.toString()}',
      };
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    _currentUser = null;
    await _clearSavedUser();
    notifyListeners();
  }

  /// Update user languages
  Future<Map<String, dynamic>> updateUserLanguages(
    String? langNative,
    String? langLearning,
  ) async {
    if (_currentUser == null) {
      return {
        'success': false,
        'message': 'No user logged in',
      };
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.updateUserLanguages(
        _currentUser!.id,
        langNative,
        langLearning,
      );
      
      if (result['success'] == true) {
        final user = result['user'] as User;
        _currentUser = user;
        await _saveUser(user);
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error updating languages: ${e.toString()}',
      };
    }
  }

  /// Update Leitner configuration
  Future<Map<String, dynamic>> updateLeitnerConfig({
    int? maxBins,
    String? algorithm,
    int? intervalStartHours,
  }) async {
    if (_currentUser == null) {
      return {
        'success': false,
        'message': 'No user logged in',
      };
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.updateLeitnerConfig(
        _currentUser!.id,
        maxBins,
        algorithm,
        intervalStartHours,
      );
      
      if (result['success'] == true) {
        final user = result['user'] as User;
        _currentUser = user;
        await _saveUser(user);
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error updating Leitner config: ${e.toString()}',
      };
    }
  }

  /// Upload user profile image
  Future<Map<String, dynamic>> uploadProfileImage(dynamic imageFile) async {
    if (_currentUser == null) {
      return {
        'success': false,
        'message': 'No user logged in',
      };
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.uploadUserProfileImage(
        _currentUser!.id,
        imageFile,
      );
      
      if (result['success'] == true) {
        final user = result['user'] as User;
        _currentUser = user;
        await _saveUser(user);
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error uploading profile image: ${e.toString()}',
      };
    }
  }

  /// Delete user data
  Future<Map<String, dynamic>> deleteUserData() async {
    if (_currentUser == null) {
      return {
        'success': false,
        'message': 'No user logged in',
      };
    }

    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.deleteUserData(_currentUser!.id);
      
      if (result['success'] == true) {
        // Don't logout, just refresh user data
        await _loadSavedUser();
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Error deleting user data: ${e.toString()}',
      };
    }
  }

  /// Refresh user data from SharedPreferences
  Future<void> refreshUser() async {
    await _loadSavedUser();
  }
}

