import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'calendar_provider.dart';
import '../../core/app_logger.dart';

/// Calendar week view with vertical timeline grid (like Google Calendar)
class CalendarWeekView extends ConsumerStatefulWidget {
  const CalendarWeekView({super.key});

  @override
  ConsumerState<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends ConsumerState<CalendarWeekView> {
  late DateTime _weekStart;
  late DateTime _weekEnd;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeWeek(DateTime.now());
    _loadEvents();

    // Scroll to 6 AM
    WidgetsBinding.instance.addPostFrameCallback((_) {
      const hourHeight = 60.0;
      const scrollTo = 6 * hourHeight;
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

  void _initializeWeek(DateTime date) {
    // Start week on Monday
    final monday = date.subtract(Duration(days: date.weekday - 1));
    _weekStart = DateTime(monday.year, monday.month, monday.day);
    _weekEnd = _weekStart.add(const Duration(days: 7));
  }

  Future<void> _loadEvents() async {
    AppLogger.debug('[WeekView] Loading events from $_weekStart to $_weekEnd');
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
          if (calendarState.isLoading) const LinearProgressIndicator(),

          // Week grid with timeline
          Expanded(
            child: _buildWeekGrid(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/calendar/event/create');
        },
        child: const Icon(Icons.add),
        tooltip: 'New Event',
      ),
    );
  }

  Widget _buildWeekGrid(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const hourHeight = 60.0;
    const timeColumnWidth = 50.0;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          // Day headers
          Container(
            color: colorScheme.surface,
            child: Row(
              children: [
                // Time column spacer
                const SizedBox(width: timeColumnWidth),
                // Day headers
                Expanded(
                  child: Row(
                    children: List.generate(7, (index) {
                      final day = _weekStart.add(Duration(days: index));
                      return Expanded(
                        child: _buildDayHeader(context, day),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Timeline grid
          Stack(
            children: [
              // Hour grid background
              Row(
                children: [
                  // Time labels column
                  SizedBox(
                    width: timeColumnWidth,
                    child: Column(
                      children: List.generate(24, (hour) {
                        final time = DateTime(2020, 1, 1, hour);
                        final timeFormat = DateFormat('HH:mm');
                        return SizedBox(
                          height: hourHeight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4, top: 4),
                            child: Text(
                              timeFormat.format(time),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Day columns with grid lines
                  Expanded(
                    child: Row(
                      children: List.generate(7, (dayIndex) {
                        final day = _weekStart.add(Duration(days: dayIndex));
                        final isToday = _isToday(day);

                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isToday
                                  ? colorScheme.primaryContainer.withOpacity(0.05)
                                  : null,
                              border: Border(
                                left: BorderSide(
                                  color: colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Column(
                              children: List.generate(24, (hour) {
                                return Container(
                                  height: hourHeight,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: colorScheme.outlineVariant,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              // Event blocks overlay
              Positioned(
                left: timeColumnWidth,
                right: 0,
                top: 0,
                child: SizedBox(
                  height: 24 * hourHeight,
                  child: Row(
                    children: List.generate(7, (dayIndex) {
                      final day = _weekStart.add(Duration(days: dayIndex));
                      final events = ref
                          .read(calendarProvider.notifier)
                          .getEventsForDate(day)
                          .where((e) => !e.isAllDay)
                          .toList();

                      return Expanded(
                        child: Stack(
                          children: events.map((event) {
                            return _buildEventBlock(context, event, hourHeight);
                          }).toList(),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Current time indicator
              if (_isCurrentWeek()) _buildCurrentTimeIndicator(colorScheme, hourHeight, timeColumnWidth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, DateTime day) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayFormat = DateFormat('EEE');
    final dateFormat = DateFormat('d');
    final isToday = _isToday(day);
    final events = ref.read(calendarProvider.notifier).getEventsForDate(day);
    final allDayEvents = events.where((e) => e.isAllDay).toList();

    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/calendar/day', arguments: day);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          children: [
            // Day name
            Text(
              dayFormat.format(day),
              style: theme.textTheme.labelMedium?.copyWith(
                color: isToday
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            // Date number
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
            // All-day event indicators
            if (allDayEvents.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
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
      left: 2,
      right: 2,
      child: GestureDetector(
        onTap: () {
          AppLogger.debug('[WeekView] Event tapped: ${event.id}');
          Navigator.pushNamed(context, '/calendar/event/${event.id}');
        },
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(0.2),
            border: Border.all(color: categoryColor, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                event.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
                maxLines: height > 30 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Time (only if height allows)
              if (height > 25) ...[
                const SizedBox(height: 2),
                Text(
                  timeFormat.format(event.startTime),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: categoryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(ColorScheme colorScheme, double hourHeight, double timeColumnWidth) {
    final now = DateTime.now();

    // Only show if today is in current week
    if (now.isBefore(_weekStart) || now.isAfter(_weekEnd)) {
      return const SizedBox.shrink();
    }

    final dayIndex = now.weekday - 1; // Monday = 0
    final top = (now.hour + (now.minute / 60)) * hourHeight;
    final screenWidth = MediaQuery.of(context).size.width;
    final dayColumnWidth = (screenWidth - timeColumnWidth) / 7;
    final left = timeColumnWidth + (dayIndex * dayColumnWidth);

    return Positioned(
      top: top,
      left: left,
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
          Container(
            width: dayColumnWidth - 8,
            height: 2,
            color: colorScheme.error,
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

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  bool _isCurrentWeek() {
    final now = DateTime.now();
    return now.isAfter(_weekStart) && now.isBefore(_weekEnd);
  }

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();
  }
}
