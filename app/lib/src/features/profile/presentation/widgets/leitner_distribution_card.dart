import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/profile/data/statistics_service.dart';

/// Widget displaying Leitner bin distribution as a bar chart.
class LeitnerDistributionCard extends StatefulWidget {
  final LeitnerDistribution distribution;
  final List<Language> languages;
  final int userId;
  final VoidCallback? onRefresh;

  const LeitnerDistributionCard({
    super.key,
    required this.distribution,
    required this.languages,
    required this.userId,
    this.onRefresh,
  });

  @override
  State<LeitnerDistributionCard> createState() => _LeitnerDistributionCardState();
}

class _LeitnerDistributionCardState extends State<LeitnerDistributionCard> {
  bool _isRecomputing = false;

  String _getLanguageName(String code) {
    final language = widget.languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Language(code: code, name: code.toUpperCase()),
    );
    return language.name;
  }

  Future<void> _handleRecompute() async {
    // Get user ID from somewhere - we'll need to pass it or get it from context
    // For now, we'll need to get it from the distribution or pass it as a parameter
    // Let's check if we can get it from the profile screen context
    
    setState(() {
      _isRecomputing = true;
    });

    try {
      final result = await StatisticsService.recomputeSRS(
        userId: widget.userId,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String? ?? 'SRS recomputed successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // Refresh the data
          widget.onRefresh?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String? ?? 'Failed to recompute SRS'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecomputing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.distribution.distribution.isEmpty) {
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Leitner Bins - ${_getLanguageName(widget.distribution.languageCode)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: _isRecomputing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                    onPressed: _isRecomputing ? null : _handleRecompute,
                    tooltip: 'Recompute SRS',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
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

    final emoji = LanguageEmoji.getEmoji(widget.distribution.languageCode);
    final languageName = _getLanguageName(widget.distribution.languageCode);
    
    // Determine bin range: minimum 0-7, extend if higher bins exist
    final binsInData = widget.distribution.distribution.map((d) => d.bin).toList();
    final minBin = 1; // Include bin 0 (new/unpracticed lemmas)
    final maxBinInData = binsInData.isEmpty ? 7 : binsInData.reduce((a, b) => a > b ? a : b);
    final maxBin = maxBinInData > 7 ? maxBinInData : 7;
    
    // Create a map of bin -> LeitnerBinData for quick lookup
    final binDataMap = <int, LeitnerBinData>{};
    for (final binData in widget.distribution.distribution) {
      binDataMap[binData.bin] = binData;
    }
    
    // Create complete list of bins with counts (0 for missing bins)
    final completeDistribution = <LeitnerBinData>[];
    for (int bin = minBin; bin <= maxBin; bin++) {
      final existingBinData = binDataMap[bin];
      if (existingBinData != null) {
        completeDistribution.add(existingBinData);
      } else {
        completeDistribution.add(
          LeitnerBinData(
            bin: bin,
            count: 0,
            countDue: 0,
            countNotDue: 0,
          ),
        );
      }
    }
    
    // Find max count for scaling (only from actual data, not zeros)
    // Use the total count for each bin (should equal countDue + countNotDue)
    final maxCount = completeDistribution
        .where((d) => d.count > 0)
        .map((d) => d.count)
        .fold(0, (a, b) => a > b ? a : b);

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
            Row(
              children: [
                Text(
                  emoji,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Leitner Bins - $languageName',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: _isRecomputing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.refresh,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                  onPressed: _isRecomputing ? null : _handleRecompute,
                  tooltip: 'Recompute SRS',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount > 0 ? maxCount * 1.1 : 10, // Add 10% padding
                  minY: 0,
                  groupsSpace: 4,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(context).colorScheme.surface,
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final binValue = group.x.toInt();
                        final binData = completeDistribution.firstWhere(
                          (d) => d.bin == binValue,
                          orElse: () => LeitnerBinData(bin: binValue, count: 0),
                        );
                        
                        final totalCount = binData.count;
                        final countNotDue = binData.countNotDue;
                        final countDue = binData.countDue;
                        
                        // Check if breakdown is available (if both are 0 but count > 0, breakdown isn't available)
                        final hasBreakdown = !(countNotDue == 0 && countDue == 0 && totalCount > 0);
                        
                        if (!hasBreakdown) {
                          // Fallback: show total count
                          return BarTooltipItem(
                            '$totalCount lemmas',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        
                        // For stacked bars, show both segments in tooltip
                        return BarTooltipItem(
                          'Done: ${countNotDue}\nDue: ${countDue}\nTotal: $totalCount',
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          // Show labels for all bins in range
                          final binValue = value.toInt();
                          if (binValue >= minBin && binValue <= maxBin) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Bin $binValue',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 40,
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
                  barGroups: completeDistribution.map((binData) {
                    // Pastel dark green for not due (next_review_at after current time)
                    const pastelDarkGreen = Color(0xFF7CB342); // Pastel dark green
                    // Pastel dark orange for due (next_review_at before current time)
                    const pastelDarkOrange = Color(0xFFF57C00); // Pastel dark orange
                    
                    // Use breakdown if available, otherwise fall back to total count
                    final totalCount = binData.count.toDouble();
                    final countNotDue = binData.countNotDue.toDouble();
                    final countDue = binData.countDue.toDouble();
                    
                    // If breakdown is not available (both are 0 but count > 0), use total count as not due
                    final effectiveCountNotDue = (countNotDue == 0 && countDue == 0 && totalCount > 0)
                        ? totalCount
                        : countNotDue;
                    final effectiveCountDue = (countNotDue == 0 && countDue == 0 && totalCount > 0)
                        ? 0.0
                        : countDue;
                    
                    // Create stacked rod items
                    final rodStackItems = <BarChartRodStackItem>[];
                    
                    // Bottom segment: not due (green)
                    if (effectiveCountNotDue > 0) {
                      rodStackItems.add(
                        BarChartRodStackItem(
                          0,
                          effectiveCountNotDue,
                          pastelDarkGreen,
                        ),
                      );
                    }
                    
                    // Top segment: due (orange)
                    if (effectiveCountDue > 0) {
                      rodStackItems.add(
                        BarChartRodStackItem(
                          effectiveCountNotDue,
                          effectiveCountNotDue + effectiveCountDue,
                          pastelDarkOrange,
                        ),
                      );
                    }
                    
                    return BarChartGroupData(
                      x: binData.bin, // Use actual bin number as x value
                      barRods: [
                        BarChartRodData(
                          toY: effectiveCountNotDue + effectiveCountDue,
                          fromY: 0,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          rodStackItems: rodStackItems,
                        ),
                      ],
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

