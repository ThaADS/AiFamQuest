/// RRULE display widget - shows human-readable recurrence pattern
///
/// Parses RFC 5545 RRULE strings and displays them as readable text
/// Examples:
/// - "FREQ=DAILY" → "Every day"
/// - "FREQ=WEEKLY;BYDAY=MO,WE,FR" → "Every Monday, Wednesday, Friday"
/// - "FREQ=MONTHLY;BYMONTHDAY=1" → "1st of every month"

import 'package:flutter/material.dart';

class RRuleDisplay extends StatelessWidget {
  final String rrule;
  final TextStyle? style;
  final bool compact;

  const RRuleDisplay({
    Key? key,
    required this.rrule,
    this.style,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = _parseRRule(rrule);
    return Text(
      text,
      style: style,
      maxLines: compact ? 1 : null,
      overflow: compact ? TextOverflow.ellipsis : null,
    );
  }

  String _parseRRule(String rrule) {
    if (rrule.isEmpty) return 'No recurrence';

    try {
      // Extract frequency
      String? frequency;
      if (rrule.contains('FREQ=DAILY')) {
        frequency = 'daily';
      } else if (rrule.contains('FREQ=WEEKLY')) {
        frequency = 'weekly';
      } else if (rrule.contains('FREQ=MONTHLY')) {
        frequency = 'monthly';
      } else if (rrule.contains('FREQ=YEARLY')) {
        frequency = 'yearly';
      }

      if (frequency == null) return 'Custom pattern';

      // Extract interval
      final intervalMatch = RegExp(r'INTERVAL=(\d+)').firstMatch(rrule);
      final interval = intervalMatch != null ? int.parse(intervalMatch.group(1)!) : 1;

      // Build base text
      String text = '';

      switch (frequency) {
        case 'daily':
          text = interval > 1 ? 'Every $interval days' : 'Every day';
          break;

        case 'weekly':
          final days = _extractWeekDays(rrule);
          if (days.isEmpty) {
            text = interval > 1 ? 'Every $interval weeks' : 'Every week';
          } else {
            final prefix = interval > 1 ? 'Every $interval weeks on' : 'Every';
            text = '$prefix ${days.join(", ")}';
          }
          break;

        case 'monthly':
          final day = _extractMonthDay(rrule);
          if (day != null) {
            final prefix = interval > 1 ? 'Every $interval months on' : 'Monthly on';
            text = '$prefix ${_ordinal(day)}';
          } else {
            text = interval > 1 ? 'Every $interval months' : 'Every month';
          }
          break;

        case 'yearly':
          text = interval > 1 ? 'Every $interval years' : 'Every year';
          break;
      }

      // Add end condition
      final endText = _extractEndCondition(rrule);
      if (endText.isNotEmpty) {
        text = '$text, $endText';
      }

      return text;
    } catch (e) {
      return 'Invalid pattern';
    }
  }

  List<String> _extractWeekDays(String rrule) {
    final match = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rrule);
    if (match == null) return [];

    final days = match.group(1)!.split(',');
    return days.map((d) => _dayCodeToName(d)).toList();
  }

  String _dayCodeToName(String code) {
    const map = {
      'MO': 'Monday',
      'TU': 'Tuesday',
      'WE': 'Wednesday',
      'TH': 'Thursday',
      'FR': 'Friday',
      'SA': 'Saturday',
      'SU': 'Sunday',
    };
    return map[code] ?? code;
  }

  int? _extractMonthDay(String rrule) {
    final match = RegExp(r'BYMONTHDAY=(\d+)').firstMatch(rrule);
    return match != null ? int.parse(match.group(1)!) : null;
  }

  String _extractEndCondition(String rrule) {
    // Check for COUNT
    final countMatch = RegExp(r'COUNT=(\d+)').firstMatch(rrule);
    if (countMatch != null) {
      final count = countMatch.group(1);
      return '$count times';
    }

    // Check for UNTIL
    final untilMatch = RegExp(r'UNTIL=(\d{8}T\d{6}Z)').firstMatch(rrule);
    if (untilMatch != null) {
      try {
        final dateStr = untilMatch.group(1)!;
        final date = _parseRRuleDate(dateStr);
        return 'until ${date.day}/${date.month}/${date.year}';
      } catch (e) {
        return 'until date';
      }
    }

    return '';
  }

  DateTime _parseRRuleDate(String dateStr) {
    // Parse: 20251231T235959Z
    final year = int.parse(dateStr.substring(0, 4));
    final month = int.parse(dateStr.substring(4, 6));
    final day = int.parse(dateStr.substring(6, 8));
    return DateTime(year, month, day);
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';

    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }
}

/// Compact chip version for use in lists
class RRuleChip extends StatelessWidget {
  final String rrule;

  const RRuleChip({Key? key, required this.rrule}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.repeat,
            size: 14,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          RRuleDisplay(
            rrule: rrule,
            compact: true,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
