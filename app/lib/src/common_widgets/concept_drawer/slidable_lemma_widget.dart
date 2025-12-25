import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:archipelago/src/features/dictionary/domain/dictionary_card.dart';
import 'language_lemma_widget.dart';

class SlidableLemmaWidget extends StatelessWidget {
  final DictionaryCard card;
  final String languageCode;
  final bool showDescription;
  final bool showExtraInfo;
  final String? partOfSpeech;
  final VoidCallback? onRegenerate;
  final bool isRetrieving;

  const SlidableLemmaWidget({
    super.key,
    required this.card,
    required this.languageCode,
    this.showDescription = true,
    this.showExtraInfo = true,
    this.partOfSpeech,
    this.onRegenerate,
    this.isRetrieving = false,
  });

  String _formatRelativeDate(DateTime? date) {
    if (date == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  String _formatFutureDate(DateTime? date) {
    if (date == null) return 'Not scheduled';
    
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.isNegative) {
      return 'Overdue';
    }
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Now';
        }
        return 'in ${difference.inMinutes}m';
      }
      return 'in ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays < 7) {
      return 'in ${difference.inDays}d';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? 'in 1 week' : 'in $weeks weeks';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? 'in 1 month' : 'in $months months';
    } else {
      final years = (difference.inDays / 365).floor();
      return years == 1 ? 'in 1 year' : 'in $years years';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUserData = card.userLemmaId != null;
    
    return Slidable(
      key: ValueKey('lemma_${card.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.4,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User lemma info section
                      _buildInfoRow(
                        context,
                        card.leitnerBin?.toString() ?? (hasUserData ? '0' : 'NA'),
                        Icons.inventory_2,
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        context,
                        hasUserData ? _formatRelativeDate(card.lastReviewTime) : 'NA',
                        Icons.history,
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        context,
                        hasUserData ? _formatFutureDate(card.nextReviewAt) : 'NA',
                        Icons.schedule,
                      ),
                    ],
                  ),
                  // Regenerate button in upper right
                  if (onRegenerate != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: isRetrieving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: onRegenerate,
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(32, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              tooltip: 'Regenerate',
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      child: LanguageLemmaWidget(
        card: card,
        languageCode: languageCode,
        showDescription: showDescription,
        showExtraInfo: showExtraInfo,
        partOfSpeech: partOfSpeech,
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String value,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

