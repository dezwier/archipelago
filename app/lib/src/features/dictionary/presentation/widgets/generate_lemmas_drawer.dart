import 'package:flutter/material.dart';
import 'package:archipelago/src/features/dictionary/presentation/widgets/card_generation_progress_widget.dart';
import 'package:archipelago/src/features/dictionary/presentation/controllers/card_generation_state.dart';

/// Bottom drawer widget for generating lemmas for concepts with missing languages
class GenerateLemmasDrawer extends StatefulWidget {
  final CardGenerationState cardGenerationState;
  final Future<void> Function() onConfirmGenerate;
  final List<String> visibleLanguageCodes;

  const GenerateLemmasDrawer({
    super.key,
    required this.cardGenerationState,
    required this.onConfirmGenerate,
    required this.visibleLanguageCodes,
  });

  @override
  State<GenerateLemmasDrawer> createState() => _GenerateLemmasDrawerState();
}

class _GenerateLemmasDrawerState extends State<GenerateLemmasDrawer> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Listen to state changes to update UI when progress changes
    return ListenableBuilder(
      listenable: widget.cardGenerationState,
      builder: (context, _) {
        final isGenerating = widget.cardGenerationState.isGeneratingCards;
        final hasProgress = widget.cardGenerationState.totalConcepts != null;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 8.0, 0.0),
            child: Row(
              children: [
                Text(
                  'Generate Lemmas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // Progress widget (shown when generating or has progress)
                  if (hasProgress)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: CardGenerationProgressWidget(
                        totalConcepts: widget.cardGenerationState.totalConcepts,
                        currentConceptIndex: widget.cardGenerationState.currentConceptIndex,
                        currentConceptTerm: widget.cardGenerationState.currentConceptTerm,
                        currentConceptMissingLanguages: widget.cardGenerationState.currentConceptMissingLanguages,
                        conceptsProcessed: widget.cardGenerationState.conceptsProcessed,
                        cardsCreated: widget.cardGenerationState.cardsCreated,
                        errors: widget.cardGenerationState.errors,
                        sessionCostUsd: widget.cardGenerationState.sessionCostUsd,
                        isGenerating: widget.cardGenerationState.isGeneratingCards,
                        isCancelled: widget.cardGenerationState.isCancelled,
                        onCancel: widget.cardGenerationState.isGeneratingCards 
                            ? () => widget.cardGenerationState.handleCancel()
                            : null,
                        onDismiss: !widget.cardGenerationState.isGeneratingCards 
                            ? () {
                                widget.cardGenerationState.dismissProgress();
                                if (mounted) setState(() {});
                              }
                            : null,
                      ),
                    ),
                  
                  // Confirmation section (shown when not generating or when there's no progress)
                  if (!isGenerating && !hasProgress) ...[
                    // Info about what will be generated
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'What will be generated?',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This will generate lemmas (cards) for concepts that are missing translations in the currently visible languages.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          if (widget.visibleLanguageCodes.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Text(
                                  'Visible languages:',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                ...widget.visibleLanguageCodes.map((code) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      code.toUpperCase(),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Generate button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || widget.visibleLanguageCodes.isEmpty) 
                            ? null 
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                
                                try {
                                  await widget.onConfirmGenerate();
                                  // Don't close drawer - let progress show
                                  if (mounted) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _isLoading = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Generate Lemmas',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                  
                  // Bottom padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ],
        ),
      );
      },
    );
  }
}

/// Helper function to show the generate lemmas bottom drawer
void showGenerateLemmasDrawer({
  required BuildContext context,
  required CardGenerationState cardGenerationState,
  required Future<void> Function() onConfirmGenerate,
  required List<String> visibleLanguageCodes,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => GenerateLemmasDrawer(
      cardGenerationState: cardGenerationState,
      onConfirmGenerate: onConfirmGenerate,
      visibleLanguageCodes: visibleLanguageCodes,
    ),
  );
}

