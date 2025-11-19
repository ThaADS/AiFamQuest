import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;
import '../../models/study_models.dart';
import '../../api/client.dart';
import 'spaced_repetition_scheduler.dart';

/// Screen showing all study sessions for a study item
class StudySessionsScreen extends StatefulWidget {
  final String studyItemId;

  const StudySessionsScreen({
    super.key,
    required this.studyItemId,
  });

  @override
  State<StudySessionsScreen> createState() => _StudySessionsScreenState();
}

class _StudySessionsScreenState extends State<StudySessionsScreen> {
  StudyItem? _studyItem;
  List<StudySession> _sessions = [];
  bool _isLoading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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
          content: Text('Failed to load study sessions: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  List<StudySession> _getSessionsForDay(DateTime day) {
    return _sessions.where((session) {
      return isSameDay(session.scheduledAt, day);
    }).toList();
  }

  int get _completedSessions =>
      _sessions.where((s) => s.completed).length;

  double get _progressPercentage =>
      _sessions.isEmpty ? 0 : _completedSessions / _sessions.length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Sessions')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_studyItem == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Sessions')),
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
        ],
      ),
      body: Column(
        children: [
          // Header card
          _buildHeaderCard(),

          // Calendar view
          _buildCalendar(),

          // Session list
          Expanded(
            child: _buildSessionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final daysUntilExam = _studyItem!.testDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.all(16),
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
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _studyItem!.subject,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    icon: Icons.calendar_today,
                    label: 'Exam',
                    value: DateFormat('MMM d').format(_studyItem!.testDate),
                    subtitle: '$daysUntilExam days',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    icon: Icons.emoji_events,
                    label: 'Difficulty',
                    value: _studyItem!.difficulty.emoji,
                    subtitle: _studyItem!.difficulty.displayName,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '$_completedSessions / ${_sessions.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressPercentage,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _progressPercentage >= 0.8
                                ? Colors.green
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 30)),
        lastDay: _studyItem!.testDate.add(const Duration(days: 7)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay!, day),
        calendarFormat: _calendarFormat,
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        eventLoader: _getSessionsForDay,
        calendarStyle: CalendarStyle(
          markersMaxCount: 1,
          markerDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
      ),
    );
  }

  Widget _buildSessionList() {
    final filteredSessions = _selectedDay == null
        ? _sessions
        : _getSessionsForDay(_selectedDay!);

    if (filteredSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _selectedDay == null
                  ? 'No study sessions'
                  : 'No sessions on this day',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredSessions.length,
      itemBuilder: (context, index) {
        final session = filteredSessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(StudySession session) {
    final isToday = isSameDay(session.scheduledAt, DateTime.now());
    // final isPast = session.scheduledAt.isBefore(DateTime.now());
    final hasQuiz = _studyItem!.studyPlan.quizzes.any(
      (quiz) => quiz.sessionIndex == _sessions.indexOf(session),
    );

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: session.completed
                          ? Colors.green.withValues(alpha: 0.1)
                          : isToday
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      session.completed
                          ? Icons.check_circle
                          : isToday
                              ? Icons.today
                              : Icons.event,
                      color: session.completed
                          ? Colors.green
                          : isToday
                              ? Colors.orange
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Session info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.focus,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('EEE, MMM d').format(session.scheduledAt)} • ${session.duration} min',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quiz badge
                  if (hasQuiz)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.quiz, size: 12, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            'Quiz',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (session.tasks.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...session.tasks.take(2).map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          session.completed
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 16,
                          color: session.completed ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              decoration: session.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (session.tasks.length > 2)
                  Text(
                    '  +${session.tasks.length - 2} more tasks',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
              if (session.completed && session.quizScore != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Quiz: ${session.quizScore}/${session.quizTotal}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
