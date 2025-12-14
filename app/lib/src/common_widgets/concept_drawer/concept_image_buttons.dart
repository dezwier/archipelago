import 'package:flutter/material.dart';

class DictionaryActionButtons extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final VoidCallback? onRegenerate;
  final VoidCallback? onDelete;

  const DictionaryActionButtons({
    super.key,
    required this.isEditing,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
    this.onRegenerate,
    this.onDelete,
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
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate if buttons fit, if not, reduce size further
        final buttonWidth = 36.0;
        final spacing = 4.0;
        // Calculate total width based on number of visible buttons
        final buttonCount = 2 + (onRegenerate != null ? 1 : 0);
        final totalWidth = (buttonWidth * buttonCount) + (spacing * (buttonCount - 1));
        
        // If buttons don't fit, use smaller size
        final useSmallButtons = constraints.maxWidth < totalWidth && constraints.maxWidth > 0;
        final actualButtonWidth = useSmallButtons ? 32.0 : 36.0;
        final actualIconSize = useSmallButtons ? 16.0 : 18.0;
        
        final buttons = <Widget>[
          _buildSquareIconButton(
            context,
            icon: Icons.edit,
            tooltip: 'Edit',
            onPressed: onEdit,
            buttonWidth: actualButtonWidth,
            iconSize: actualIconSize,
          ),
        ];
        
        // Only show regenerate button if onRegenerate is provided
        if (onRegenerate != null) {
          buttons.add(SizedBox(width: useSmallButtons ? 2 : 4));
          buttons.add(
            _buildSquareIconButton(
              context,
              icon: Icons.auto_fix_high,
              tooltip: 'Regenerate LLM Output',
              onPressed: onRegenerate,
              buttonWidth: actualButtonWidth,
              iconSize: actualIconSize,
            ),
          );
        }
        
        buttons.add(SizedBox(width: useSmallButtons ? 2 : 4));
        buttons.add(
          _buildSquareIconButton(
            context,
            icon: Icons.delete,
            tooltip: 'Delete',
            onPressed: onDelete,
            buttonWidth: actualButtonWidth,
            iconSize: actualIconSize,
          ),
        );
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: buttons,
        );
      },
    );
  }

  Widget _buildSquareIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Widget? child,
    double buttonWidth = 36,
    double iconSize = 18,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: buttonWidth,
            height: buttonWidth,
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
                  size: iconSize,
                  color: onPressed == null
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                      : icon == Icons.delete
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}

