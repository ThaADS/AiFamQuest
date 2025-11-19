import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../api/client.dart';
import '../../core/app_logger.dart';

/// Admin Revenue Dashboard
///
/// Displays:
/// - Total revenue (all time, this month)
/// - Active subscriptions count
/// - Conversion rates (free → paid)
/// - Churn rate
/// - Revenue chart (last 6 months)
///
/// Access: Admin role only
class RevenueDashboardScreen extends StatefulWidget {
  const RevenueDashboardScreen({super.key});

  @override
  State<RevenueDashboardScreen> createState() => _RevenueDashboardScreenState();
}

class _RevenueDashboardScreenState extends State<RevenueDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _subscriptions;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await ApiClient.instance.getRevenueStats();
      final subscriptions = await ApiClient.instance.getSubscriptionAnalytics();

      if (mounted) {
        setState(() {
          _stats = stats;
          _subscriptions = subscriptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.debug('[ADMIN] Error loading revenue data: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revenue Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError(theme)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Summary cards
                      _buildSummaryCards(theme),
                      const SizedBox(height: 24),

                      // Revenue chart
                      _buildRevenueChart(theme),
                      const SizedBox(height: 24),

                      // Subscription breakdown
                      _buildSubscriptionBreakdown(theme),
                      const SizedBox(height: 24),

                      // Conversion metrics
                      _buildConversionMetrics(theme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading revenue data',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final totalRevenue = _stats?['total_revenue'] ?? 0.0;
    final monthRevenue = _stats?['month_revenue'] ?? 0.0;
    // Note: activeSubscriptions and churnRate available in _subscriptions/_stats
    // but not displayed in summary cards (shown in detailed sections below)

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            'Total Revenue',
            '€${totalRevenue.toStringAsFixed(2)}',
            Icons.euro,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            theme,
            'This Month',
            '€${monthRevenue.toStringAsFixed(2)}',
            Icons.calendar_today,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(ThemeData theme) {
    final revenueData = _stats?['revenue_trend'] as List<dynamic>? ?? [];

    if (revenueData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Revenue Trend',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text('No data available'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend (Last 6 Months)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '€${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < revenueData.length) {
                            final month = revenueData[index]['month'] ?? '';
                            return Text(
                              month,
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
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
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: revenueData
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                                e.key.toDouble(),
                                (e.value['revenue'] ?? 0).toDouble(),
                              ))
                          .toList(),
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBreakdown(ThemeData theme) {
    final freeCount = _subscriptions?['free_count'] ?? 0;
    final familyUnlockCount = _subscriptions?['family_unlock_count'] ?? 0;
    final premiumMonthlyCount = _subscriptions?['premium_monthly_count'] ?? 0;
    final premiumYearlyCount = _subscriptions?['premium_yearly_count'] ?? 0;
    final totalActive = _subscriptions?['active_count'] ?? 1;
    // Note: activeSubscriptions and churnRate are calculated on backend

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subscription Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildSubscriptionRow(
              theme,
              'Free',
              freeCount,
              totalActive,
              Colors.grey,
            ),
            const SizedBox(height: 12),
            _buildSubscriptionRow(
              theme,
              'Family Unlock',
              familyUnlockCount,
              totalActive,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildSubscriptionRow(
              theme,
              'Premium Monthly',
              premiumMonthlyCount,
              totalActive,
              Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildSubscriptionRow(
              theme,
              'Premium Yearly',
              premiumYearlyCount,
              totalActive,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionRow(
    ThemeData theme,
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildConversionMetrics(ThemeData theme) {
    final conversionRate = _stats?['conversion_rate'] ?? 0.0;
    final churnRate = _stats?['churn_rate'] ?? 0.0;
    final avgRevenuePerUser = _stats?['avg_revenue_per_user'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conversion Metrics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              theme,
              'Conversion Rate (Free → Paid)',
              '${conversionRate.toStringAsFixed(1)}%',
              conversionRate >= 4.0 ? Colors.green : Colors.orange,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              theme,
              'Churn Rate',
              '${churnRate.toStringAsFixed(1)}%',
              churnRate <= 2.0 ? Colors.green : Colors.red,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              theme,
              'Average Revenue Per User',
              '€${avgRevenuePerUser.toStringAsFixed(2)}',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    ThemeData theme,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
