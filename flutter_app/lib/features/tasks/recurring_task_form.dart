/// Recurring task form for FamQuest
///
/// Comprehensive form for creating and editing recurring tasks

import 'package:flutter/material.dart';
import '../../models/recurring_task_models.dart';
import '../../widgets/rrule_builder.dart';
import '../../api/client.dart';

class RecurringTaskFormScreen extends StatefulWidget {
  final RecurringTask? existingTask;

  const RecurringTaskFormScreen({Key? key, this.existingTask}) : super(key: key);

  @override
  State<RecurringTaskFormScreen> createState() => _RecurringTaskFormScreenState();
}

class _RecurringTaskFormScreenState extends State<RecurringTaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  TaskCategory _category = TaskCategory.cleaning;
  String _rrule = 'FREQ=WEEKLY;BYDAY=MO';
  RotationStrategy _rotationStrategy = RotationStrategy.roundRobin;
  Set<String> _selectedAssignees = {};
  int _points = 10;
  int _estimatedMinutes = 15;
  bool _photoRequired = false;
  bool _parentApproval = false;
  bool _isLoading = false;
  List<dynamic> _previewOccurrences = [];
  List<Map<String, dynamic>> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();

    if (widget.existingTask != null) {
      _titleController.text = widget.existingTask!.title;
      _descriptionController.text = widget.existingTask!.description ?? '';
      _category = widget.existingTask!.category;
      _rrule = widget.existingTask!.rrule;
      _rotationStrategy = widget.existingTask!.rotationStrategy;
      _selectedAssignees = widget.existingTask!.assigneeIds.toSet();
      _points = widget.existingTask!.points;
      _estimatedMinutes = widget.existingTask!.estimatedMinutes;
      _photoRequired = widget.existingTask!.photoRequired;
      _parentApproval = widget.existingTask!.parentApproval;
    }
  }

  Future<void> _loadUsers() async {
    try {
      // TODO: Add API endpoint to get family members
      // For now, mock data
      setState(() {
        _availableUsers = [
          {'id': 'user1', 'name': 'Emma', 'avatar': null},
          {'id': 'user2', 'name': 'Noah', 'avatar': null},
          {'id': 'user3', 'name': 'Sophia', 'avatar': null},
        ];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _previewAssignments() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAssignees.isEmpty &&
        _rotationStrategy != RotationStrategy.manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one assignee')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Mock preview data
      // TODO: Call backend API for real preview
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _previewOccurrences = [
          {
            'date': DateTime.now().add(const Duration(days: 0)),
            'assigned_to': _selectedAssignees.first,
            'assigned_to_name': _availableUsers
                .firstWhere((u) => u['id'] == _selectedAssignees.first)['name']
          },
          {
            'date': DateTime.now().add(const Duration(days: 7)),
            'assigned_to': _selectedAssignees.length > 1
                ? _selectedAssignees.elementAt(1)
                : _selectedAssignees.first,
            'assigned_to_name': _availableUsers.firstWhere((u) =>
                u['id'] ==
                (_selectedAssignees.length > 1
                    ? _selectedAssignees.elementAt(1)
                    : _selectedAssignees.first))['name']
          },
          {
            'date': DateTime.now().add(const Duration(days: 14)),
            'assigned_to': _selectedAssignees.first,
            'assigned_to_name': _availableUsers
                .firstWhere((u) => u['id'] == _selectedAssignees.first)['name']
          },
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAssignees.isEmpty &&
        _rotationStrategy != RotationStrategy.manual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one assignee')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final taskData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category.value,
        'rrule': _rrule,
        'rotation_strategy': _rotationStrategy.value,
        'assignee_ids': _selectedAssignees.toList(),
        'points': _points,
        'estimated_minutes': _estimatedMinutes,
        'photo_required': _photoRequired,
        'parent_approval': _parentApproval,
      };

      if (widget.existingTask != null) {
        await ApiClient.instance.updateRecurringTask(
          widget.existingTask!.id,
          taskData,
        );
      } else {
        await ApiClient.instance.createRecurringTask(taskData);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingTask != null
                ? 'Recurring task updated'
                : 'Recurring task created'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTask != null
            ? 'Edit Recurring Task'
            : 'New Recurring Task'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveTask,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Title must be at least 3 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // Category
                  DropdownButtonFormField<TaskCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: TaskCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(cat.icon, color: cat.color, size: 20),
                            const SizedBox(width: 8),
                            Text(cat.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _category = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // RRULE Builder
                  RRuleBuilder(
                    initialRRule: _rrule,
                    onRRuleChanged: (rrule) {
                      setState(() {
                        _rrule = rrule;
                        _previewOccurrences = []; // Clear preview
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Rotation Strategy
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assignment Strategy',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...RotationStrategy.values.map((strategy) {
                            return RadioListTile<RotationStrategy>(
                              title: Row(
                                children: [
                                  Icon(strategy.icon, size: 20),
                                  const SizedBox(width: 8),
                                  Text(strategy.displayName),
                                ],
                              ),
                              subtitle: Text(strategy.description),
                              value: strategy,
                              groupValue: _rotationStrategy,
                              onChanged: (value) {
                                setState(() {
                                  _rotationStrategy = value!;
                                  _previewOccurrences = [];
                                });
                              },
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Assignees
                  if (_rotationStrategy != RotationStrategy.manual)
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assignees',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: _availableUsers.map((user) {
                                final isSelected =
                                    _selectedAssignees.contains(user['id']);
                                return FilterChip(
                                  label: Text(user['name']),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedAssignees.add(user['id']);
                                      } else {
                                        _selectedAssignees.remove(user['id']);
                                      }
                                      _previewOccurrences = [];
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            if (_selectedAssignees.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Text(
                                  'Please select at least one assignee',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Points and Duration
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rewards',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Text('Points: $_points'),
                          Slider(
                            value: _points.toDouble(),
                            min: 5,
                            max: 100,
                            divisions: 19,
                            label: _points.toString(),
                            onChanged: (value) {
                              setState(() {
                                _points = value.toInt();
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          Text('Estimated Duration: $_estimatedMinutes min'),
                          Slider(
                            value: _estimatedMinutes.toDouble(),
                            min: 5,
                            max: 120,
                            divisions: 23,
                            label: '$_estimatedMinutes min',
                            onChanged: (value) {
                              setState(() {
                                _estimatedMinutes = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Options
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Completion Options',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SwitchListTile(
                            title: const Text('Photo Required'),
                            subtitle: const Text(
                                'Task must include a proof photo'),
                            value: _photoRequired,
                            onChanged: (value) {
                              setState(() {
                                _photoRequired = value;
                              });
                            },
                          ),
                          SwitchListTile(
                            title: const Text('Parent Approval'),
                            subtitle: const Text(
                                'Task requires parent approval before awarding points'),
                            value: _parentApproval,
                            onChanged: (value) {
                              setState(() {
                                _parentApproval = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Preview Button
                  FilledButton.icon(
                    onPressed: _previewAssignments,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview Next 5 Occurrences'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  // Preview Results
                  if (_previewOccurrences.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ..._previewOccurrences.map((occurrence) {
                              final date =
                                  occurrence['date'] as DateTime;
                              final name = occurrence['assigned_to_name'];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(name[0]),
                                ),
                                title: Text(name),
                                subtitle: Text(
                                  '${date.day}/${date.month}/${date.year}',
                                ),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _saveTask,
              icon: const Icon(Icons.save),
              label: const Text('Save Task'),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
