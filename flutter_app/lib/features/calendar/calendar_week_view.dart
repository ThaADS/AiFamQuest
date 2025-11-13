import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'calendar_provider.dart';

/// Calendar week view with horizontal scrollable days
class CalendarWeekView extends ConsumerStatefulWidget {
  const CalendarWeekView({super.key});

  @override
  ConsumerState<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends ConsumerState<CalendarWeekView> {
  late DateTime _weekStart;
  late DateTime _weekEnd;

  @override
  void initState() {
    super.initState();
    _initializeWeek(DateTime.now());
    _loadEvents();
  }

  void _initializeWeek(DateTime date) {
    // Start week on Monday
    final monday = date.subtract(Duration(days: date.weekday - 1));
    _weekStart = DateTime(monday.year, monday.month, monday.day);
    _weekEnd = _weekStart.add(const Duration(days: 7));
  }

  Future<void> _loadEvents() async {
    await ref.read(calendarProvider.notifier).fetchEvents(_weekStart, _weekEnd);
  }

  void _previousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _weekEnd = _weekEnd.subtract(const Duration(days: 7));
    });
    _loadEvents();
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _weekEnd = _weekEnd.add(const Duration(days: 7));
    });
    _loadEvents();
  }

  void _goToToday() {
    setState(() {
      _initializeWeek(DateTime.now());
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final calendarState = ref.watch(calendarProvider);
    final monthFormat = DateFormat('MMMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(monthFormat.format(_weekStart)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _goToToday,
            tooltip: 'Today',
          ),
        ],
      ),
      body: Column(
        children: [
          // Week navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousWeek,
                  tooltip: 'Previous week',
                ),
                Text(
                  'Week ${_getWeekNumber(_weekStart)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextWeek,
                  tooltip: 'Next week',
                ),
              ],
            ),
          ),

          // Loading indicator
          if (calendarState.isLoading)
            const LinearProgressIndicator(),

          // Week days
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                final day = _weekStart.add(Duration(days: index));
                final events =
                    ref.read(calendarProvider.notifier).getEventsForDate(day);
                final isToday = _isToday(day);

                return _buildDayColumn(
                  context,
                  day,
                  events,
                  isToday,
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/calendar/event/create');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    DateTime day,
    List<CalendarEvent> events,
    bool isToday,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayFormat = DateFormat('EEE');
    final dateFormat = DateFormat('d');

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Day header
          InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/calendar/day',
                arguments: day,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isToday
                    ? colorScheme.primaryContainer
                    : colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    dayFormat.format(day),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isToday
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isToday ? colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dateFormat.format(day),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isToday
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Events list
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      'No events',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: events.length > 3 ? 3 : events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _buildCompactEventCard(context, event);
                    },
                  ),
          ),

          // Show more indicator
          if (events.length > 3)
            InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/calendar/day',
                  arguments: day,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${events.length - 3} more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactEventCard(BuildContext context, CalendarEvent event) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('HH:mm');
    final categoryColor = _getCategoryColor(event.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/calendar/event/${event.id}');
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: categoryColor, width: 3),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      event.isAllDay
                          ? 'All day'
                          : timeFormat.format(event.startTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'school':
        return Colors.blue;
      case 'sport':
        return Colors.green;
      case 'appointment':
        return Colors.orange;
      case 'family':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();
  }
}
