import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/study_models.dart';
import '../../api/client.dart';
import 'spaced_repetition_scheduler.dart';

/// Study Item Detail Screen
///
/// Shows comprehensive view of a study item with:
/// - AI-generated backward plan
/// - All scheduled sessions with completion status
/// - Quick access to today's quiz
/// - Progress chart (sessions completed vs total)
/// - Study statistics
class StudyItemDetailScreen extends StatefulWidget {
  final String studyItemId;

  const StudyItemDetailScreen({
    super.key,
    required this.studyItemId,
  });

  @override
  State<StudyItemDetailScreen> createState() => _StudyItemDetailScreenState();
}

class _StudyItemDetailScreenState extends State<StudyItemDetailScreen> {
  StudyItem? _studyItem;
  List<StudySession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final item = await ApiClient.getStudyItem(widget.studyItemId);
      final sessions = await ApiClient.getStudySessions(widget.studyItemId);

      setState(() {
        _studyItem = item;
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load study item: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  int get _completedSessions => _sessions.where((s) => s.completed).length;
  double get _progressPercentage =>
      _sessions.isEmpty ? 0 : _completedSessions / _sessions.length;

  StudySession? get _todaySession {
    return _sessions.firstWhere(
      (s) => !s.completed && SpacedRepetitionScheduler.isDueToday(s),
      orElse: () => _sessions.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Item')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_studyItem == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Item')),
        body: const Center(child: Text('Study item not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_studyItem!.subject),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Study Item'),
                    content: const Text(
                      'Are you sure? This will delete all sessions and progress.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  try {
                    await ApiClient.deleteStudyItem(widget.studyItemId);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Study item deleted'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            _buildHeaderCard(),

            // Progress Chart
            _buildProgressChart(),

            // AI Plan Section
            _buildAIPlanSection(),

            // Today's Session Quick Access
            if (_todaySession != null) _buildTodaySessionCard(),

            // Milestones
            if (_studyItem!.studyPlan.milestones.isNotEmpty)
              _buildMilestonesSection(),

            // All Sessions List
            _buildSessionsList(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: _todaySession != null &&
              !_todaySession!.completed &&
              SpacedRepetitionScheduler.isDueToday(_todaySession!)
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/study/session-detail',
                  arguments: _todaySession!.id,
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Today\'s Session'),
            )
          : null,
    );
  }

  Widget _buildHeaderCard() {
    final daysUntilTest = _studyItem!.testDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.school,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _studyItem!.subject,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _studyItem!.topic,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    icon: Icons.calendar_today,
                    label: 'Test Date',
                    value: DateFormat('MMM d, y').format(_studyItem!.testDate),
                    subtitle: '$daysUntilTest days left',
                    color: daysUntilTest <= 3 ? Colors.red : Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatChip(
                    icon: Icons.trending_up,
                    label: 'Difficulty',
                    value: _studyItem!.difficulty.displayName,
                    subtitle: _studyItem!.difficulty.emoji,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    icon: Icons.event_note,
                    label: 'Sessions',
                    value: '$_completedSessions / ${_sessions.length}',
                    subtitle: 'completed',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatChip(
                    icon: Icons.emoji_events,
                    label: 'Status',
                    value: _studyItem!.status.displayName,
                    subtitle: _studyItem!.status.emoji,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: _sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No data yet',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: _completedSessions.toDouble(),
                            title: '$_completedSessions\nCompleted',
                            color: Colors.green,
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            value: (_sessions.length - _completedSessions).toDouble(),
                            title: '${_sessions.length - _completedSessions}\nRemaining',
                            color: Colors.grey[300],
                            radius: 80,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progressPercentage,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _progressPercentage >= 0.8 ? Colors.green : Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progressPercentage * 100).toInt()}% Complete',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIPlanSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.auto_awesome, color: Colors.amber),
          title: const Text(
            'AI Study Plan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${_studyItem!.studyPlan.plan.length} sessions • ${_studyItem!.studyPlan.totalEstimatedHours.toStringAsFixed(1)} hours',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Confidence Score
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AI Confidence',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(_studyItem!.studyPlan.confidenceScore * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Plan Sessions
                  ..._studyItem!.studyPlan.plan.asMap().entries.map((entry) {
                    final index = entry.key;
                    final session = entry.value;
                    final isCompleted = _sessions.length > index &&
                        _sessions[index].completed;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCompleted ? Colors.green : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isCompleted ? Colors.green : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCompleted ? Icons.check : Icons.event,
                                size: 16,
                                color: isCompleted ? Colors.white : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Session ${index + 1}: ${session.focus}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${session.date} • ${session.duration} min',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySessionCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.amber.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/study/session-detail',
            arguments: _todaySession!.id,
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.today, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Session',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _todaySession!.focus,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/study/session-detail',
                    arguments: _todaySession!.id,
                  ).then((_) => _loadData());
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestonesSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Milestones',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._studyItem!.studyPlan.milestones.map((milestone) {
              final milestoneDate = DateTime.parse(milestone.date);
              final isPast = milestoneDate.isBefore(DateTime.now());

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      isPast ? Icons.check_circle : Icons.flag,
                      color: isPast ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            milestone.checkpoint,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d').format(milestoneDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Sessions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ..._sessions.asMap().entries.map((entry) {
              final index = entry.key;
              final session = entry.value;
              final isToday = SpacedRepetitionScheduler.isDueToday(session);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: session.completed
                        ? Colors.green
                        : isToday
                            ? Colors.amber
                            : Colors.grey[300],
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: session.completed || isToday ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    session.focus,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${DateFormat('MMM d').format(session.scheduledAt)} • ${session.duration} min',
                  ),
                  trailing: session.completed
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : isToday
                          ? const Chip(
                              label: Text('Today', style: TextStyle(fontSize: 10)),
                              backgroundColor: Colors.amber,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                            )
                          : null,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/study/session-detail',
                      arguments: session.id,
                    ).then((_) => _loadData());
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
