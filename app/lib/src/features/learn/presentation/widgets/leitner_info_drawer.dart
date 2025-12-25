import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:archipelago/src/features/profile/data/statistics_service.dart';
import 'package:archipelago/src/features/profile/data/auth_service.dart';
import 'package:archipelago/src/features/shared/domain/user.dart';
import 'package:archipelago/src/features/shared/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Callback type for when Leitner config is updated
/// Parameters: (maxBins, algorithm, intervalStartHours)
typedef LeitnerConfigUpdatedCallback = void Function(int maxBins, String algorithm, int intervalStartHours);

/// Widget displaying information about Leitner bins in a bottom sheet drawer.
class LeitnerInfoDrawer extends StatefulWidget {
  final int userId;
  final int maxBins;
  final String algorithm;
  final int intervalStartHours;
  final VoidCallback? onRefresh;
  final LeitnerConfigUpdatedCallback? onConfigUpdated;

  const LeitnerInfoDrawer({
    super.key,
    required this.userId,
    required this.maxBins,
    required this.algorithm,
    required this.intervalStartHours,
    this.onRefresh,
    this.onConfigUpdated,
  });

  @override
  State<LeitnerInfoDrawer> createState() => _LeitnerInfoDrawerState();
}

class _LeitnerInfoDrawerState extends State<LeitnerInfoDrawer> {
  bool _isRecomputing = false;
  
  // Local state for configuration (to update UI immediately)
  late int _localMaxBins;
  late String _localAlgorithm;
  late int _localIntervalStartHours;
  
  // Callback to update modal state
  StateSetter? _modalStateSetter;
  
  // Delete data confirmation state
  bool _showDeleteConfirmation = false;
  bool _isDeletingData = false;
  
  @override
  void initState() {
    super.initState();
    _localMaxBins = widget.maxBins;
    _localAlgorithm = widget.algorithm;
    _localIntervalStartHours = widget.intervalStartHours;
  }
  
  @override
  void didUpdateWidget(LeitnerInfoDrawer oldWidget) {
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

  Future<void> _handleRecompute() async {
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
          
          // Notify parent to refresh user data with updated config values
          widget.onConfigUpdated?.call(
            _localMaxBins,
            _localAlgorithm,
            _localIntervalStartHours,
          );
          
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

  Widget _buildDeleteDataButton(BuildContext context, StateSetter setModalState) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isLoggedIn;
    
    if (!isLoggedIn) {
      return const SizedBox.shrink();
    }
    
    if (_showDeleteConfirmation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete all data?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isDeletingData)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _showDeleteConfirmation = false;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _isDeletingData
                        ? null
                        : () async {
                            setModalState(() {
                              _isDeletingData = true;
                            });
                            
                            try {
                              final result = await authProvider.deleteUserData();
                              
                              if (mounted) {
                                if (result['success'] == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['message'] as String),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  // Close the drawer after successful deletion
                                  Navigator.of(context).pop();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result['message'] as String),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error deleting data: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setModalState(() {
                                  _isDeletingData = false;
                                  _showDeleteConfirmation = false;
                                });
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }
    
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _showDeleteConfirmation = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              'Delete all data',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
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
                        const SizedBox(height: 32),
                        // Delete data button at the bottom
                        _buildDeleteDataButton(context, setModalState),
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Helper function to show the Leitner info drawer
void showLeitnerInfoDrawer({
  required BuildContext context,
  required int userId,
  required int maxBins,
  required String algorithm,
  required int intervalStartHours,
  VoidCallback? onRefresh,
  LeitnerConfigUpdatedCallback? onConfigUpdated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (context) => LeitnerInfoDrawer(
      userId: userId,
      maxBins: maxBins,
      algorithm: algorithm,
      intervalStartHours: intervalStartHours,
      onRefresh: onRefresh,
      onConfigUpdated: onConfigUpdated,
    ),
  );
}

