/// Task Filter Widget
///
/// Provides filtering and search functionality for task lists
/// Supports status, category, assignee, and date filters

import 'package:flutter/material.dart';
import '../providers/task_provider.dart';

class TaskFilters {
  final String? searchQuery;
  final List<TaskStatus>? statuses;
  final List<String>? categories;
  final List<String>? assignees;
  final DateTime? dueBefore;
  final DateTime? dueAfter;
  final TaskSortBy sortBy;
  final bool sortDescending;

  TaskFilters({
    this.searchQuery,
    this.statuses,
    this.categories,
    this.assignees,
    this.dueBefore,
    this.dueAfter,
    this.sortBy = TaskSortBy.dueDate,
    this.sortDescending = false,
  });

  TaskFilters copyWith({
    String? searchQuery,
    List<TaskStatus>? statuses,
    List<String>? categories,
    List<String>? assignees,
    DateTime? dueBefore,
    DateTime? dueAfter,
    TaskSortBy? sortBy,
    bool? sortDescending,
  }) {
    return TaskFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      statuses: statuses ?? this.statuses,
      categories: categories ?? this.categories,
      assignees: assignees ?? this.assignees,
      dueBefore: dueBefore ?? this.dueBefore,
      dueAfter: dueAfter ?? this.dueAfter,
      sortBy: sortBy ?? this.sortBy,
      sortDescending: sortDescending ?? this.sortDescending,
    );
  }

  bool matches(Task task) {
    // Search query
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      if (!task.title.toLowerCase().contains(query) &&
          !(task.description?.toLowerCase().contains(query) ?? false)) {
        return false;
      }
    }

    // Status filter
    if (statuses != null && statuses!.isNotEmpty) {
      if (!statuses!.contains(task.status)) {
        return false;
      }
    }

    // Category filter
    if (categories != null && categories!.isNotEmpty) {
      if (!categories!.contains(task.category)) {
        return false;
      }
    }

    // Assignee filter
    if (assignees != null && assignees!.isNotEmpty) {
      if (!task.assignees.any((a) => assignees!.contains(a))) {
        return false;
      }
    }

    // Due date filters
    if (dueBefore != null && task.due != null) {
      if (task.due!.isAfter(dueBefore!)) {
        return false;
      }
    }

    if (dueAfter != null && task.due != null) {
      if (task.due!.isBefore(dueAfter!)) {
        return false;
      }
    }

    return true;
  }

  List<Task> apply(List<Task> tasks) {
    // Filter
    final filtered = tasks.where(matches).toList();

    // Sort (modify the list in place)
    switch (sortBy) {
      case TaskSortBy.dueDate:
        filtered.sort((a, b) {
          if (a.due == null && b.due == null) return 0;
          if (a.due == null) return 1;
          if (b.due == null) return -1;
          return sortDescending
              ? b.due!.compareTo(a.due!)
              : a.due!.compareTo(b.due!);
        });
        break;

      case TaskSortBy.priority:
        filtered.sort((a, b) {
          final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
          final aVal = priorityOrder[a.priority] ?? 1;
          final bVal = priorityOrder[b.priority] ?? 1;
          return sortDescending ? bVal.compareTo(aVal) : aVal.compareTo(bVal);
        });
        break;

      case TaskSortBy.points:
        filtered.sort((a, b) => sortDescending
            ? b.points.compareTo(a.points)
            : a.points.compareTo(b.points));
        break;

      case TaskSortBy.title:
        filtered.sort((a, b) => sortDescending
            ? b.title.compareTo(a.title)
            : a.title.compareTo(b.title));
        break;
    }

    return filtered;
  }
}

enum TaskSortBy {
  dueDate,
  priority,
  points,
  title,
}

class TaskFilterWidget extends StatefulWidget {
  final TaskFilters initialFilters;
  final Function(TaskFilters) onFiltersChanged;

  const TaskFilterWidget({
    Key? key,
    required this.initialFilters,
    required this.onFiltersChanged,
  }) : super(key: key);

  @override
  State<TaskFilterWidget> createState() => _TaskFilterWidgetState();
}

class _TaskFilterWidgetState extends State<TaskFilterWidget> {
  late TaskFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  void _updateFilters(TaskFilters newFilters) {
    setState(() {
      _filters = newFilters;
    });
    widget.onFiltersChanged(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _updateFilters(_filters.copyWith(searchQuery: value));
            },
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Status filter
              FilterChip(
                label: const Text('Status'),
                avatar: const Icon(Icons.filter_list, size: 16),
                selected: _filters.statuses != null,
                onSelected: (_) => _showStatusFilter(),
              ),
              const SizedBox(width: 8),

              // Category filter
              FilterChip(
                label: const Text('Category'),
                avatar: const Icon(Icons.category, size: 16),
                selected: _filters.categories != null,
                onSelected: (_) => _showCategoryFilter(),
              ),
              const SizedBox(width: 8),

              // Sort
              ChoiceChip(
                label: Text(_getSortLabel()),
                avatar: const Icon(Icons.sort, size: 16),
                selected: true,
                onSelected: (_) => _showSortOptions(),
              ),
              const SizedBox(width: 8),

              // Clear filters
              if (_hasActiveFilters())
                ActionChip(
                  label: const Text('Clear'),
                  avatar: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _updateFilters(TaskFilters());
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return _filters.searchQuery != null ||
        _filters.statuses != null ||
        _filters.categories != null ||
        _filters.assignees != null;
  }

  String _getSortLabel() {
    switch (_filters.sortBy) {
      case TaskSortBy.dueDate:
        return 'Due Date';
      case TaskSortBy.priority:
        return 'Priority';
      case TaskSortBy.points:
        return 'Points';
      case TaskSortBy.title:
        return 'Name';
    }
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _StatusFilterSheet(
        selectedStatuses: _filters.statuses ?? [],
        onChanged: (statuses) {
          _updateFilters(_filters.copyWith(statuses: statuses));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _CategoryFilterSheet(
        selectedCategories: _filters.categories ?? [],
        onChanged: (categories) {
          _updateFilters(_filters.copyWith(categories: categories));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SortOptionsSheet(
        sortBy: _filters.sortBy,
        sortDescending: _filters.sortDescending,
        onChanged: (sortBy, descending) {
          _updateFilters(_filters.copyWith(
            sortBy: sortBy,
            sortDescending: descending,
          ));
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _StatusFilterSheet extends StatefulWidget {
  final List<TaskStatus> selectedStatuses;
  final Function(List<TaskStatus>) onChanged;

  const _StatusFilterSheet({
    required this.selectedStatuses,
    required this.onChanged,
  });

  @override
  State<_StatusFilterSheet> createState() => _StatusFilterSheetState();
}

class _StatusFilterSheetState extends State<_StatusFilterSheet> {
  late Set<TaskStatus> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedStatuses.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter by Status',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...TaskStatus.values.map((status) {
            return CheckboxListTile(
              title: Text(_statusLabel(status)),
              value: _selected.contains(status),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(status);
                  } else {
                    _selected.remove(status);
                  }
                });
              },
            );
          }).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onChanged(_selected.toList()),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.pendingApproval:
        return 'Pending Approval';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

class _CategoryFilterSheet extends StatefulWidget {
  final List<String> selectedCategories;
  final Function(List<String>) onChanged;

  const _CategoryFilterSheet({
    required this.selectedCategories,
    required this.onChanged,
  });

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  late Set<String> _selected;
  final _categories = ['cleaning', 'care', 'pet', 'homework', 'other'];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedCategories.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter by Category',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ..._categories.map((category) {
            return CheckboxListTile(
              title: Text(_categoryLabel(category)),
              value: _selected.contains(category),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(category);
                  } else {
                    _selected.remove(category);
                  }
                });
              },
            );
          }).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onChanged(_selected.toList()),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'cleaning':
        return 'Cleaning';
      case 'care':
        return 'Care';
      case 'pet':
        return 'Pet Care';
      case 'homework':
        return 'Homework';
      default:
        return 'Other';
    }
  }
}

class _SortOptionsSheet extends StatelessWidget {
  final TaskSortBy sortBy;
  final bool sortDescending;
  final Function(TaskSortBy, bool) onChanged;

  const _SortOptionsSheet({
    required this.sortBy,
    required this.sortDescending,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sort By', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          RadioListTile<TaskSortBy>(
            title: const Text('Due Date'),
            value: TaskSortBy.dueDate,
            groupValue: sortBy,
            onChanged: (value) =>
                onChanged(value!, sortDescending),
          ),
          RadioListTile<TaskSortBy>(
            title: const Text('Priority'),
            value: TaskSortBy.priority,
            groupValue: sortBy,
            onChanged: (value) =>
                onChanged(value!, sortDescending),
          ),
          RadioListTile<TaskSortBy>(
            title: const Text('Points'),
            value: TaskSortBy.points,
            groupValue: sortBy,
            onChanged: (value) =>
                onChanged(value!, sortDescending),
          ),
          RadioListTile<TaskSortBy>(
            title: const Text('Name'),
            value: TaskSortBy.title,
            groupValue: sortBy,
            onChanged: (value) =>
                onChanged(value!, sortDescending),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Descending'),
            value: sortDescending,
            onChanged: (value) => onChanged(sortBy, value),
          ),
        ],
      ),
    );
  }
}
