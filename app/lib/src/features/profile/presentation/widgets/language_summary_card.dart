import 'package:flutter/material.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

/// Widget displaying language summary statistics.
class LanguageSummaryCard extends StatelessWidget {
  final SummaryStats stats;
  final List<Language> languages;

  const LanguageSummaryCard({
    super.key,
    required this.stats,
    required this.languages,
  });

  String _getLanguageName(String code) {
    final language = languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Language(code: code, name: code.toUpperCase()),
    );
    return language.name;
  }

  @override
  Widget build(BuildContext context) {
    if (stats.languageStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learning Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'No learning data available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learning Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...stats.languageStats.map((stat) {
              final emoji = LanguageEmoji.getEmoji(stat.languageCode);
              final languageName = _getLanguageName(stat.languageCode);
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          emoji,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          languageName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stat.lemmaCount} lemmas learning',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${stat.exerciseCount} exercises done',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

