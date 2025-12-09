/// Maps language codes to their corresponding flag emojis
class LanguageEmoji {
  static const Map<String, String> emojiMap = {
    'en': '🇬🇧', // English - UK flag
    'es': '🇪🇸', // Spanish
    'it': '🇮🇹', // Italian
    'fr': '🇫🇷', // French
    'de': '🇩🇪', // German
    'jp': '🇯🇵', // Japanese
    'nl': '🇳🇱', // Dutch
    'lt': '🇱🇹', // Lithuanian
    'pt': '🇵🇹', // Portuguese
    'ar': '🇸🇦', // Arabic - Saudi Arabian flag
  };

  static String getEmoji(String languageCode) {
    return emojiMap[languageCode.toLowerCase()] ?? '🌐';
  }
}

