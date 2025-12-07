import 'package:flutter/material.dart';
import '../../../../utils/language_emoji.dart';
import '../../domain/paired_vocabulary_item.dart';

class EditVocabularyDialog extends StatefulWidget {
  final PairedVocabularyItem item;
  final String? sourceLanguageCode;
  final String? targetLanguageCode;

  const EditVocabularyDialog({
    super.key,
    required this.item,
    this.sourceLanguageCode,
    this.targetLanguageCode,
  });

  @override
  State<EditVocabularyDialog> createState() => _EditVocabularyDialogState();
}

class _EditVocabularyDialogState extends State<EditVocabularyDialog> {
  late final TextEditingController _sourceController;
  late final TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController(
      text: widget.item.sourceCard?.translation ?? '',
    );
    _targetController = TextEditingController(
      text: widget.item.targetCard?.translation ?? '',
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Translation'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.item.sourceCard != null && widget.sourceLanguageCode != null) ...[
              Text(
                '${LanguageEmoji.getEmoji(widget.sourceLanguageCode!)} Source (${widget.sourceLanguageCode!.toUpperCase()})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sourceController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Enter source translation',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.item.targetCard != null && widget.targetLanguageCode != null) ...[
              Text(
                '${LanguageEmoji.getEmoji(widget.targetLanguageCode!)} Target (${widget.targetLanguageCode!.toUpperCase()})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Enter target translation',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop({
              'source': _sourceController.text.trim(),
              'target': _targetController.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

}

