/// Streak History Screen
///
/// Beautiful visualization of streak history
/// Features:
/// - 30-day bar chart showing task completions
/// - Current streak highlighted
/// - Longest streak marker
/// - Streak breaks (red markers)
/// - Tap bars for day details
/// - Summary stats at top

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/gamification_models.dart';
import '../../api/gamification_client.dart';

class StreakHistoryScreen extends StatefulWidget {
  final String userId;

  const StreakHistoryScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<StreakHistoryScreen> createState() => _StreakHistoryScreenState();
}

class _StreakHistoryScreenState extends State<StreakHistoryScreen> {
  final _client = GamificationClient.instance;

  StreakHistory? _history;
  bool _loading = true;
  String? _error;
  int? _selectedDayIndex;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final history = await _client.getStreakHistory(widget.userId);
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streak History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(theme, colorScheme)
              : _history == null
                  ? _buildEmptyState(theme, colorScheme)
                  : _buildHistoryContent(theme, colorScheme),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load history',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_error!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('No history yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Complete tasks to start building your streak history!',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent(ThemeData theme, ColorScheme colorScheme) {
    final history = _history!;

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stats
            _buildSummaryStats(history, theme, colorScheme),
            const SizedBox(height: 24),

            // Bar chart
            Text(
              'Last 30 Days',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBarChart(history, theme, colorScheme),
            const SizedBox(height: 24),

            // Selected day details
            if (_selectedDayIndex != null) ...[
              _buildDayDetails(history, theme, colorScheme),
              const SizedBox(height: 16),
            ],

            // Legend
            _buildLegend(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats(
    StreakHistory history,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.local_fire_department,
                    label: 'Current',
                    value: '${history.currentStreak}',
                    color: Colors.orange,
                    theme: theme,
                  ),
                ),
                Container(width: 1, height: 40, color: colorScheme.outline),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.emoji_events,
                    label: 'Longest',
                    value: '${history.longestStreak}',
                    color: Colors.amber,
                    theme: theme,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.calendar_today,
                    label: 'Active Days',
                    value: '${history.totalDaysWithTasks}',
                    color: Colors.blue,
                    theme: theme,
                  ),
                ),
                Container(width: 1, height: 40, color: colorScheme.outline),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.shield,
                    label: 'Saves',
                    value: '${history.streakSaveCount}',
                    color: Colors.green,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(
    StreakHistory history,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (history.days.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('No data to display')),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxY(history.days),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (response != null &&
                      response.spot != null &&
                      event is FlTapUpEvent) {
                    setState(() {
                      _selectedDayIndex = response.spot!.touchedBarGroupIndex;
                    });
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: colorScheme.surfaceContainerHighest,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = history.days[groupIndex];
                    return BarTooltipItem(
                      '${DateFormat('MMM d').format(day.date)}\n${day.tasksCompleted} tasks',
                      TextStyle(
                        color: colorScheme.onSurfaceVariant,
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
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= history.days.length) {
                        return const SizedBox.shrink();
                      }
                      final day = history.days[value.toInt()];
                      // Show every 5th day
                      if (value.toInt() % 5 == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat('M/d').format(day.date),
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: theme.textTheme.bodySmall,
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
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: colorScheme.outline),
                  left: BorderSide(color: colorScheme.outline),
                ),
              ),
              barGroups: _buildBarGroups(history, colorScheme),
            ),
          ),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(
    StreakHistory history,
    ColorScheme colorScheme,
  ) {
    return List.generate(history.days.length, (index) {
      final day = history.days[index];
      final color = _getBarColor(day, colorScheme);

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: day.tasksCompleted.toDouble(),
            color: color,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });
  }

  Color _getBarColor(StreakHistoryDay day, ColorScheme colorScheme) {
    if (day.isToday) {
      return Colors.purple;
    } else if (day.isStreakDay) {
      return Colors.orange;
    } else if (day.tasksCompleted > 0) {
      return Colors.blue;
    } else {
      return colorScheme.surfaceContainerHighest;
    }
  }

  double _getMaxY(List<StreakHistoryDay> days) {
    if (days.isEmpty) return 5;
    final maxTasks =
        days.map((d) => d.tasksCompleted).reduce((a, b) => a > b ? a : b);
    return (maxTasks + 1).toDouble();
  }

  Widget _buildDayDetails(
    StreakHistory history,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final day = history.days[_selectedDayIndex!];

    return Card(
      elevation: 2,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(day.date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedDayIndex = null),
                  color: colorScheme.onPrimaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.task_alt,
                  color: colorScheme.onPrimaryContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${day.tasksCompleted} tasks completed',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            if (day.isStreakDay) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Part of current streak',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
            if (day.isToday) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.today,
                    color: Colors.purple.shade300,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Today',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Legend',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildLegendItem(
              color: Colors.purple,
              label: 'Today',
              theme: theme,
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: Colors.orange,
              label: 'Streak day',
              theme: theme,
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: Colors.blue,
              label: 'Tasks completed (no streak)',
              theme: theme,
            ),
            const SizedBox(height: 8),
            _buildLegendItem(
              color: colorScheme.surfaceContainerHighest,
              label: 'No tasks (streak break)',
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
