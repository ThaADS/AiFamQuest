import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'calendar_provider.dart';
import '../../widgets/recurrence_dialog.dart';
import '../../services/local_storage.dart';

/// Event create/edit form with validation
class EventFormScreen extends ConsumerStatefulWidget {
  final CalendarEvent? event; // null for create, populated for edit
  final DateTime? initialDate;

  const EventFormScreen({super.key, this.event, this.initialDate});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  String _category = 'other';
  String _color = '#2196F3';
  RecurrenceRule? _recurrence;
  final Set<String> _selectedAttendees = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      // Edit mode
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description ?? '';
      _startDate = widget.event!.startTime;
      _startTime = TimeOfDay.fromDateTime(widget.event!.startTime);
      _endDate = widget.event!.endTime;
      _endTime = TimeOfDay.fromDateTime(widget.event!.endTime);
      _isAllDay = widget.event!.isAllDay;
      _category = widget.event!.category;
      _color = widget.event!.color;
      _recurrence = widget.event!.recurrence;
      _selectedAttendees.addAll(widget.event!.attendees);
    } else {
      // Create mode
      final initialDate = widget.initialDate ?? DateTime.now();
      _startDate = initialDate;
      _startTime = TimeOfDay.now();
      _endDate = initialDate;
      _endTime = TimeOfDay(hour: TimeOfDay.now().hour + 1, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'New Event' : 'Edit Event'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Event name',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Add details (optional)',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 24),

            // All-day toggle
            SwitchListTile(
              value: _isAllDay,
              onChanged: (value) => setState(() => _isAllDay = value),
              title: const Text('All-day event'),
              secondary: const Icon(Icons.all_inclusive),
            ),

            const SizedBox(height: 16),

            // Start date/time
            _buildDateTimePicker(
              context,
              label: 'Start',
              date: _startDate,
              time: _startTime,
              onDateChanged: (date) => setState(() => _startDate = date),
              onTimeChanged: (time) => setState(() => _startTime = time),
            ),

            const SizedBox(height: 16),

            // End date/time
            _buildDateTimePicker(
              context,
              label: 'End',
              date: _endDate,
              time: _endTime,
              onDateChanged: (date) => setState(() => _endDate = date),
              onTimeChanged: (time) => setState(() => _endTime = time),
            ),

            const SizedBox(height: 24),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'school', child: Text('School')),
                DropdownMenuItem(value: 'sport', child: Text('Sport')),
                DropdownMenuItem(value: 'appointment', child: Text('Appointment')),
                DropdownMenuItem(value: 'family', child: Text('Family')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _category = value!),
            ),

            const SizedBox(height: 16),

            // Color picker
            _buildColorPicker(context, colorScheme),

            const SizedBox(height: 24),

            // Recurrence button
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repeat'),
              subtitle: Text(_recurrence?.getDescription() ?? 'Does not repeat'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectRecurrence,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colorScheme.outline),
              ),
            ),

            const SizedBox(height: 16),

            // Attendees section
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadFamilyMembers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snapshot.data!;
                return _buildAttendeesSection(context, members);
              },
            ),

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveEvent,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(widget.event == null ? 'Create' : 'Save'),
      ),
    );
  }

  Widget _buildDateTimePicker(
    BuildContext context, {
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<TimeOfDay> onTimeChanged,
  }) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Date picker
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) onDateChanged(picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(dateFormat.format(date)),
                  ),
                ),
                if (!_isAllDay) ...[
                  const SizedBox(width: 8),
                  // Time picker
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked != null) onTimeChanged(picked);
                      },
                      icon: const Icon(Icons.access_time),
                      label: Text(timeFormat.format(DateTime(
                        2020,
                        1,
                        1,
                        time.hour,
                        time.minute,
                      ))),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(BuildContext context, ColorScheme colorScheme) {
    final colors = {
      '#2196F3': Colors.blue,
      '#4CAF50': Colors.green,
      '#FF9800': Colors.orange,
      '#9C27B0': Colors.purple,
      '#F44336': Colors.red,
      '#00BCD4': Colors.cyan,
      '#FFEB3B': Colors.yellow,
      '#9E9E9E': Colors.grey,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.entries.map((entry) {
            final hex = entry.key;
            final color = entry.value;
            final isSelected = _color == hex;

            return InkWell(
              onTap: () => setState(() => _color = hex),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAttendeesSection(
    BuildContext context,
    List<Map<String, dynamic>> members,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendees',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...members.map((member) {
          final userId = member['id'] as String;
          final name = member['name'] as String;
          final isSelected = _selectedAttendees.contains(userId);

          return CheckboxListTile(
            value: isSelected,
            onChanged: (selected) {
              setState(() {
                if (selected == true) {
                  _selectedAttendees.add(userId);
                } else {
                  _selectedAttendees.remove(userId);
                }
              });
            },
            title: Text(name),
            secondary: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _selectRecurrence() async {
    final rule = await showDialog<RecurrenceRule?>(
      context: context,
      builder: (context) => RecurrenceDialog(initialRule: _recurrence),
    );

    if (rule != null) {
      setState(() => _recurrence = rule);
    } else if (rule == null && _recurrence != null) {
      setState(() => _recurrence = null);
    }
  }

  Future<List<Map<String, dynamic>>> _loadFamilyMembers() async {
    // TODO: Load from API/storage
    // Mock data for now
    return [
      {'id': 'user1', 'name': 'John'},
      {'id': 'user2', 'name': 'Jane'},
      {'id': 'user3', 'name': 'Kid1'},
    ];
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate dates
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime) ||
        endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Validate attendees
    if (_selectedAttendees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one attendee')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await LocalStorage.instance.getCurrentUser();
      final userId = user?['id'] as String? ?? 'unknown';

      final event = CalendarEvent(
        id: widget.event?.id ?? '',
        familyId: user?['familyId'] as String? ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        isAllDay: _isAllDay,
        attendees: _selectedAttendees.toList(),
        category: _category,
        color: _color,
        recurrence: _recurrence,
        updatedAt: DateTime.now().toUtc(),
        lastModifiedBy: userId,
      );

      if (widget.event == null) {
        // Create new event
        await ref.read(calendarProvider.notifier).createEvent(event);
      } else {
        // Update existing event
        await ref.read(calendarProvider.notifier).updateEvent(widget.event!.id, event);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.event == null ? 'Event created' : 'Event updated',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
