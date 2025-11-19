import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/study_models.dart';
import '../../api/client.dart';
import 'spaced_repetition_scheduler.dart';
import 'study_planner_screen.dart';
import 'study_item_detail_screen.dart';

/// Study Dashboard Screen
///
/// Main hub for the homework coach feature showing:
/// - Overview of all study items
/// - Upcoming sessions calendar view
/// - Study statistics (total time, quiz scores)
/// - Create new study item button
/// - Quick access to today's sessions
class StudyDashboardScreen extends StatefulWidget {
  final String userId;

  const StudyDashboardScreen({
    super.key,
    required this.userId,
  });

  @override
  State<StudyDashboardScreen> createState() => _StudyDashboardScreenState();
}

class _StudyDashboardScreenState extends State<StudyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StudyItem> _studyItems = [];
  List<List<StudySession>> _sessionsByItem = [];
  bool _isLoading = true;
  StudyStatistics? _statistics;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final studyItems = await ApiClient.getStudyItems(widget.userId);

      // Load sessions for each study item
      final sessionsByItem = <List<StudySession>>[];
      for (final item in studyItems) {
        final sessions = await ApiClient.getStudySessions(item.id);
        sessionsByItem.add(sessions);
      }

      // Calculate statistics
      final statistics = SpacedRepetitionScheduler.calculateStatistics(
        studyItems,
        sessionsByItem,
      );

      setState(() {
        _studyItems = studyItems;
        _sessionsByItem = sessionsByItem;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load study data: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  List<StudySession> get _allSessions {
    return _sessionsByItem.expand((sessions) => sessions).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Calendar'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Statistics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildCalendarTab(),
                _buildStatisticsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudyPlannerScreen(userId: widget.userId),
            ),
          ).then((_) => _loadData());
        },
        icon: const Icon(Icons.add),
        label: const Text('New Study Plan'),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_studyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No study plans yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first AI-powered study plan',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudyPlannerScreen(userId: widget.userId),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Study Plan'),
            ),
          ],
        ),
      );
    }

    final todaySessions = SpacedRepetitionScheduler.getTodaySessions(_allSessions);
    final upcomingSessions = SpacedRepetitionScheduler.getUpcomingSessions(_allSessions);
    final overdueSessions = SpacedRepetitionScheduler.getOverdueSessions(_allSessions);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Stats
            _buildQuickStatsRow(),

            const SizedBox(height: 24),

            // Today's Sessions
            if (todaySessions.isNotEmpty) ...[
              _buildSectionHeader('Today\'s Sessions', Icons.today),
              const SizedBox(height: 12),
              ...todaySessions.map((session) {
                final item = _studyItems.firstWhere(
                  (item) => item.id == session.studyItemId,
                );
                return _buildSessionCard(session, item);
              }),
              const SizedBox(height: 24),
            ],

            // Overdue Sessions
            if (overdueSessions.isNotEmpty) ...[
              _buildSectionHeader('Overdue', Icons.warning, color: Colors.red),
              const SizedBox(height: 12),
              ...overdueSessions.map((session) {
                final item = _studyItems.firstWhere(
                  (item) => item.id == session.studyItemId,
                );
                return _buildSessionCard(session, item, isOverdue: true);
              }),
              const SizedBox(height: 24),
            ],

            // Study Items
            _buildSectionHeader('My Study Plans', Icons.school),
            const SizedBox(height: 12),
            ..._studyItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final sessions = _sessionsByItem[index];
              return _buildStudyItemCard(item, sessions);
            }),

            const SizedBox(height: 24),

            // Upcoming Sessions
            if (upcomingSessions.isNotEmpty) ...[
              _buildSectionHeader('Upcoming (Next 7 Days)', Icons.event),
              const SizedBox(height: 12),
              ...upcomingSessions.take(5).map((session) {
                final item = _studyItems.firstWhere(
                  (item) => item.id == session.studyItemId,
                );
                return _buildSessionCard(session, item);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarTab() {
    if (_studyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No sessions scheduled',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return SpacedRepetitionCalendar(
      studyItems: _studyItems,
      sessionsByItem: _sessionsByItem,
      onSessionTap: (session) {
        Navigator.pushNamed(
          context,
          '/study/session-detail',
          arguments: session.id,
        ).then((_) => _loadData());
      },
    );
  }

  Widget _buildStatisticsTab() {
    if (_statistics == null || _studyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No statistics yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete some study sessions to see your progress',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Progress',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.event_note,
                          label: 'Sessions',
                          value: '${_statistics!.completedSessions}/${_statistics!.totalSessions}',
                          subtitle: '${_statistics!.completionRate}% complete',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.timer,
                          label: 'Study Time',
                          value: '${_statistics!.totalHoursStudied}h',
                          subtitle: '${_statistics!.totalMinutesStudied} minutes',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.quiz,
                          label: 'Quiz Score',
                          value: '${_statistics!.averageQuizScore}%',
                          subtitle: '${_statistics!.totalQuizCorrect}/${_statistics!.totalQuizQuestions} correct',
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.school,
                          label: 'Study Plans',
                          value: '${_studyItems.length}',
                          subtitle: 'active plans',
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Per-subject breakdown
          Text(
            'By Subject',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ..._studyItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final sessions = _sessionsByItem[index];
            final completedSessions = sessions.where((s) => s.completed).length;
            final totalMinutes = sessions
                .where((s) => s.completed)
                .fold<int>(0, (sum, s) => sum + s.duration);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.school,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.subject,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Test: ${DateFormat('MMM d').format(item.testDate)}',
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMiniStat(
                            'Sessions',
                            '$completedSessions / ${sessions.length}',
                          ),
                        ),
                        Expanded(
                          child: _buildMiniStat(
                            'Time',
                            '${(totalMinutes / 60).toStringAsFixed(1)}h',
                          ),
                        ),
                        Expanded(
                          child: _buildMiniStat(
                            'Progress',
                            '${sessions.isEmpty ? 0 : ((completedSessions / sessions.length) * 100).round()}%',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: sessions.isEmpty ? 0 : completedSessions / sessions.length,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow() {
    final todaySessions = SpacedRepetitionScheduler.getTodaySessions(_allSessions);
    final overdueSessions = SpacedRepetitionScheduler.getOverdueSessions(_allSessions);
    final completedToday = todaySessions.where((s) => s.completed).length;

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.today,
            label: 'Today',
            value: '${todaySessions.length}',
            subtitle: '$completedToday done',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.warning,
            label: 'Overdue',
            value: '${overdueSessions.length}',
            subtitle: 'sessions',
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.school,
            label: 'Active',
            value: '${_studyItems.length}',
            subtitle: 'plans',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildStudyItemCard(StudyItem item, List<StudySession> sessions) {
    final completedSessions = sessions.where((s) => s.completed).length;
    final progress = sessions.isEmpty ? 0.0 : completedSessions / sessions.length;
    final daysUntilTest = item.testDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudyItemDetailScreen(studyItemId: item.id),
            ),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.topic,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Test: ${DateFormat('MMM d').format(item.testDate)} ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '($daysUntilTest days)',
                    style: TextStyle(
                      fontSize: 12,
                      color: daysUntilTest <= 3 ? Colors.red : Colors.grey[600],
                      fontWeight: daysUntilTest <= 3 ? FontWeight.bold : null,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completedSessions / ${sessions.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 0.8 ? Colors.green : Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(StudySession session, StudyItem item,
      {bool isOverdue = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/study/session-detail',
            arguments: session.id,
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? Colors.red.withValues(alpha: 0.1)
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOverdue ? Icons.warning : Icons.event,
                  color: isOverdue ? Colors.red : Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.focus,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${session.duration} min',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
