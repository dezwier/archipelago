import 'package:flutter/material.dart';
import '../../../utils/html_entity_decoder.dart';

class FlashcardConfirmationScreen extends StatefulWidget {
  final Map<String, dynamic> flashcardData;
  final String concept;
  final String sourceLanguageCode;
  final String targetLanguageCode;

  const FlashcardConfirmationScreen({
    super.key,
    required this.flashcardData,
    required this.concept,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
  });

  @override
  State<FlashcardConfirmationScreen> createState() => _FlashcardConfirmationScreenState();
}

class _FlashcardConfirmationScreenState extends State<FlashcardConfirmationScreen> {

  String _getFlagEmoji(String code) {
    // Map language codes to flag emojis
    final flagMap = {
      'en': '🇬🇧',
      'fr': '🇫🇷',
      'es': '🇪🇸',
      'de': '🇩🇪',
      'it': '🇮🇹',
      'pt': '🇵🇹',
      'jp': '🇯🇵',
      'ja': '🇯🇵', // Alternative code for Japanese
      'zh': '🇨🇳',
      'ru': '🇷🇺',
      'ko': '🇰🇷',
      'ar': '🇸🇦',
      'nl': '🇳🇱',
      'pl': '🇵🇱',
      'sv': '🇸🇪',
      'da': '🇩🇰',
      'no': '🇳🇴',
      'fi': '🇫🇮',
      'tr': '🇹🇷',
      'he': '🇮🇱',
      'hi': '🇮🇳',
      'th': '🇹🇭',
      'vi': '🇻🇳',
      'id': '🇮🇩',
      'cs': '🇨🇿',
      'hu': '🇭🇺',
      'ro': '🇷🇴',
      'el': '🇬🇷',
      'uk': '🇺🇦',
      'bg': '🇧🇬',
      'hr': '🇭🇷',
      'sk': '🇸🇰',
      'sl': '🇸🇮',
      'et': '🇪🇪',
      'lv': '🇱🇻',
      'lt': '🇱🇹',
    };
    
    return flagMap[code.toLowerCase()] ?? '🌐';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.flashcardData['data'] as Map<String, dynamic>?;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirmation')),
        body: const Center(child: Text('No data available')),
      );
    }

    // Extract all cards from the response
    final allCards = data['all_cards'] as List<dynamic>?;
    
    // Build list of all translations
    final translations = <Map<String, String>>[];
    
    if (allCards != null) {
      for (final card in allCards) {
        final cardMap = card as Map<String, dynamic>;
        translations.add({
          'language_code': cardMap['language_code'] as String,
          'translation': cardMap['translation'] as String,
        });
      }
    } else {
      // Fallback to source and target cards if all_cards is not available
      final sourceCard = data['source_card'] as Map<String, dynamic>?;
      final targetCard = data['target_card'] as Map<String, dynamic>?;
      
      if (sourceCard != null) {
        translations.add({
          'language_code': sourceCard['language_code'] as String,
          'translation': sourceCard['translation'] as String,
        });
      }
      
      if (targetCard != null) {
        translations.add({
          'language_code': targetCard['language_code'] as String,
          'translation': targetCard['translation'] as String,
        });
      }
    }

    // Sort by language code for consistent display
    translations.sort((a, b) => a['language_code']!.compareTo(b['language_code']!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard Created'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data['message'] as String? ?? 'Flashcard generated successfully',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Concept section - more compact and stylish
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Concept',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Text(
                HtmlEntityDecoder.decode(widget.concept),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Translations section
            Row(
              children: [
                Icon(
                  Icons.translate,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Translations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            ...translations.map((translation) {
                final langCode = translation['language_code']!;
                final translationText = translation['translation']!;
                final flagEmoji = _getFlagEmoji(langCode);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Language flag emoji - fixed width for alignment
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            flagEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Translation text
                      Expanded(
                        child: Text(
                          HtmlEntityDecoder.decode(translationText),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            
            const SizedBox(height: 16),
            
            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

