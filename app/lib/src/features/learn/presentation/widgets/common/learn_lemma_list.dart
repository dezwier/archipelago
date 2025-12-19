import 'package:flutter/material.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

/// Widget to display a list of concepts with both native and learning language lemmas
class LearnLemmaList extends StatelessWidget {
  final List<Map<String, dynamic>> concepts; // List of concepts, each with learning_lemma and native_lemma
  final bool isLoading;
  final String? errorMessage;
  final String? nativeLanguage;
  final String? learningLanguage;

  const LearnLemmaList({
    super.key,
    required this.concepts,
    this.isLoading = false,
    this.errorMessage,
    this.nativeLanguage,
    this.learningLanguage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (concepts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'No new cards available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: concepts.length,
      itemBuilder: (context, index) {
        final concept = concepts[index];
        
        // Get learning and native lemmas from the concept
        final learningLemma = concept['learning_lemma'] as Map<String, dynamic>?;
        final nativeLemma = concept['native_lemma'] as Map<String, dynamic>?;
        
        if (learningLemma == null) {
          return const SizedBox.shrink();
        }
        
        final translation = learningLemma['translation'] as String? ?? 'Unknown';
        final languageCode = (learningLemma['language_code'] as String? ?? '').toLowerCase();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Row(
                  children: [
                    Text(
                      LanguageEmoji.getEmoji(languageCode),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        translation,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                subtitle: learningLemma['description'] != null
                    ? Text(
                        learningLemma['description'] as String,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : null,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    translation.isNotEmpty ? translation[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              // Show native language lemma if available
              if (nativeLemma != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                  child: Row(
                    children: [
                      Text(
                        LanguageEmoji.getEmoji((nativeLemma['language_code'] as String? ?? '').toLowerCase()),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          nativeLemma['translation'] as String? ?? 'Unknown',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}


