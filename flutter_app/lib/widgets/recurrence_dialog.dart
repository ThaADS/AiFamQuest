import 'package:flutter/material.dart';
import '../features/calendar/calendar_provider.dart';

/// Recurrence dialog for selecting repeat patterns
class RecurrenceDialog extends StatefulWidget {
  final RecurrenceRule? initialRule;

  const RecurrenceDialog({super.key, this.initialRule});

  @override
  State<RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<RecurrenceDialog> {
  String _frequency = 'none';
  final Set<int> _selectedWeekdays = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialRule != null) {
      _frequency = widget.initialRule!.frequency;
      if (widget.initialRule!.weekdays != null) {
        _selectedWeekdays.addAll(widget.initialRule!.weekdays!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Repeat'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // None option
            RadioListTile<String>(
              value: 'none',
              groupValue: _frequency,
              onChanged: (value) => setState(() => _frequency = value!),
              title: const Text('Does not repeat'),
              dense: true,
            ),

            const Divider(),

            // Daily option
            RadioListTile<String>(
              value: 'daily',
              groupValue: _frequency,
              onChanged: (value) => setState(() => _frequency = value!),
              title: const Text('Daily'),
              subtitle: const Text('Repeats every day'),
              dense: true,
            ),

            // Weekly option
            RadioListTile<String>(
              value: 'weekly',
              groupValue: _frequency,
              onChanged: (value) => setState(() => _frequency = value!),
              title: const Text('Weekly'),
              subtitle: _frequency == 'weekly'
                  ? const Text('Select days below')
                  : null,
              dense: true,
            ),

            // Weekday selection (only shown when weekly is selected)
            if (_frequency == 'weekly') ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildWeekdayChip('Mo', 1, colorScheme),
                    _buildWeekdayChip('Tu', 2, colorScheme),
                    _buildWeekdayChip('We', 3, colorScheme),
                    _buildWeekdayChip('Th', 4, colorScheme),
                    _buildWeekdayChip('Fr', 5, colorScheme),
                    _buildWeekdayChip('Sa', 6, colorScheme),
                    _buildWeekdayChip('Su', 7, colorScheme),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Monthly option
            RadioListTile<String>(
              value: 'monthly',
              groupValue: _frequency,
              onChanged: (value) => setState(() => _frequency = value!),
              title: const Text('Monthly'),
              subtitle: const Text('Same day each month'),
              dense: true,
            ),

            const Divider(),

            // Preview
            if (_frequency != 'none') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPreviewText(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_frequency == 'none') {
              Navigator.pop(context, null);
            } else {
              final sortedWeekdays = _selectedWeekdays.toList()..sort();
              final rule = RecurrenceRule(
                frequency: _frequency,
                weekdays: _frequency == 'weekly' && _selectedWeekdays.isNotEmpty
                    ? sortedWeekdays
                    : null,
              );
              Navigator.pop(context, rule);
            }
          },
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildWeekdayChip(String label, int weekday, ColorScheme colorScheme) {
    final isSelected = _selectedWeekdays.contains(weekday);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekdays.add(weekday);
          } else {
            _selectedWeekdays.remove(weekday);
          }
        });
      },
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  String _getPreviewText() {
    switch (_frequency) {
      case 'daily':
        return 'Repeats every day';
      case 'weekly':
        if (_selectedWeekdays.isEmpty) {
          return 'Select at least one day';
        }
        final days = _selectedWeekdays
            .map((d) => ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][d - 1])
            .join(', ');
        return 'Repeats every $days';
      case 'monthly':
        return 'Repeats on the same day each month';
      default:
        return '';
    }
  }
}
