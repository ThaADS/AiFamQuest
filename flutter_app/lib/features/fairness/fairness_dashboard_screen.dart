import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/fairness_models.dart';
import '../../widgets/capacity_bar.dart';
import '../../widgets/task_distribution_chart.dart';
import '../../widgets/fairness_insights_card.dart';
import 'fairness_provider.dart';

/// Fairness Dashboard - Main screen showing workload distribution
///
/// Features:
/// - Family workload balance overview
/// - Individual capacity bars
/// - Task distribution pie chart
/// - AI-generated fairness insights
/// - Date range filtering
/// - Rebalance action
class FairnessDashboardScreen extends ConsumerWidget {
  const FairnessDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedDateRangeProvider);
    final fairnessAsync = ref.watch(fairnessProvider(selectedRange));
    final insightsAsync = ref.watch(fairnessInsightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workload Balance'),
        elevation: 0,
      ),
      body: fairnessAsync.when(
        data: (fairnessData) => _buildDashboard(
          context,
          ref,
          fairnessData,
          insightsAsync,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load fairness data',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(fairnessProvider(ref.read(selectedDateRangeProvider))),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    FairnessData fairnessData,
    AsyncValue<List<String>> insightsAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(fairnessProvider);
        ref.invalidate(fairnessInsightsProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, ref, fairnessData),
            const SizedBox(height: 24),
            _buildCapacityBars(context, fairnessData),
            const SizedBox(height: 24),
            TaskDistributionChart(
              distribution: fairnessData.taskDistribution,
              workloads: fairnessData.workloads,
              onUserSelected: (userId) {
                // TODO: Navigate to user's task list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Filter tasks by ${fairnessData.workloads[userId]?.userName ?? "user"}'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            insightsAsync.when(
              data: (insights) => FairnessInsightsCard(
                insights: insights,
                onRebalance: () => _handleRebalance(context),
              ),
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => FairnessInsightsCard(
                insights: const ['Unable to load insights'],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Build header with fairness score and date range selector
  Widget _buildHeader(BuildContext context, WidgetRef ref, FairnessData fairnessData) {
    final theme = Theme.of(context);
    final selectedRange = ref.watch(selectedDateRangeProvider);
    final status = fairnessData.status;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fairness Score',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${(fairnessData.fairnessScore * 100).toInt()}%',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(theme, status),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status),
                    size: 32,
                    color: _getStatusColor(status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            // Date range selector
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time Period:',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<DateRange>(
                    segments: DateRange.values
                        .map((range) => ButtonSegment(
                              value: range,
                              label: Text(
                                range.label,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    selected: {selectedRange},
                    onSelectionChanged: (Set<DateRange> newSelection) {
                      ref.read(selectedDateRangeProvider.notifier).state = newSelection.first;
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build capacity bars for all family members
  Widget _buildCapacityBars(BuildContext context, FairnessData fairnessData) {
    final sortedWorkloads = fairnessData.sortedWorkloads;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Family Workload',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...sortedWorkloads.map((workload) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: CapacityBar(
                workload: workload,
                onTap: () {
                  // TODO: Navigate to user's profile or task list
                },
              ),
            )),
      ],
    );
  }

  /// Get color based on fairness status
  Color _getStatusColor(FairnessStatus status) {
    switch (status) {
      case FairnessStatus.excellent:
        return Colors.green;
      case FairnessStatus.good:
        return Colors.blue;
      case FairnessStatus.fair:
        return Colors.orange;
      case FairnessStatus.unbalanced:
        return Colors.red;
    }
  }

  /// Get icon based on fairness status
  IconData _getStatusIcon(FairnessStatus status) {
    switch (status) {
      case FairnessStatus.excellent:
        return Icons.emoji_events;
      case FairnessStatus.good:
        return Icons.thumb_up;
      case FairnessStatus.fair:
        return Icons.balance;
      case FairnessStatus.unbalanced:
        return Icons.warning;
    }
  }

  /// Build status badge
  Widget _buildStatusBadge(ThemeData theme, FairnessStatus status) {
    String label;
    switch (status) {
      case FairnessStatus.excellent:
        label = 'Excellent';
        break;
      case FairnessStatus.good:
        label = 'Good';
        break;
      case FairnessStatus.fair:
        label = 'Fair';
        break;
      case FairnessStatus.unbalanced:
        label = 'Unbalanced';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: _getStatusColor(status),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Handle rebalance action
  void _handleRebalance(BuildContext context) {
    // TODO: Navigate to AI planner with fairness focus
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening AI Planner with fairness optimization...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
