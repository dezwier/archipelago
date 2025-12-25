import 'package:archipelago/src/features/shared/domain/language.dart';

class LanguageVisibilityManager {
  Map<String, bool> _languageVisibility = {};
  List<String> _languagesToShow = [];

  Map<String, bool> get languageVisibility => _languageVisibility;
  List<String> get languagesToShow => _languagesToShow;

  void initializeForLoggedOutUser(List<Language> allLanguages) {
    _languageVisibility = {
      for (var lang in allLanguages) 
        lang.code: lang.code.toLowerCase() == 'en'
    };
    _languagesToShow = ['en'];
  }

  void initializeForLoggedInUser(
    List<Language> allLanguages,
    String? sourceCode,
    String? targetCode,
  ) {
    // Always re-initialize to ensure correct state (handles hot restart)
    // Initialize all languages to false, then enable native and learning languages
    _languageVisibility = {
      for (var lang in allLanguages) 
        lang.code: false
    };
    
    // Enable native and learning languages
    if (sourceCode != null) {
      _languageVisibility[sourceCode] = true;
    }
    if (targetCode != null) {
      _languageVisibility[targetCode] = true;
    }
    
    _languagesToShow = [];
    if (sourceCode != null) {
      _languagesToShow.add(sourceCode);
    }
    if (targetCode != null && targetCode != sourceCode) {
      _languagesToShow.add(targetCode);
    }
  }

  void toggleLanguageVisibility(String languageCode) {
    // Get current state - default to false if not in map
    final wasVisible = _languageVisibility[languageCode] ?? false;
    final willBeVisible = !wasVisible;
    
    // Prevent disabling if this is the last visible language
    if (wasVisible && !willBeVisible) {
      final visibleCount = _languageVisibility.values.where((v) => v == true).length;
      if (visibleCount <= 1) {
        return; // Don't proceed with the change
      }
    }
    
    // Ensure the language is in the map
    if (!_languageVisibility.containsKey(languageCode)) {
      _languageVisibility[languageCode] = false;
    }
    
    _languageVisibility[languageCode] = willBeVisible;
    
    if (!wasVisible && willBeVisible) {
      // Language was just enabled - append to the end of the list
      if (!_languagesToShow.contains(languageCode)) {
        _languagesToShow.add(languageCode);
      }
    } else if (wasVisible && !willBeVisible) {
      // Language was just disabled - remove from the list
      _languagesToShow.remove(languageCode);
    }
  }

  List<String> getVisibleLanguageCodes() {
    return _languageVisibility.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}

