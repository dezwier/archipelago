import 'package:archipelago/src/features/profile/domain/language.dart';

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
    if (_languagesToShow.isNotEmpty) {
      return; // Already initialized
    }

    _languageVisibility = {
      for (var lang in allLanguages) 
        lang.code: (lang.code == sourceCode || lang.code == targetCode)
    };
    
    _languagesToShow = [];
    if (sourceCode != null) {
      _languagesToShow.add(sourceCode);
    }
    if (targetCode != null && targetCode != sourceCode) {
      _languagesToShow.add(targetCode);
    }
  }

  void toggleLanguageVisibility(String languageCode) {
    final wasVisible = _languageVisibility[languageCode] ?? true;
    final willBeVisible = !wasVisible;
    
    // Prevent disabling if this is the last visible language
    if (wasVisible && !willBeVisible) {
      final visibleCount = _languageVisibility.values.where((v) => v == true).length;
      if (visibleCount <= 1) {
        return; // Don't proceed with the change
      }
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

