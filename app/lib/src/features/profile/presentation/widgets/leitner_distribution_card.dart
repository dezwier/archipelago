import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:archipelago/src/features/profile/domain/statistics.dart';
import 'package:archipelago/src/features/profile/domain/language.dart';
import 'package:archipelago/src/utils/language_emoji.dart';
import 'package:archipelago/src/features/profile/data/statistics_service.dart';
import 'package:archipelago/src/features/profile/data/auth_service.dart';
import 'package:archipelago/src/features/profile/domain/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Widget displaying Leitner bin distribution as a bar chart.
class LeitnerDistributionCard extends StatefulWidget {
  final LeitnerDistribution distribution;
  final List<Language> languages;
  final int userId;
  final VoidCallback? onRefresh;
  final int maxBins;
  final String algorithm;
  final int intervalStartHours;
  final VoidCallback? onConfigUpdated;

  const LeitnerDistributionCard({
    super.key,
    required this.distribution,
    required this.languages,
    required this.userId,
    this.onRefresh,
    this.maxBins = 7,
    this.algorithm = 'fibonacci',
    this.intervalStartHours = 23,
    this.onConfigUpdated,
  });

  @override
  State<LeitnerDistributionCard> createState() => _LeitnerDistributionCardState();
}

class _LeitnerDistributionCardState extends State<LeitnerDistributionCard> {
  bool _isRecomputing = false;
  
  // Local state for configuration (to update UI immediately)
  late int _localMaxBins;
  late String _localAlgorithm;
  late int _localIntervalStartHours;
  
  // Callback to update modal state
  StateSetter? _modalStateSetter;
  
  @override
  void initState() {
    super.initState();
    _localMaxBins = widget.maxBins;
    _localAlgorithm = widget.algorithm;
    _localIntervalStartHours = widget.intervalStartHours;
  }
  
  @override
  void didUpdateWidget(LeitnerDistributionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxBins != widget.maxBins) {
      _localMaxBins = widget.maxBins;
    }
    if (oldWidget.algorithm != widget.algorithm) {
      _localAlgorithm = widget.algorithm;
    }
    if (oldWidget.intervalStartHours != widget.intervalStartHours) {
      _localIntervalStartHours = widget.intervalStartHours;
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  String _getLanguageName(String code) {
    final language = widget.languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => Language(code: code, name: code.toUpperCase()),
    );
    return language.name;
  }

  /// Calculate Fibonacci interval for a given bin number
  int _calculateFibonacciInterval(int binNumber, int intervalStartHours) {
    if (binNumber <= 0) return intervalStartHours;
    if (binNumber == 1) return intervalStartHours;
    if (binNumber == 2) return intervalStartHours;
    
    int fibPrev = intervalStartHours;
    int fibCurr = intervalStartHours;
    
    for (int i = 3; i <= binNumber; i++) {
      final fibNext = fibPrev + fibCurr;
      fibPrev = fibCurr;
      fibCurr = fibNext;
    }
    
    return fibCurr;
  }

  /// Format hours to a human-readable string with 2 most significant intervals
  String _formatInterval(int hours) {
    final parts = <String>[];
    
    // Calculate all time units
    final totalMonths = hours ~/ 720;
    final remainingAfterMonths = hours % 720;
    final totalWeeks = remainingAfterMonths ~/ 168;
    final remainingAfterWeeks = remainingAfterMonths % 168;
    final totalDays = remainingAfterWeeks ~/ 24;
    final remainingHours = remainingAfterWeeks % 24;
    
    // Add the 2 most significant non-zero units
    if (totalMonths > 0) {
      parts.add('$totalMonths ${totalMonths == 1 ? 'month' : 'months'}');
      if (parts.length < 2 && totalWeeks > 0) {
        parts.add('$totalWeeks ${totalWeeks == 1 ? 'week' : 'weeks'}');
      } else if (parts.length < 2 && totalDays > 0) {
        parts.add('$totalDays ${totalDays == 1 ? 'day' : 'days'}');
      } else if (parts.length < 2 && remainingHours > 0) {
        parts.add('$remainingHours ${remainingHours == 1 ? 'hour' : 'hours'}');
      }
    } else if (totalWeeks > 0) {
      parts.add('$totalWeeks ${totalWeeks == 1 ? 'week' : 'weeks'}');
      if (parts.length < 2 && totalDays > 0) {
        parts.add('$totalDays ${totalDays == 1 ? 'day' : 'days'}');
      } else if (parts.length < 2 && remainingHours > 0) {
        parts.add('$remainingHours ${remainingHours == 1 ? 'hour' : 'hours'}');
      }
    } else if (totalDays > 0) {
      parts.add('$totalDays ${totalDays == 1 ? 'day' : 'days'}');
      if (parts.length < 2 && remainingHours > 0) {
        parts.add('$remainingHours ${remainingHours == 1 ? 'hour' : 'hours'}');
      }
    } else {
      // Only hours
      parts.add('$remainingHours ${remainingHours == 1 ? 'hour' : 'hours'}');
    }
    
    return parts.join(' ');
  }

  void _showInfoDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Store modal state setter for later use
          _modalStateSetter = setModalState;
          return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header with title and refresh button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'About Leitner Bins',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: _isRecomputing ? null : _handleRecompute,
                        tooltip: 'Recompute SRS',
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // What is Leitner system
                        Text(
                          'What is the Leitner System?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The Leitner System is a spaced repetition learning method. Cards are organized into bins based on how well you know them. When you answer correctly, cards move to higher bins with longer review intervals. When you answer incorrectly, cards move to lower bins for more frequent review.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        // Number of bins
                        Text(
                          'Your Configuration',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildEditableField(
                          'Number of Bins',
                          'maxBins',
                          setModalState: setModalState,
                        ),
                        _buildEditableField(
                          'Starting Interval',
                          'intervalStart',
                          setModalState: setModalState,
                        ),
                        _buildEditableField(
                          'Algorithm',
                          'algorithm',
                          setModalState: setModalState,
                        ),
                        const SizedBox(height: 24),
                        // Review intervals
                        Text(
                          'Review Intervals',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(_localMaxBins, (index) {
                          final binNumber = index + 1;
                          final intervalHours = _calculateFibonacciInterval(binNumber, _localIntervalStartHours);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bin $binNumber',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatInterval(intervalHours),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        // How it works
                        Text(
                          'How It Works',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• New cards start in Bin 1\n'
                          '• Correct answers move cards to the next bin\n'
                          '• Incorrect answers move cards down by 2 bins (minimum Bin 1)\n'
                          '• Using hints keeps cards in the same bin\n'
                          '• Higher bins have longer review intervals',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  Widget _buildEditableField(String label, String fieldKey, {StateSetter? setModalState}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (fieldKey == 'algorithm') ...[
                  DropdownButton<String>(
                    value: _localAlgorithm,
                    items: const [
                      DropdownMenuItem(value: 'fibonacci', child: Text('Fibonacci')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _localAlgorithm = value;
                        });
                        setModalState?.call(() {}); // Update modal state
                        _handleSaveDirectly('algorithm', value);
                      }
                    },
                  ),
                ] else if (fieldKey == 'maxBins') ...[
                  DropdownButton<int>(
                    value: _localMaxBins,
                    items: List.generate(16, (index) {
                      final value = index + 5; // 5 to 20
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _localMaxBins = value;
                        });
                        setModalState?.call(() {}); // Update modal state
                        _handleSaveDirectly('maxBins', value.toString());
                      }
                    },
                  ),
                ] else if (fieldKey == 'intervalStart') ...[
                  DropdownButton<int>(
                    value: _localIntervalStartHours,
                    items: List.generate(24, (index) {
                      final value = index + 1; // 1 to 24
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _localIntervalStartHours = value;
                        });
                        setModalState?.call(() {}); // Update modal state
                        _handleSaveDirectly('intervalStart', value.toString());
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveDirectly(String fieldKey, String value) async {
    
    try {
      int? maxBins;
      String? algorithm;
      int? intervalStartHours;
      
      if (fieldKey == 'maxBins') {
        final intValue = int.tryParse(value);
        if (intValue == null || intValue < 5 || intValue > 20) {
          throw Exception('Must be between 5 and 20');
        }
        maxBins = intValue;
      } else if (fieldKey == 'algorithm') {
        if (value != 'fibonacci') {
          throw Exception('Only Fibonacci is supported');
        }
        algorithm = value;
      } else if (fieldKey == 'intervalStart') {
        final intValue = int.tryParse(value);
        if (intValue == null || intValue < 1 || intValue > 24) {
          throw Exception('Must be between 1 and 24 hours');
        }
        intervalStartHours = intValue;
      }
      
      final result = await AuthService.updateLeitnerConfig(
        widget.userId,
        maxBins,
        algorithm,
        intervalStartHours,
      );
      
      if (mounted) {
        if (result['success'] == true) {
          // Update local state
          if (maxBins != null) {
            _localMaxBins = maxBins;
          }
          if (algorithm != null) {
            _localAlgorithm = algorithm;
          }
          if (intervalStartHours != null) {
            _localIntervalStartHours = intervalStartHours;
          }
          
          // Update modal state to reflect changes
          _modalStateSetter?.call(() {});
          
          // Save updated user to SharedPreferences
          try {
            final updatedUser = result['user'] as User;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('current_user', jsonEncode(updatedUser.toJson()));
          } catch (e) {
            // Ignore save errors
          }
          
          // Notify parent to refresh user data
          widget.onConfigUpdated?.call();
          
          // Recompute SRS after configuration update
          setState(() {
            _isRecomputing = true;
          });
          
          try {
            final recomputeResult = await StatisticsService.recomputeSRS(
              userId: widget.userId,
            );
            
            if (mounted) {
              setState(() {
                _isRecomputing = false;
              });
              
              if (recomputeResult['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Configuration updated and SRS recomputed successfully'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
                // Refresh the data
                widget.onRefresh?.call();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Configuration updated, but SRS recomputation failed: ${recomputeResult['message']}'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _isRecomputing = false;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Configuration updated, but SRS recomputation error: ${e.toString()}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String? ?? 'Failed to update configuration'),
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
    }
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
                    icon: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: _showInfoDrawer,
                    tooltip: 'About Leitner Bins',
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
    
    // Always show bins from 1 to user's max_bins
    final minBin = 1;
    final maxBin = _localMaxBins;
    
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    'Leitner Bins',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  onPressed: _showInfoDrawer,
                  tooltip: 'About Leitner Bins',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                                'B$binValue',
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

