import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/study_models.dart';
import '../../api/client.dart';
import '../../widgets/quiz_widget.dart';

/// Detail screen for a single study session with timer and quiz
class StudySessionDetail extends StatefulWidget {
  final String sessionId;

  const StudySessionDetail({
    super.key,
    required this.sessionId,
  });

  @override
  State<StudySessionDetail> createState() => _StudySessionDetailState();
}

class _StudySessionDetailState extends State<StudySessionDetail> {
  StudySession? _session;
  StudyItem? _studyItem;
  StudyQuiz? _quiz;
  bool _isLoading = true;
  bool _isTimerRunning = false;
  int _secondsElapsed = 0;
  Timer? _timer;
  final _notesController = TextEditingController();
  final Map<String, bool> _completedTasks = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final session = await ApiClient.getStudySession(widget.sessionId);
      final studyItem = await ApiClient.getStudyItem(session.studyItemId);

      // Find quiz for this session
      final sessionIndex = await _getSessionIndex(session.id, session.studyItemId);
      final quiz = studyItem.studyPlan.quizzes
          .where((q) => q.sessionIndex == sessionIndex)
          .firstOrNull;

      setState(() {
        _session = session;
        _studyItem = studyItem;
        _quiz = quiz;
        _notesController.text = session.notes ?? '';
        for (final task in session.tasks) {
          _completedTasks[task] = false;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load session: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  Future<int> _getSessionIndex(String sessionId, String studyItemId) async {
    final sessions = await ApiClient.getStudySessions(studyItemId);
    return sessions.indexWhere((s) => s.id == sessionId);
  }

  void _startTimer() {
    if (_isTimerRunning) return;

    setState(() => _isTimerRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsElapsed++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  String get _timerDisplay {
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get _targetSeconds => (_session?.duration ?? 30) * 60;

  double get _timerProgress =>
      _targetSeconds > 0 ? _secondsElapsed / _targetSeconds : 0;

  Future<void> _completeSession({int? quizScore, int? quizTotal}) async {
    if (_session == null) return;

    try {
      await ApiClient.completeStudySession(
        _session!.id,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        quizScore: quizScore,
        quizTotal: quizTotal,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session completed! Great job! 🎉'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete session: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQuiz() {
    if (_quiz == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QuizWidget(
                  questions: _quiz!.questions,
                  onComplete: (score, total) {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => QuizCompletionDialog(
                        score: score,
                        total: total,
                        onClose: () {
                          Navigator.pop(context);
                          _completeSession(quizScore: score, quizTotal: total);
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Session')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null || _studyItem == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Session')),
        body: const Center(child: Text('Session not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_session!.focus),
        actions: [
          if (_session!.completed)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Session info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _studyItem!.subject,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _session!.focus,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.calendar_today,
                          DateFormat('MMM d, y').format(_session!.scheduledAt),
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.timer,
                          '${_session!.duration} min',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Timer card
            if (!_session!.completed) ...[
              Card(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _timerDisplay,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Target: ${_session!.duration} min',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _timerProgress.clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _timerProgress >= 1
                                ? Colors.green
                                : Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                            icon: Icon(_isTimerRunning ? Icons.pause : Icons.play_arrow),
                            label: Text(_isTimerRunning ? 'Pause' : 'Start'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],

            // Tasks card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ..._session!.tasks.map((task) {
                      return CheckboxListTile(
                        value: _session!.completed || _completedTasks[task] == true,
                        onChanged: _session!.completed
                            ? null
                            : (value) {
                                setState(() {
                                  _completedTasks[task] = value ?? false;
                                });
                              },
                        title: Text(
                          task,
                          style: TextStyle(
                            decoration: (_session!.completed ||
                                    _completedTasks[task] == true)
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notes card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      enabled: !_session!.completed,
                      decoration: const InputDecoration(
                        hintText: 'Add notes about this session...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quiz section
            if (_quiz != null && !_session!.completed) ...[
              Card(
                color: Colors.amber.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.quiz, size: 48, color: Colors.amber),
                      const SizedBox(height: 8),
                      Text(
                        'Quiz Available',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_quiz!.questions.length} questions',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showQuiz,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Quiz'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Quiz score display (if completed)
            if (_session!.completed && _session!.quizScore != null) ...[
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, size: 32, color: Colors.green),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quiz Score',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${_session!.quizScore} / ${_session!.quizTotal}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Complete button
            if (!_session!.completed)
              ElevatedButton.icon(
                onPressed: _quiz != null ? null : () => _completeSession(),
                icon: const Icon(Icons.check_circle),
                label: Text(_quiz != null
                    ? 'Complete Quiz First'
                    : 'Complete Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
