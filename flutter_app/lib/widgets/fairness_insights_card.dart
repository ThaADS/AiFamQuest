import 'package:flutter/material.dart';

/// Fairness insights card displaying AI-generated recommendations
///
/// Shows:
/// - Workload imbalance alerts
/// - Fairness improvement suggestions
/// - User performance highlights
class FairnessInsightsCard extends StatelessWidget {
  final List<String> insights;
  final VoidCallback? onRebalance;

  const FairnessInsightsCard({
    super.key,
    required this.insights,
    this.onRebalance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (insights.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Excellent Balance!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Workload is distributed fairly across all family members.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb,
                    color: Colors.amber.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fairness Insights',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onRebalance != null)
                  IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    onPressed: onRebalance,
                    tooltip: 'Rebalance Tasks',
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Insights list
            ...insights.asMap().entries.map((entry) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < insights.length - 1 ? 12.0 : 0.0,
                ),
                child: _buildInsightItem(context, entry.value),
              );
            }),
            // Rebalance button (if callback provided)
            if (onRebalance != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRebalance,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Rebalance Tasks'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build individual insight item
  Widget _buildInsightItem(BuildContext context, String insight) {
    final theme = Theme.of(context);

    // Detect insight type from content
    final InsightType type = _detectInsightType(insight);
    final icon = _getInsightIcon(type);
    final color = _getInsightColor(type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            insight,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Detect insight type from content
  InsightType _detectInsightType(String insight) {
    final lowerInsight = insight.toLowerCase();

    if (lowerInsight.contains('above') ||
        lowerInsight.contains('overload') ||
        lowerInsight.contains('too many')) {
      return InsightType.warning;
    }

    if (lowerInsight.contains('light') ||
        lowerInsight.contains('below') ||
        lowerInsight.contains('fewer')) {
      return InsightType.opportunity;
    }

    if (lowerInsight.contains('streak') ||
        lowerInsight.contains('completed all') ||
        lowerInsight.contains('100%')) {
      return InsightType.success;
    }

    return InsightType.info;
  }

  /// Get icon for insight type
  IconData _getInsightIcon(InsightType type) {
    switch (type) {
      case InsightType.warning:
        return Icons.warning_amber;
      case InsightType.opportunity:
        return Icons.trending_up;
      case InsightType.success:
        return Icons.emoji_events;
      case InsightType.info:
        return Icons.info;
    }
  }

  /// Get color for insight type
  Color _getInsightColor(InsightType type) {
    switch (type) {
      case InsightType.warning:
        return Colors.orange;
      case InsightType.opportunity:
        return Colors.blue;
      case InsightType.success:
        return Colors.green;
      case InsightType.info:
        return Colors.grey;
    }
  }
}

/// Insight type categories
enum InsightType {
  warning,
  opportunity,
  success,
  info,
}
