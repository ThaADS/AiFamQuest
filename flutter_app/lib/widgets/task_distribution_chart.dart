import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/fairness_models.dart';

/// Task distribution pie chart widget
///
/// Shows percentage of tasks completed by each family member
/// Interactive: Tap slice to filter to user's tasks
class TaskDistributionChart extends StatefulWidget {
  final Map<String, int> distribution; // userId -> task count
  final Map<String, UserWorkload> workloads;
  final Function(String userId)? onUserSelected;

  const TaskDistributionChart({
    super.key,
    required this.distribution,
    required this.workloads,
    this.onUserSelected,
  });

  @override
  State<TaskDistributionChart> createState() => _TaskDistributionChartState();
}

class _TaskDistributionChartState extends State<TaskDistributionChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.distribution.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No task data available',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final total = widget.distribution.values.reduce((a, b) => a + b);
    if (total == 0) {
      return Center(
        child: Text(
          'No completed tasks yet',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Distribution',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.3,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: _buildSections(total),
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(theme, total),
          ],
        ),
      ),
    );
  }

  /// Build pie chart sections
  List<PieChartSectionData> _buildSections(int total) {
    final entries = widget.distribution.entries.toList();
    final colors = _generateColors(entries.length);

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final percentage = (entry.value / total * 100);
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 110.0 : 100.0;
      final fontSize = isTouched ? 18.0 : 16.0;

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toInt()}%',
        color: colors[index],
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
            ),
          ],
        ),
      );
    });
  }

  /// Build legend with user names and colors
  Widget _buildLegend(ThemeData theme, int total) {
    final entries = widget.distribution.entries.toList();
    final colors = _generateColors(entries.length);

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final workload = widget.workloads[entry.key];
        final percentage = (entry.value / total * 100).toInt();
        final userName = workload?.userName ?? 'Unknown';

        return InkWell(
          onTap: widget.onUserSelected != null
              ? () => widget.onUserSelected!(entry.key)
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$userName ($percentage%)',
                  style: theme.textTheme.bodyMedium,
                ),
                if (widget.onUserSelected != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Generate distinct colors for pie slices
  List<Color> _generateColors(int count) {
    final baseColors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
      Colors.indigo.shade600,
      Colors.amber.shade600,
    ];

    if (count <= baseColors.length) {
      return baseColors.take(count).toList();
    }

    // Generate more colors if needed
    final colors = <Color>[];
    for (int i = 0; i < count; i++) {
      colors.add(baseColors[i % baseColors.length]);
    }
    return colors;
  }
}
