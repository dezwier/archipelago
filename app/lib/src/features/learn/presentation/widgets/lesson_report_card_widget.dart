import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:archipelago/src/features/learn/domain/exercise_performance.dart';
import 'package:archipelago/src/features/dictionary/data/lemma_audio_service.dart';

/// Widget that displays a report card at the end of a lesson
/// Shows summary statistics and detailed exercise performance
class LessonReportCardWidget extends StatefulWidget {
  final List<ExercisePerformance> performances;
  final VoidCallback onDone;

  const LessonReportCardWidget({
    super.key,
    required this.performances,
    required this.onDone,
  });

  @override
  State<LessonReportCardWidget> createState() => _LessonReportCardWidgetState();
}

class _LessonReportCardWidgetState extends State<LessonReportCardWidget> {
  final Set<int> _expandedExerciseIndices = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  dynamic _currentPlayingConceptId;
  bool _isPlayingAudio = false;
  bool _isGeneratingAudio = false;

  /// Calculate summary statistics
  Map<String, dynamic> _calculateStats() {
    if (widget.performances.isEmpty) {
      return {
        'totalExercises': 0,
        'succeeded': 0,
        'neededHints': 0,
        'failed': 0,
        'totalDuration': Duration.zero,
      };
    }

    final totalExercises = widget.performances.length;
    final succeeded = widget.performances.where((p) => p.outcome == ExerciseOutcome.succeeded).length;
    final neededHints = widget.performances.where((p) => p.outcome == ExerciseOutcome.neededHints).length;
    final failed = widget.performances.where((p) => p.outcome == ExerciseOutcome.failed).length;
    
    final totalDuration = widget.performances.fold<Duration>(
      Duration.zero,
      (sum, p) => sum + p.duration,
    );

    return {
      'totalExercises': totalExercises,
      'succeeded': succeeded,
      'neededHints': neededHints,
      'failed': failed,
      'totalDuration': totalDuration,
    };
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '${seconds}s';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (minutes < 60) {
        return '${minutes}m ${remainingSeconds}s';
      } else {
        final hours = minutes ~/ 60;
        final remainingMinutes = minutes % 60;
        return '${hours}h ${remainingMinutes}m';
      }
    }
  }

  Color _getOutcomeColor(ExerciseOutcome outcome) {
    switch (outcome) {
      case ExerciseOutcome.succeeded:
        return Colors.green;
      case ExerciseOutcome.neededHints:
        return Colors.orange;
      case ExerciseOutcome.failed:
        return Colors.red;
    }
  }

  IconData _getOutcomeIcon(ExerciseOutcome outcome) {
    switch (outcome) {
      case ExerciseOutcome.succeeded:
        return Icons.check_circle;
      case ExerciseOutcome.neededHints:
        return Icons.help_outline;
      case ExerciseOutcome.failed:
        return Icons.cancel;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Get unique concepts from performances (deduplicated by conceptId)
  List<Map<String, dynamic>> _getUniqueConcepts() {
    final Map<dynamic, Map<String, dynamic>> uniqueConcepts = {};
    
    for (final performance in widget.performances) {
      final conceptId = performance.conceptId;
      if (conceptId != null && !uniqueConcepts.containsKey(conceptId)) {
        // Count exercises for this concept
        final exerciseCount = widget.performances.where((p) => 
          p.conceptId != null && p.conceptId.toString() == conceptId.toString()
        ).length;
        
        uniqueConcepts[conceptId] = {
          'conceptId': conceptId,
          'conceptTerm': performance.conceptTerm,
          'conceptImageUrl': performance.conceptImageUrl,
          'exerciseCount': exerciseCount,
          'learningLemmaId': performance.learningLemmaId,
          'learningAudioPath': performance.learningAudioPath,
          'learningLanguageCode': performance.learningLanguageCode,
          'learningTerm': performance.learningTerm,
        };
      }
    }
    
    return uniqueConcepts.values.toList();
  }

  /// Play audio for a concept, interrupting any currently playing audio
  /// If the same concept is already playing, stop it instead
  Future<void> _playConceptAudio(Map<String, dynamic> concept) async {
    final conceptId = concept['conceptId'];
    final learningLemmaId = concept['learningLemmaId'] as int?;
    
    if (learningLemmaId == null) {
      return;
    }
    
    // Check if the same concept is already playing
    final isCurrentlyPlaying = _currentPlayingConceptId != null && 
        _currentPlayingConceptId.toString() == conceptId.toString() &&
        (_isPlayingAudio || _isGeneratingAudio);
    
    if (isCurrentlyPlaying) {
      // Stop the audio if it's already playing
      await _audioPlayer.stop();
      setState(() {
        _currentPlayingConceptId = null;
        _isPlayingAudio = false;
        _isGeneratingAudio = false;
      });
      return;
    }
    
    // Stop any currently playing audio from other concepts
    await _audioPlayer.stop();
    
    final learningAudioPath = concept['learningAudioPath'] as String?;
    final learningLanguageCode = concept['learningLanguageCode'] as String?;
    final learningTerm = concept['learningTerm'] as String?;
    
    setState(() {
      _currentPlayingConceptId = conceptId;
      _isPlayingAudio = false;
      _isGeneratingAudio = false;
    });
    
    // Check if audio already exists
    if (learningAudioPath != null && learningAudioPath.isNotEmpty) {
      await _playExistingAudio(conceptId, learningAudioPath);
    } else {
      // Generate audio first
      await _generateAndPlayAudio(conceptId, learningLemmaId, learningTerm, learningLanguageCode);
    }
  }

  Future<void> _playExistingAudio(dynamic conceptId, String audioPath) async {
    setState(() {
      _isPlayingAudio = true;
    });
    
    try {
      final audioUrl = LemmaAudioService.getAudioUrl(audioPath);
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
              _currentPlayingConceptId = null;
            });
          }
        });
      } else {
        setState(() {
          _isPlayingAudio = false;
          _currentPlayingConceptId = null;
        });
      }
    } catch (e) {
      setState(() {
        _isPlayingAudio = false;
        _currentPlayingConceptId = null;
      });
    }
  }

  Future<void> _generateAndPlayAudio(dynamic conceptId, int lemmaId, String? term, String? languageCode) async {
    setState(() {
      _isGeneratingAudio = true;
    });
    
    try {
      final result = await LemmaAudioService.generateAudio(
        lemmaId: lemmaId,
        term: term,
        languageCode: languageCode,
      );
      
      if (!result['success']) {
        setState(() {
          _isGeneratingAudio = false;
          _currentPlayingConceptId = null;
        });
        return;
      }
      
      final audioUrl = result['audioUrl'] as String?;
      if (audioUrl == null) {
        setState(() {
          _isGeneratingAudio = false;
          _currentPlayingConceptId = null;
        });
        return;
      }
      
      setState(() {
        _isGeneratingAudio = false;
        _isPlayingAudio = true;
      });
      
      final fullAudioUrl = LemmaAudioService.getAudioUrl(audioUrl);
      if (fullAudioUrl != null) {
        await _audioPlayer.play(UrlSource(fullAudioUrl));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() {
              _isPlayingAudio = false;
              _currentPlayingConceptId = null;
            });
          }
        });
      } else {
        setState(() {
          _isPlayingAudio = false;
          _currentPlayingConceptId = null;
        });
      }
    } catch (e) {
      setState(() {
        _isGeneratingAudio = false;
        _isPlayingAudio = false;
        _currentPlayingConceptId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final uniqueConcepts = _getUniqueConcepts();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.assessment,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Lesson Report',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Compact Summary Card
              _buildCompactSummaryCard(context, stats),
              const SizedBox(height: 4),

              // Concepts Learned Card
              if (uniqueConcepts.isNotEmpty) ...[
                _buildConceptsLearnedCard(context, uniqueConcepts),
                const SizedBox(height: 12),
              ],
              // Done Button (between summary and concepts)
              FilledButton(
                onPressed: widget.onDone,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done'),
              ),
              const SizedBox(height: 24),


              // Exercise Details Section
              Text(
                'Exercise Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (widget.performances.isEmpty)
                _buildDictionaryStyleCard(
                  context,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'No exercises completed',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...widget.performances.asMap().entries.map((entry) {
                  final index = entry.key;
                  final performance = entry.value;
                  return _buildExpandableExerciseCard(context, index, performance);
                }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Build dictionary-style card container
  Widget _buildDictionaryStyleCard(BuildContext context, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  /// Build compact summary card
  Widget _buildCompactSummaryCard(BuildContext context, Map<String, dynamic> stats) {
    return _buildDictionaryStyleCard(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Total exercises
            Row(
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total exercises: ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${stats['totalExercises']}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Exercises breakdown: succeeded, hinted, failed
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildOutcomeChipWithLabel(
                        context,
                        'succeeded',
                        '${stats['succeeded']}',
                        Colors.green,
                      ),
                      _buildOutcomeChipWithLabel(
                        context,
                        'hinted',
                        '${stats['neededHints']}',
                        Colors.orange,
                      ),
                      _buildOutcomeChipWithLabel(
                        context,
                        'failed',
                        '${stats['failed']}',
                        Colors.red,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Total time
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Total time: ',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  _formatDuration(stats['totalDuration']),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build outcome chip with label for exercises breakdown display
  Widget _buildOutcomeChipWithLabel(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Build concepts learned card
  Widget _buildConceptsLearnedCard(BuildContext context, List<Map<String, dynamic>> concepts) {
    return _buildDictionaryStyleCard(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${concepts.length} Concepts Learned',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 4,
                childAspectRatio: 2.5,
              ),
              itemCount: concepts.length,
              itemBuilder: (context, index) {
                return _buildConceptItem(context, concepts[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual concept item
  Widget _buildConceptItem(BuildContext context, Map<String, dynamic> concept) {
    final imageUrl = concept['conceptImageUrl'] as String?;
    final conceptTerm = concept['conceptTerm'] as String? ?? 'Unknown';
    final conceptId = concept['conceptId'];
    final learningLemmaId = concept['learningLemmaId'] as int?;
    final canPlayAudio = learningLemmaId != null;
    final isCurrentlyPlaying = _currentPlayingConceptId != null && 
        _currentPlayingConceptId.toString() == conceptId.toString();
    final isPlaying = isCurrentlyPlaying && (_isPlayingAudio || _isGeneratingAudio);

    return InkWell(
      onTap: canPlayAudio ? () => _playConceptAudio(concept) : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Square image on the left with overlay icon when playing
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              size: 24,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                // Volume icon overlay when playing
                if (isPlaying)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.volume_up,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Concept term on the right - max 3 lines
          Expanded(
            child: Text(
              conceptTerm,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Build expandable exercise card
  Widget _buildExpandableExerciseCard(BuildContext context, int index, ExercisePerformance performance) {
    final isExpanded = _expandedExerciseIndices.contains(index);

    return _buildDictionaryStyleCard(
      context,
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedExerciseIndices.remove(index);
            } else {
              _expandedExerciseIndices.add(index);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Compact view (always visible)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Outcome icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getOutcomeColor(performance.outcome).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getOutcomeIcon(performance.outcome),
                      color: _getOutcomeColor(performance.outcome),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Exercise info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exercise ${index + 1}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          performance.exerciseType.displayName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Duration
                  Text(
                    performance.durationString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand/collapse icon
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
            // Expanded view (conditional)
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 8),
                    // Concept term
                    if (performance.conceptTerm != null && performance.conceptTerm!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              performance.conceptTerm!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Outcome
                    Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          performance.outcomeDisplayName,
                          style: TextStyle(
                            color: _getOutcomeColor(performance.outcome),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Hints used
                    if (performance.hintCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${performance.hintCount} hint${performance.hintCount == 1 ? '' : 's'} used',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                    // Failure reason
                    if (performance.failureReason != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              performance.failureReason!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Duration detail
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Duration: ${performance.durationString}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
