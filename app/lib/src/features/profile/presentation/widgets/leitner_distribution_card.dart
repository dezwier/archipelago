import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';

/// Widget displaying Leitner bin distribution as a bar chart.
class LeitnerDistributionCard extends StatelessWidget {
  final LeitnerDistribution distribution;
  final List<Language> languages;

  const LeitnerDistributionCard({
    super.key,
    required this.distribution,
    required this.languages,
  });

  String _getLanguageName(String code) {
    final language = languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Language(code: code, name: code.toUpperCase()),
    );
    return language.name;
  }

  @override
  Widget build(BuildContext context) {
    if (distribution.distribution.isEmpty) {
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
                'Leitner Distribution - ${_getLanguageName(distribution.languageCode)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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

    final emoji = LanguageEmoji.getEmoji(distribution.languageCode);
    final languageName = _getLanguageName(distribution.languageCode);
    
    // Determine bin range: minimum 0-7, extend if higher bins exist
    final binsInData = distribution.distribution.map((d) => d.bin).toList();
    final minBin = 1;
    final maxBinInData = binsInData.isEmpty ? 7 : binsInData.reduce((a, b) => a > b ? a : b);
    final maxBin = maxBinInData > 7 ? maxBinInData : 7;
    
    // Create a map of bin -> count for quick lookup
    final binCountMap = <int, int>{};
    for (final binData in distribution.distribution) {
      binCountMap[binData.bin] = binData.count;
    }
    
    // Create complete list of bins with counts (0 for missing bins)
    final completeDistribution = <LeitnerBinData>[];
    for (int bin = minBin; bin <= maxBin; bin++) {
      completeDistribution.add(
        LeitnerBinData(
          bin: bin,
          count: binCountMap[bin] ?? 0,
        ),
      );
    }
    
    // Find max count for scaling (only from actual data, not zeros)
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
                    'Leitner Distribution - $languageName',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
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
                        final count = completeDistribution.firstWhere(
                          (d) => d.bin == binValue,
                          orElse: () => LeitnerBinData(bin: binValue, count: 0),
                        ).count;
                        return BarTooltipItem(
                          '$count lemmas',
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
                    return BarChartGroupData(
                      x: binData.bin, // Use actual bin number as x value
                      barRods: [
                        BarChartRodData(
                          toY: binData.count.toDouble(),
                          color: binData.count > 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Distribution of lemmas across Leitner bins',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

