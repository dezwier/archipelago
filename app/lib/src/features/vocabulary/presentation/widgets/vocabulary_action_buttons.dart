import 'package:flutter/material.dart';

class VocabularyActionButtons extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback? onRefreshImages;
  final VoidCallback? onRandomCard;
  final VoidCallback? onRegenerate;

  const VocabularyActionButtons({
    super.key,
    required this.isEditing,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    this.onRefreshImages,
    this.onRandomCard,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onSave,
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
          IconButton(
            onPressed: onRefreshImages,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Images',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSquareIconButton(
          context,
          icon: Icons.edit,
          tooltip: 'Edit',
          onPressed: onEdit,
        ),
        const SizedBox(height: 8),
        _buildSquareIconButton(
          context,
          icon: Icons.auto_fix_high,
          tooltip: 'Regenerate LLM Output',
          onPressed: onRegenerate,
        ),
        const SizedBox(height: 8),
        _buildSquareIconButton(
          context,
          icon: Icons.shuffle,
          tooltip: 'Random Card',
          onPressed: onRandomCard,
        ),
      ],
    );
  }

  Widget _buildSquareIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Widget? child,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: child ??
                Icon(
                  icon,
                  size: 20,
                  color: onPressed == null
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                      : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}

