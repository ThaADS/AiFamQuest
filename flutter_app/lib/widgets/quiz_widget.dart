import 'package:flutter/material.dart';
import '../models/study_models.dart';

/// Interactive quiz widget for study sessions
class QuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  final Function(int score, int total) onComplete;

  const QuizWidget({
    super.key,
    required this.questions,
    required this.onComplete,
  });

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget>
    with SingleTickerProviderStateMixin {
  int _currentQuestion = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _answered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _submitAnswer(String answer) {
    if (_answered) return;

    setState(() {
      _selectedAnswer = answer;
      _answered = true;

      final question = widget.questions[_currentQuestion];
      final correctAnswer = question.questionType == QuizQuestionType.text
          ? question.a
          : question.answer;

      if (answer == correctAnswer) {
        _score++;
      }
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Wait 1.5 seconds before moving to next question
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      if (_currentQuestion < widget.questions.length - 1) {
        setState(() {
          _currentQuestion++;
          _selectedAnswer = null;
          _answered = false;
        });
      } else {
        widget.onComplete(_score, widget.questions.length);
      }
    });
  }

  bool _isCorrectAnswer(String answer) {
    if (!_answered) return false;

    final question = widget.questions[_currentQuestion];
    final correctAnswer = question.questionType == QuizQuestionType.text
        ? question.a
        : question.answer;

    return answer == correctAnswer;
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / widget.questions.length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_currentQuestion + 1}/${widget.questions.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Question text
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  question.q,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Answer options
            if (question.questionType == QuizQuestionType.multipleChoice)
              ...question.options!.map((option) {
                final isSelected = _selectedAnswer == option;
                final isCorrect = _isCorrectAnswer(option);
                final isWrong = _answered && isSelected && !isCorrect;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton(
                      onPressed: _answered ? null : () => _submitAnswer(option),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCorrect
                                ? Colors.green
                                : isWrong
                                    ? Colors.red
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        backgroundColor: isCorrect
                            ? Colors.green.withValues(alpha: 0.2)
                            : isWrong
                                ? Colors.red.withValues(alpha: 0.2)
                                : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isCorrect)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check_circle, color: Colors.green),
                            ),
                          if (isWrong)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.cancel, color: Colors.red),
                            ),
                          Flexible(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                color: isCorrect
                                    ? Colors.green
                                    : isWrong
                                        ? Colors.red
                                        : null,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
            else
              // Text input for open questions
              TextField(
                enabled: !_answered,
                onSubmitted: _submitAnswer,
                decoration: InputDecoration(
                  labelText: 'Your answer',
                  hintText: 'Type your answer here',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _answered
                      ? Icon(
                          _isCorrectAnswer(_selectedAnswer ?? '')
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: _isCorrectAnswer(_selectedAnswer ?? '')
                              ? Colors.green
                              : Colors.red,
                        )
                      : null,
                ),
              ),

            if (_answered && question.questionType == QuizQuestionType.text) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Correct answer: ${question.a}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Score display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Score: $_score/${_currentQuestion + (_answered ? 1 : 0)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiz completion dialog
class QuizCompletionDialog extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onClose;

  const QuizCompletionDialog({
    super.key,
    required this.score,
    required this.total,
    required this.onClose,
  });

  String get _message {
    final percentage = (score / total * 100).round();
    if (percentage >= 90) return 'Excellent! 🎉';
    if (percentage >= 75) return 'Great job! 👍';
    if (percentage >= 50) return 'Good effort! 💪';
    return 'Keep practicing! 📚';
  }

  Color get _color {
    final percentage = (score / total * 100).round();
    if (percentage >= 90) return Colors.green;
    if (percentage >= 75) return Colors.blue;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (score / total * 100).round();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _message,
        textAlign: TextAlign.center,
        style: TextStyle(color: _color, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            value: score / total,
            strokeWidth: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
          const SizedBox(height: 24),
          Text(
            '$score / $total',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage% correct',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text('Close'),
        ),
      ],
    );
  }
}
