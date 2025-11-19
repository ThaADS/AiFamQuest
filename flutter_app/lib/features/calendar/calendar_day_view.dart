import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'calendar_provider.dart';

/// Calendar day view with timeline
class CalendarDayView extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const CalendarDayView({super.key, this.initialDate});

  @override
  ConsumerState<CalendarDayView> createState() => _CalendarDayViewState();
}

class _CalendarDayViewState extends ConsumerState<CalendarDayView> {
  late DateTime _selectedDate;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _loadEvents();

    // Scroll to current hour
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      const hourHeight = 60.0;
      final scrollTo = (now.hour * hourHeight) - 100;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(scrollTo.clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ));
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final end = start.add(const Duration(days: 1));
    await ref.read(calendarProvider.notifier).fetchEvents(start, end);
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadEvents();
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadEvents();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final calendarState = ref.watch(calendarProvider);
    final events = ref.read(calendarProvider.notifier).getEventsForDate(_selectedDate);
    final allDayEvents = events.where((e) => e.isAllDay).toList();
    final timedEvents = events.where((e) => !e.isAllDay).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(dateFormat.format(_selectedDate)),
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
          // Date navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousDay,
                  tooltip: 'Previous day',
                ),
                Text(
                  DateFormat('EEE, MMM d').format(_selectedDate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextDay,
                  tooltip: 'Next day',
                ),
              ],
            ),
          ),

          // Loading indicator
          if (calendarState.isLoading) const LinearProgressIndicator(),

          // All-day events
          if (allDayEvents.isNotEmpty)
            Container(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Day',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...allDayEvents.map((event) => _buildAllDayEventCard(context, event)),
                ],
              ),
            ),

          // Timeline
          Expanded(
            child: timedEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No timed events',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildTimeline(context, timedEvents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/calendar/event/create',
            arguments: _selectedDate,
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Event'),
      ),
    );
  }

  Widget _buildAllDayEventCard(BuildContext context, CalendarEvent event) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(event.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/calendar/event/${event.id}');
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: categoryColor, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(_getCategoryIcon(event.category), size: 16, color: categoryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (event.recurrence != null)
                Icon(Icons.repeat, size: 14, color: theme.colorScheme.error),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<CalendarEvent> events) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const hourHeight = 60.0;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Stack(
        children: [
          // Hour grid
          Column(
            children: List.generate(24, (index) {
              final hour = index;
              final timeFormat = DateFormat('HH:mm');
              final time = DateTime(_selectedDate.year, _selectedDate.month,
                  _selectedDate.day, hour);

              return SizedBox(
                height: hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time label
                    SizedBox(
                      width: 60,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, top: 4),
                        child: Text(
                          timeFormat.format(time),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),

                    // Hour line
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 1,
                            color: colorScheme.outlineVariant,
                          ),
                          Expanded(child: Container()),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          // Event blocks
          Positioned(
            left: 60,
            right: 0,
            top: 0,
            child: Stack(
              children: events.map((event) {
                return _buildEventBlock(context, event, hourHeight);
              }).toList(),
            ),
          ),

          // Current time indicator
          if (_isToday(_selectedDate)) _buildCurrentTimeIndicator(colorScheme, hourHeight),
        ],
      ),
    );
  }

  Widget _buildEventBlock(BuildContext context, CalendarEvent event, double hourHeight) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(event.category);
    final duration = event.endTime.difference(event.startTime);
    final height = (duration.inMinutes / 60) * hourHeight;
    final top = (event.startTime.hour + (event.startTime.minute / 60)) * hourHeight;
    final timeFormat = DateFormat('HH:mm');

    return Positioned(
      top: top,
      left: 8,
      right: 8,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/calendar/event/${event.id}');
        },
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.2),
            border: Border.all(color: categoryColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getCategoryIcon(event.category),
                      size: 14, color: categoryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (event.recurrence != null)
                    Icon(Icons.repeat, size: 12, color: categoryColor),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: categoryColor,
                ),
              ),
              if (event.description != null && height > 60) ...[
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    event.description!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(ColorScheme colorScheme, double hourHeight) {
    final now = DateTime.now();
    final top = (now.hour + (now.minute / 60)) * hourHeight;

    return Positioned(
      top: top,
      left: 60,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: colorScheme.error,
            ),
          ),
        ],
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'school':
        return Icons.school;
      case 'sport':
        return Icons.sports_soccer;
      case 'appointment':
        return Icons.event;
      case 'family':
        return Icons.family_restroom;
      default:
        return Icons.event_note;
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
