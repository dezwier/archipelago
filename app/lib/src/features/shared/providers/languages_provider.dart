import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/features/shared/data/language_service.dart';

/// Provider that manages languages list.
/// Languages are loaded once on initialization and cached.
class LanguagesProvider extends ChangeNotifier {
  List<Language> _languages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  LanguagesProvider() {
    _loadLanguages();
  }

  List<Language> get languages => _languages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  Future<void> _loadLanguages() async {
    if (_isInitialized) return; // Already loaded

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final languages = await LanguageService.getLanguages();
      _languages = languages;
      _errorMessage = null;
      _isInitialized = true;
    } catch (e) {
      _errorMessage = 'Failed to load languages: ${e.toString()}';
      _languages = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manually refresh languages (rarely needed)
  Future<void> refresh() async {
    _isInitialized = false;
    await _loadLanguages();
  }
}

