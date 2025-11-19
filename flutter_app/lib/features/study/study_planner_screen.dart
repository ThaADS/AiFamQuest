import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/study_models.dart';
import '../../api/client.dart';

/// Screen for creating a new study plan with AI
class StudyPlannerScreen extends StatefulWidget {
  final String userId;

  const StudyPlannerScreen({
    super.key,
    required this.userId,
  });

  @override
  State<StudyPlannerScreen> createState() => _StudyPlannerScreenState();
}

class _StudyPlannerScreenState extends State<StudyPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _topicController = TextEditingController();

  DateTime? _examDate;
  StudyDifficulty _difficulty = StudyDifficulty.medium;
  int _availableTime = 30;
  bool _isGenerating = false;

  final List<String> _popularSubjects = [
    'Biology',
    'Mathematics',
    'History',
    'Chemistry',
    'Physics',
    'Geography',
    'English',
    'Dutch',
    'French',
    'German',
  ];

  final List<int> _timeOptions = [15, 30, 45, 60];

  @override
  void dispose() {
    _subjectController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateStudyPlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_examDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exam date')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final request = CreateStudyPlanRequest(
        userId: widget.userId,
        subject: _subjectController.text.trim(),
        topic: _topicController.text.trim(),
        examDate: DateFormat('yyyy-MM-dd').format(_examDate!),
        difficulty: _difficulty,
        availableTime: _availableTime,
      );

      final response = await ApiClient.createStudyPlan(request);

      if (!mounted) return;

      // Navigate to study sessions screen
      Navigator.pushReplacementNamed(
        context,
        '/study/sessions',
        arguments: response.studyItem.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Study plan created! ${response.plan.plan.length} sessions scheduled',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate study plan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _selectExamDate() async {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(days: 1));
    final lastDate = now.add(const Duration(days: 90));

    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select exam date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _examDate = picked);
    }
  }

  int get _daysUntilExam {
    if (_examDate == null) return 0;
    final now = DateTime.now();
    return _examDate!.difference(now).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Study Plan'),
      ),
      body: _isGenerating
          ? _buildGeneratingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Card(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.school,
                              size: 48,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'AI Study Planner',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Get a personalized study plan with spaced repetition',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Subject selection
                    Text(
                      'Subject',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Biology, Math, History',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.book),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _popularSubjects.map((subject) {
                        return ChoiceChip(
                          label: Text(subject),
                          selected: _subjectController.text == subject,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _subjectController.text = subject;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Topic input
                    Text(
                      'Topic',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        hintText:
                            'e.g., Cell structure, photosynthesis, mitosis',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.topic),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter topics to study';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Exam date
                    Text(
                      'Exam Date',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectExamDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _examDate == null
                                  ? const Text('Select exam date')
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE, MMMM d, y')
                                              .format(_examDate!),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$_daysUntilExam days until exam',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
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

                    const SizedBox(height: 24),

                    // Difficulty selection
                    Text(
                      'Difficulty',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<StudyDifficulty>(
                      segments: StudyDifficulty.values.map((diff) {
                        return ButtonSegment(
                          value: diff,
                          label: Text('${diff.emoji} ${diff.displayName}'),
                        );
                      }).toList(),
                      selected: {_difficulty},
                      onSelectionChanged: (Set<StudyDifficulty> newSelection) {
                        setState(() {
                          _difficulty = newSelection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_difficulty.displayName} = ${_difficulty.sessionCount} study sessions',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Time per session
                    Text(
                      'Time per session',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _timeOptions.map((time) {
                        return ChoiceChip(
                          label: Text('$time min'),
                          selected: _availableTime == time,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _availableTime = time);
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Generate button
                    ElevatedButton.icon(
                      onPressed: _generateStudyPlan,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate Study Plan'),
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
            ),
    );
  }

  Widget _buildGeneratingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Generating your study plan...',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}
