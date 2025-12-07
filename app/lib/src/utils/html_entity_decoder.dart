/// Utility class for decoding HTML entities in text
class HtmlEntityDecoder {
  /// Decodes common HTML entities in a string
  /// Handles entities like &amp;, &quot;, &apos;, &lsquo;, &rsquo;, &l39;, etc.
  static String decode(String text) {
    if (text.isEmpty) return text;
    
    // Common HTML entities mapping (case-insensitive)
    final Map<String, String> entities = {
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&apos;': "'",
      '&nbsp;': ' ',
      '&lsquo;': ''',
      '&rsquo;': ''',
      '&ldquo;': '"',
      '&rdquo;': '"',
      '&ndash;': '–',
      '&mdash;': '—',
      '&hellip;': '…',
      '&l39;': "'", // Common typo/variant
      '&r39;': "'", // Common typo/variant
      '&L39;': "'", // Uppercase variant
      '&R39;': "'", // Uppercase variant
    };
    
    String result = text;
    
    // Replace named entities
    entities.forEach((entity, replacement) {
      result = result.replaceAll(entity, replacement);
    });
    
    // Handle numeric entities like &#39; or &#x27;
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.parse(match.group(1)!);
        return String.fromCharCode(code);
      },
    );
    
    // Handle hex entities like &#x27;
    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final code = int.parse(match.group(1)!, radix: 16);
        return String.fromCharCode(code);
      },
    );
    
    return result;
  }
}

