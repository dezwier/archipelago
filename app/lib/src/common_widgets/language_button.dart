import 'package:flutter/material.dart';
import 'package:archipelago/src/features/shared/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

class LanguageButton extends StatelessWidget {
  final Language language;
  final bool isSelected;
  final VoidCallback? onPressed;

  const LanguageButton({
    super.key,
    required this.language,
    required this.isSelected,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          side: BorderSide(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1 : 1,
          ),
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  LanguageEmoji.getEmoji(language.code),
                  style: const TextStyle(fontSize: 24, height: 1.0),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                language.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

