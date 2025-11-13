/// RRULE visual builder widget for FamQuest
///
/// Allows users to build RFC 5545 RRULE strings visually
/// without needing to know the RRULE syntax

import 'package:flutter/material.dart';
import '../models/recurring_task_models.dart';

class RRuleBuilder extends StatefulWidget {
  final Function(String rrule) onRRuleChanged;
  final String? initialRRule;

  const RRuleBuilder({
    Key? key,
    required this.onRRuleChanged,
    this.initialRRule,
  }) : super(key: key);

  @override
  State<RRuleBuilder> createState() => _RRuleBuilderState();
}

class _RRuleBuilderState extends State<RRuleBuilder> {
  RecurrenceFrequency _frequency = RecurrenceFrequency.weekly;
  int _interval = 1;
  Set<String> _selectedDays = {'MO'}; // For weekly
  int _monthDay = 1; // For monthly
  String _endCondition = 'never'; // never, count, until
  int _count = 10;
  DateTime _until = DateTime.now().add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    if (widget.initialRRule != null && widget.initialRRule!.isNotEmpty) {
      _parseRRule(widget.initialRRule!);
    }
    _notifyChange();
  }

  void _parseRRule(String rrule) {
    // Parse FREQ
    if (rrule.contains('FREQ=DAILY')) {
      _frequency = RecurrenceFrequency.daily;
    } else if (rrule.contains('FREQ=WEEKLY')) {
      _frequency = RecurrenceFrequency.weekly;
    } else if (rrule.contains('FREQ=MONTHLY')) {
      _frequency = RecurrenceFrequency.monthly;
    }

    // Parse INTERVAL
    final intervalMatch = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
    if (intervalMatch != null) {
      _interval = int.parse(intervalMatch.group(1)!);
    }

    // Parse BYDAY (weekly)
    final byDayMatch = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule);
    if (byDayMatch != null) {
      _selectedDays = byDayMatch.group(1)!.split(',').toSet();
    }

    // Parse BYMONTHDAY (monthly)
    final byMonthDayMatch = RegExp(r'BYMONTHDAY=(\d+)').firstMatch(rrule);
    if (byMonthDayMatch != null) {
      _monthDay = int.parse(byMonthDayMatch.group(1)!);
    }

    // Parse end condition
    if (rrule.contains('COUNT=')) {
      _endCondition = 'count';
      final countMatch = RegExp(r'COUNT=(\d+)').firstMatch(rrule);
      if (countMatch != null) {
        _count = int.parse(countMatch.group(1)!);
      }
    } else if (rrule.contains('UNTIL=')) {
      _endCondition = 'until';
      final untilMatch = RegExp(r'UNTIL=(\d{8}T\d{6}Z)').firstMatch(rrule);
      if (untilMatch != null) {
        _until = _parseIso8601Date(untilMatch.group(1)!);
      }
    }
  }

  DateTime _parseIso8601Date(String date) {
    // Parse RRULE date format: 20251231T235959Z
    final year = int.parse(date.substring(0, 4));
    final month = int.parse(date.substring(4, 6));
    final day = int.parse(date.substring(6, 8));
    return DateTime(year, month, day);
  }

  String _buildRRule() {
    final parts = <String>['FREQ=${_frequency.value}'];

    if (_interval > 1) {
      parts.add('INTERVAL=$_interval');
    }

    if (_frequency == RecurrenceFrequency.weekly && _selectedDays.isNotEmpty) {
      parts.add('BYDAY=${_selectedDays.join(',')}');
    }

    if (_frequency == RecurrenceFrequency.monthly) {
      parts.add('BYMONTHDAY=$_monthDay');
    }

    if (_endCondition == 'count') {
      parts.add('COUNT=$_count');
    } else if (_endCondition == 'until') {
      final dateStr = _until.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0];
      parts.add('UNTIL=${dateStr}Z');
    }

    return parts.join(';');
  }

  void _notifyChange() {
    widget.onRRuleChanged(_buildRRule());
  }

  String _getHumanReadablePattern() {
    if (_frequency == RecurrenceFrequency.daily) {
      final prefix = _interval > 1 ? 'Every $_interval days' : 'Daily';
      return _addEndCondition(prefix);
    } else if (_frequency == RecurrenceFrequency.weekly) {
      final days = _selectedDays.map((d) => _dayCodeToName(d)).join(', ');
      final prefix = _interval > 1 ? 'Every $_interval weeks on' : 'Weekly on';
      return _addEndCondition('$prefix $days');
    } else {
      final prefix = _interval > 1 ? 'Every $_interval months on' : 'Monthly on';
      return _addEndCondition('$prefix day $_monthDay');
    }
  }

  String _addEndCondition(String base) {
    if (_endCondition == 'count') {
      return '$base, $_count times';
    } else if (_endCondition == 'until') {
      return '$base, until ${_until.day}/${_until.month}/${_until.year}';
    }
    return base;
  }

  String _dayCodeToName(String code) {
    const map = {
      'MO': 'Mon',
      'TU': 'Tue',
      'WE': 'Wed',
      'TH': 'Thu',
      'FR': 'Fri',
      'SA': 'Sat',
      'SU': 'Sun',
    };
    return map[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recurrence Pattern',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Frequency selector
            SegmentedButton<RecurrenceFrequency>(
              segments: RecurrenceFrequency.values
                  .map((f) => ButtonSegment(
                        value: f,
                        label: Text(f.displayName),
                      ))
                  .toList(),
              selected: {_frequency},
              onSelectionChanged: (selected) {
                setState(() {
                  _frequency = selected.first;
                  _notifyChange();
                });
              },
            ),

            const SizedBox(height: 16),

            // Interval selector
            Row(
              children: [
                const Text('Repeat every'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    controller: TextEditingController(text: _interval.toString())
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _interval.toString().length),
                      ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0 && parsed <= 365) {
                        setState(() {
                          _interval = parsed;
                          _notifyChange();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(_frequency == RecurrenceFrequency.daily
                    ? 'days'
                    : _frequency == RecurrenceFrequency.weekly
                        ? 'weeks'
                        : 'months'),
              ],
            ),

            const SizedBox(height: 16),

            // Weekly: Day selector
            if (_frequency == RecurrenceFrequency.weekly) ...[
              const Text('On these days:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildDayChip('MO', 'Mon'),
                  _buildDayChip('TU', 'Tue'),
                  _buildDayChip('WE', 'Wed'),
                  _buildDayChip('TH', 'Thu'),
                  _buildDayChip('FR', 'Fri'),
                  _buildDayChip('SA', 'Sat'),
                  _buildDayChip('SU', 'Sun'),
                ],
              ),
            ],

            // Monthly: Day selector
            if (_frequency == RecurrenceFrequency.monthly) ...[
              Row(
                children: [
                  const Text('On day'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: '1-31',
                      ),
                      controller: TextEditingController(text: _monthDay.toString())
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: _monthDay.toString().length),
                        ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed >= 1 && parsed <= 31) {
                          setState(() {
                            _monthDay = parsed;
                            _notifyChange();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('of the month'),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // End condition
            const Text('Ends:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Never'),
              value: 'never',
              groupValue: _endCondition,
              onChanged: (value) {
                setState(() {
                  _endCondition = value!;
                  _notifyChange();
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              title: Row(
                children: [
                  const Text('After'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      enabled: _endCondition == 'count',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      controller: TextEditingController(text: _count.toString())
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: _count.toString().length),
                        ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          setState(() {
                            _count = parsed;
                            _notifyChange();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('occurrences'),
                ],
              ),
              value: 'count',
              groupValue: _endCondition,
              onChanged: (value) {
                setState(() {
                  _endCondition = value!;
                  _notifyChange();
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              title: Row(
                children: [
                  const Text('On'),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _endCondition == 'until'
                        ? () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _until,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() {
                                _until = picked;
                                _notifyChange();
                              });
                            }
                          }
                        : null,
                    icon: const Icon(Icons.calendar_today),
                    label: Text('${_until.day}/${_until.month}/${_until.year}'),
                  ),
                ],
              ),
              value: 'until',
              groupValue: _endCondition,
              onChanged: (value) {
                setState(() {
                  _endCondition = value!;
                  _notifyChange();
                });
              },
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),

            // Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.preview,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getHumanReadablePattern(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildDayChip(String code, String label) {
    final isSelected = _selectedDays.contains(code);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(code);
          } else {
            if (_selectedDays.length > 1) {
              _selectedDays.remove(code);
            }
          }
          _notifyChange();
        });
      },
    );
  }
}
