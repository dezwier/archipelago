import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:intl/intl.dart';

/// Widget displaying practice data per language per day as an area line chart.
class ExercisesDailyChartCard extends StatefulWidget {
  final PracticeDaily? practiceDaily;
  final List<Language> languages;
  final String initialMetricType;
  final ValueChanged<String>? onMetricTypeChanged;

  const ExercisesDailyChartCard({
    super.key,
    this.practiceDaily,
    required this.languages,
    this.initialMetricType = 'exercises',
    this.onMetricTypeChanged,
  });

  @override
  State<ExercisesDailyChartCard> createState() => _ExercisesDailyChartCardState();
}

class _ExercisesDailyChartCardState extends State<ExercisesDailyChartCard> {
  late String _selectedMetricType;

  @override
  void initState() {
    super.initState();
    _selectedMetricType = widget.initialMetricType;
  }

  @override
  void didUpdateWidget(ExercisesDailyChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selected metric type if it changed from parent
    if (widget.initialMetricType != oldWidget.initialMetricType) {
      _selectedMetricType = widget.initialMetricType;
    }
  }

  String _getTitle() {
    switch (_selectedMetricType) {
      case 'lessons':
        return 'Lessons over Time';
      case 'lemmas':
        return 'Lemmas Practiced over Time';
      default:
        return 'Exercises over Time';
    }
  }

  String _getEmptyMessage() {
    switch (_selectedMetricType) {
      case 'lessons':
        return 'No lesson data available';
      case 'lemmas':
        return 'No lemma practice data available';
      default:
        return 'No exercise data available';
    }
  }

  String _getLanguageName(String code) {
    final language = widget.languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Language(code: code, name: code.toUpperCase()),
    );
    return language.name;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.practiceDaily == null || widget.practiceDaily!.languageData.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTitle(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyMessage(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Collect all unique dates and sort them
    final allDates = <String>{};
    for (final langData in widget.practiceDaily!.languageData) {
      for (final dailyData in langData.dailyData) {
        allDates.add(dailyData.date);
      }
    }
    final sortedDates = allDates.toList()..sort();

    if (sortedDates.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTitle(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyMessage(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Find max count for scaling
    int maxCount = 1;
    for (final langData in widget.practiceDaily!.languageData) {
      for (final dailyData in langData.dailyData) {
        if (dailyData.count > maxCount) {
          maxCount = dailyData.count;
        }
      }
    }

    // Define colors for each language
    final languageColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    // Build spots for each language
    final languageSpots = <String, List<FlSpot>>{};
    for (int i = 0; i < widget.practiceDaily!.languageData.length; i++) {
      final langData = widget.practiceDaily!.languageData[i];
      final spots = <FlSpot>[];
      
      // Create a map of date -> count for this language
      final dateCountMap = <String, int>{};
      for (final dailyData in langData.dailyData) {
        dateCountMap[dailyData.date] = dailyData.count;
      }
      
      // Create spots for each date (use 0 if no data for that date)
      for (int j = 0; j < sortedDates.length; j++) {
        final date = sortedDates[j];
        final count = dateCountMap[date] ?? 0;
        spots.add(FlSpot(j.toDouble(), count.toDouble()));
      }
      
      languageSpots[langData.languageCode] = spots;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getTitle(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lemmas', label: Text('Lemmas')),
                ButtonSegment(value: 'lessons', label: Text('Lessons')),
                ButtonSegment(value: 'exercises', label: Text('Exercises')),
              ],
              selected: {_selectedMetricType},
              onSelectionChanged: (Set<String> newSelection) {
                final newMetricType = newSelection.first;
                setState(() {
                  _selectedMetricType = newMetricType;
                });
                // Notify parent to reload data with new metric type
                widget.onMetricTypeChanged?.call(newMetricType);
              },
              showSelectedIcon: false,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedDates.length) {
                            final dateStr = sortedDates[index];
                            try {
                              final date = DateTime.parse(dateStr);
                              // Show date label for every nth date to avoid crowding
                              final interval = (sortedDates.length / 8).ceil();
                              if (index % interval == 0 || index == sortedDates.length - 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('MM/dd').format(date),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              }
                            } catch (_) {
                              // If parsing fails, show the string
                              if (index % 5 == 0 || index == sortedDates.length - 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    dateStr.length > 5 ? dateStr.substring(5) : dateStr,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              }
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.min || value == meta.max) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            value.toInt().toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  minX: 0,
                  maxX: (sortedDates.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxCount * 1.1, // Add 10% padding
                  lineBarsData: widget.practiceDaily!.languageData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final langData = entry.value;
                    final spots = languageSpots[langData.languageCode] ?? [];
                    final color = languageColors[index % languageColors.length];
                    
                    return LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.2),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: widget.practiceDaily!.languageData.asMap().entries.map((entry) {
                final index = entry.key;
                final langData = entry.value;
                final emoji = LanguageEmoji.getEmoji(langData.languageCode);
                final languageName = _getLanguageName(langData.languageCode);
                final color = languageColors[index % languageColors.length];
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      emoji,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      languageName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

