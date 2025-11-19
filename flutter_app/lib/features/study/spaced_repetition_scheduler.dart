import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/study_models.dart';

/// Spaced Repetition Scheduler using SM-2 Algorithm
///
/// This service calculates optimal review dates for study sessions
/// based on the SuperMemo 2 (SM-2) algorithm, which uses:
/// - Easiness Factor (EF): Quality of recall (2.5 default)
/// - Interval: Days until next review
/// - Repetition: Number of successful reviews
///
/// The algorithm ensures that well-learned material is reviewed less frequently,
/// while difficult material is reviewed more often.
class SpacedRepetitionScheduler {
  /// Calculate next review date based on SM-2 algorithm
  ///
  /// [lastReviewDate] - Date of the last review
  /// [quality] - Quality rating (0-5):
  ///   - 0-2: Incorrect response (need to relearn)
  ///   - 3: Correct with difficulty
  ///   - 4: Correct with hesitation
  ///   - 5: Perfect recall
  /// [easinessFactor] - Current easiness factor (default 2.5)
  /// [repetitions] - Number of successful repetitions
  ///
  /// Returns: [ScheduledReview] with next review date and updated parameters
  static ScheduledReview calculateNextReview({
    required DateTime lastReviewDate,
    required int quality,
    double easinessFactor = 2.5,
    int repetitions = 0,
  }) {
    // Ensure quality is in range 0-5
    quality = quality.clamp(0, 5);

    // Calculate new easiness factor
    double newEF = easinessFactor +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));

    // EF should never be less than 1.3
    newEF = newEF < 1.3 ? 1.3 : newEF;

    int newRepetitions;
    int intervalDays;

    if (quality < 3) {
      // Incorrect response - restart learning
      newRepetitions = 0;
      intervalDays = 1;
    } else {
      // Correct response
      newRepetitions = repetitions + 1;

      // Calculate interval based on repetition number
      if (newRepetitions == 1) {
        intervalDays = 1;
      } else if (newRepetitions == 2) {
        intervalDays = 6;
      } else {
        // For subsequent repetitions, multiply previous interval by EF
        final previousInterval = _calculatePreviousInterval(repetitions, easinessFactor);
        intervalDays = (previousInterval * newEF).round();
      }
    }

    final nextReviewDate = lastReviewDate.add(Duration(days: intervalDays));

    return ScheduledReview(
      nextReviewDate: nextReviewDate,
      easinessFactor: newEF,
      repetitions: newRepetitions,
      intervalDays: intervalDays,
    );
  }

  /// Calculate the previous interval for a given repetition count
  static int _calculatePreviousInterval(int repetitions, double easinessFactor) {
    if (repetitions == 0) return 0;
    if (repetitions == 1) return 1;
    if (repetitions == 2) return 6;

    int interval = 6;
    for (int i = 3; i <= repetitions; i++) {
      interval = (interval * easinessFactor).round();
    }
    return interval;
  }

  /// Generate a study calendar for the next N days
  ///
  /// [studyItems] - List of study items with their sessions
  /// [days] - Number of days to generate (default 30)
  ///
  /// Returns: Map of date strings to list of sessions due on that date
  static Map<String, List<StudySession>> generateStudyCalendar(
    List<StudyItem> studyItems,
    List<List<StudySession>> sessionsByItem, {
    int days = 30,
  }) {
    final Map<String, List<StudySession>> calendar = {};
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Initialize calendar for next N days
    for (int i = 0; i < days; i++) {
      final date = now.add(Duration(days: i));
      calendar[dateFormat.format(date)] = [];
    }

    // Add sessions to calendar
    for (int i = 0; i < studyItems.length; i++) {
      final sessions = sessionsByItem[i];

      for (final session in sessions) {
        final dateKey = dateFormat.format(session.scheduledAt);
        if (calendar.containsKey(dateKey)) {
          calendar[dateKey]!.add(session);
        }
      }
    }

    return calendar;
  }

  /// Check if a session is due today
  static bool isDueToday(StudySession session) {
    final now = DateTime.now();
    return isSameDay(session.scheduledAt, now);
  }

  /// Check if a session is overdue
  static bool isOverdue(StudySession session) {
    final now = DateTime.now();
    return session.scheduledAt.isBefore(now) && !session.completed;
  }

  /// Get upcoming sessions (next 7 days)
  static List<StudySession> getUpcomingSessions(
    List<StudySession> sessions,
  ) {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    return sessions
        .where((session) =>
            !session.completed &&
            session.scheduledAt.isAfter(now) &&
            session.scheduledAt.isBefore(sevenDaysFromNow))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Get sessions due today
  static List<StudySession> getTodaySessions(
    List<StudySession> sessions,
  ) {
    return sessions
        .where((session) => !session.completed && isDueToday(session))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Get overdue sessions
  static List<StudySession> getOverdueSessions(
    List<StudySession> sessions,
  ) {
    return sessions.where((session) => isOverdue(session)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Calculate study statistics
  static StudyStatistics calculateStatistics(
    List<StudyItem> studyItems,
    List<List<StudySession>> sessionsByItem,
  ) {
    int totalSessions = 0;
    int completedSessions = 0;
    int totalMinutesStudied = 0;
    int totalQuizQuestions = 0;
    int totalQuizCorrect = 0;

    for (int i = 0; i < studyItems.length; i++) {
      final sessions = sessionsByItem[i];

      for (final session in sessions) {
        totalSessions++;

        if (session.completed) {
          completedSessions++;
          totalMinutesStudied += session.duration;

          if (session.quizScore != null && session.quizTotal != null) {
            totalQuizQuestions += session.quizTotal!;
            totalQuizCorrect += session.quizScore!;
          }
        }
      }
    }

    final averageQuizScore = totalQuizQuestions > 0
        ? (totalQuizCorrect / totalQuizQuestions * 100).round()
        : 0;

    return StudyStatistics(
      totalSessions: totalSessions,
      completedSessions: completedSessions,
      completionRate: totalSessions > 0
          ? (completedSessions / totalSessions * 100).round()
          : 0,
      totalMinutesStudied: totalMinutesStudied,
      totalHoursStudied: (totalMinutesStudied / 60).toStringAsFixed(1),
      averageQuizScore: averageQuizScore,
      totalQuizQuestions: totalQuizQuestions,
      totalQuizCorrect: totalQuizCorrect,
    );
  }
}

/// Result of SM-2 calculation
class ScheduledReview {
  final DateTime nextReviewDate;
  final double easinessFactor;
  final int repetitions;
  final int intervalDays;

  const ScheduledReview({
    required this.nextReviewDate,
    required this.easinessFactor,
    required this.repetitions,
    required this.intervalDays,
  });
}

/// Study statistics
class StudyStatistics {
  final int totalSessions;
  final int completedSessions;
  final int completionRate;
  final int totalMinutesStudied;
  final String totalHoursStudied;
  final int averageQuizScore;
  final int totalQuizQuestions;
  final int totalQuizCorrect;

  const StudyStatistics({
    required this.totalSessions,
    required this.completedSessions,
    required this.completionRate,
    required this.totalMinutesStudied,
    required this.totalHoursStudied,
    required this.averageQuizScore,
    required this.totalQuizQuestions,
    required this.totalQuizCorrect,
  });
}

/// Widget to display study calendar with scheduled sessions
class SpacedRepetitionCalendar extends StatefulWidget {
  final List<StudyItem> studyItems;
  final List<List<StudySession>> sessionsByItem;
  final Function(StudySession)? onSessionTap;

  const SpacedRepetitionCalendar({
    super.key,
    required this.studyItems,
    required this.sessionsByItem,
    this.onSessionTap,
  });

  @override
  State<SpacedRepetitionCalendar> createState() =>
      _SpacedRepetitionCalendarState();
}

class _SpacedRepetitionCalendarState extends State<SpacedRepetitionCalendar> {
  late Map<String, List<StudySession>> _calendar;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generateCalendar();
  }

  @override
  void didUpdateWidget(SpacedRepetitionCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studyItems != widget.studyItems ||
        oldWidget.sessionsByItem != widget.sessionsByItem) {
      _generateCalendar();
    }
  }

  void _generateCalendar() {
    _calendar = SpacedRepetitionScheduler.generateStudyCalendar(
      widget.studyItems,
      widget.sessionsByItem,
      days: 30,
    );
  }

  List<StudySession> _getSessionsForDate(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    return _calendar[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _getSessionsForDate(_selectedDate);

    return Column(
      children: [
        // Week view with dates
        _buildWeekView(),

        const SizedBox(height: 16),

        // Sessions for selected date
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sessions scheduled',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _buildSessionCard(session);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWeekView() {
    final today = DateTime.now();
    final weekDates = List.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weekDates.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final date = weekDates[index];
          final isSelected = isSameDay(date, _selectedDate);
          final sessionsCount = _getSessionsForDate(date).length;
          final isToday = isSameDay(date, today);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : isToday
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  if (sessionsCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$sessionsCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionCard(StudySession session) {
    final isOverdue = SpacedRepetitionScheduler.isOverdue(session);
    final studyItem = widget.studyItems.firstWhere(
      (item) => item.id == session.studyItemId,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => widget.onSessionTap?.call(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: session.completed
                      ? Colors.green.withValues(alpha: 0.1)
                      : isOverdue
                          ? Colors.red.withValues(alpha: 0.1)
                          : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  session.completed
                      ? Icons.check_circle
                      : isOverdue
                          ? Icons.warning
                          : Icons.school,
                  color: session.completed
                      ? Colors.green
                      : isOverdue
                          ? Colors.red
                          : Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studyItem.subject,
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
              if (isOverdue && !session.completed)
                const Chip(
                  label: Text(
                    'Overdue',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 8),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to check if two dates are the same day
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
