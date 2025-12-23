import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
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
        return 'Lessons per Day';
      case 'lemmas':
        return 'Lemmas per Day';
      case 'time':
        return 'Time per Day';
      default:
        return 'Exercises per Day';
    }
  }

  String _getEmptyMessage() {
    switch (_selectedMetricType) {
      case 'lessons':
        return 'No lesson data available';
      case 'lemmas':
        return 'No lemma practice data available';
      case 'time':
        return 'No time data available';
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

  Color _getLanguageColor(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'it':
        // Italian pastel dark green
        return const Color(0xFF6B8E5A);
      case 'fr':
        // French dark pastel blue
        return const Color(0xFF5A7A9A);
      default:
        // Default colors for other languages
        return Theme.of(context).colorScheme.primary;
    }
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

    // Create a map of language code to color
    final languageColorMap = <String, Color>{};
    final defaultColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    
    int defaultColorIndex = 0;
    for (final langData in widget.practiceDaily!.languageData) {
      if (!languageColorMap.containsKey(langData.languageCode)) {
        // Use specific colors for Italian and French, otherwise use default colors
        if (langData.languageCode.toLowerCase() == 'it' || 
            langData.languageCode.toLowerCase() == 'fr') {
          languageColorMap[langData.languageCode] = _getLanguageColor(langData.languageCode);
        } else {
          languageColorMap[langData.languageCode] = defaultColors[defaultColorIndex % defaultColors.length];
          defaultColorIndex++;
        }
      }
    }

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
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'lemmas', label: Text('Lemmas')),
                ButtonSegment(value: 'lessons', label: Text('Lessons')),
                ButtonSegment(value: 'exercises', label: Text('Exercises')),
                ButtonSegment(value: 'time', label: Text('Time')),
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
            const SizedBox(height: 18),
            SizedBox(
              height: 200,
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
                          if (_selectedMetricType == 'time') {
                            // Format as hours if >= 60 minutes, otherwise minutes
                            final minutes = value.toInt();
                            if (minutes >= 60) {
                              final hours = (minutes / 60).round();
                              return Text(
                                '${hours}h',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            } else {
                              return Text(
                                '${minutes}m',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            }
                          } else {
                            return Text(
                              value.toInt().toString(),
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          }
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
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest,
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          // Use barIndex to find the language
                          if (touchedSpot.barIndex >= 0 && 
                              touchedSpot.barIndex < widget.practiceDaily!.languageData.length) {
                            final langData = widget.practiceDaily!.languageData[touchedSpot.barIndex];
                            final languageCode = langData.languageCode;
                            final languageName = _getLanguageName(languageCode);
                            return LineTooltipItem(
                              '$languageName: ${touchedSpot.y.toInt()}',
                              TextStyle(
                                color: languageColorMap[languageCode] ?? Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: widget.practiceDaily!.languageData.asMap().entries.map((entry) {
                    final langData = entry.value;
                    final spots = languageSpots[langData.languageCode] ?? [];
                    final color = languageColorMap[langData.languageCode] ?? Theme.of(context).colorScheme.primary;
                    
                    return LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: color,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.2),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          
          ],
        ),
      ),
    );
  }
}

