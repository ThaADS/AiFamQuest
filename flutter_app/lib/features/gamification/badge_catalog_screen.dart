/// Badge Catalog Screen
///
/// Grid view of all badges with filtering
/// Features:
/// - Unlocked badges: full color
/// - Locked badges: grayscale with lock icon
/// - Progress bars for badges in progress
/// - Filter: All / Unlocked / Locked
/// - Material 3 card design
/// - Tap for badge details

import 'package:flutter/material.dart';
import '../../models/gamification_models.dart';
import '../../api/gamification_client.dart';

enum BadgeFilter { all, unlocked, locked }

class BadgeCatalogScreen extends StatefulWidget {
  final String userId;

  const BadgeCatalogScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<BadgeCatalogScreen> createState() => _BadgeCatalogScreenState();
}

class _BadgeCatalogScreenState extends State<BadgeCatalogScreen> {
  final _client = GamificationClient.instance;

  List<UserBadge> _earnedBadges = [];
  List<BadgeProgress> _badgeProgress = [];
  BadgeFilter _filter = BadgeFilter.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _client.getAvailableBadges(widget.userId);
      setState(() {
        _earnedBadges = data['earned'] as List<UserBadge>;
        _badgeProgress = data['progress'] as List<BadgeProgress>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> get _filteredItems {
    switch (_filter) {
      case BadgeFilter.unlocked:
        return _earnedBadges;
      case BadgeFilter.locked:
        return _badgeProgress.where((p) => !p.isEarned).toList();
      case BadgeFilter.all:
        return [..._earnedBadges, ..._badgeProgress.where((p) => !p.isEarned)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Collection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBadges,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip(
                  'All',
                  BadgeFilter.all,
                  '${_earnedBadges.length + _badgeProgress.where((p) => !p.isEarned).length}',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Unlocked',
                  BadgeFilter.unlocked,
                  '${_earnedBadges.length}',
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Locked',
                  BadgeFilter.locked,
                  '${_badgeProgress.where((p) => !p.isEarned).length}',
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: colorScheme.error),
                            const SizedBox(height: 16),
                            Text('Failed to load badges',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(_error!,
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadBadges,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emoji_events,
                                    size: 64, color: colorScheme.secondary),
                                const SizedBox(height: 16),
                                Text('No badges yet',
                                    style: theme.textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  'Complete tasks to earn badges!',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                                16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              if (item is UserBadge) {
                                return _buildEarnedBadgeCard(item);
                              } else if (item is BadgeProgress) {
                                return _buildLockedBadgeCard(item);
                              }
                              return const SizedBox.shrink();
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, BadgeFilter filter, String count) {
    final isSelected = _filter == filter;

    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filter = filter);
        }
      },
    );
  }

  Widget _buildEarnedBadgeCard(UserBadge badge) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showBadgeDetails(badge: badge),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                badge.icon,
                size: 56,
                color: badge.color,
              ),
              const SizedBox(height: 12),
              Text(
                badge.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                badge.description,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.rarity.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badge.rarity.color, width: 1),
                ),
                child: Text(
                  badge.rarity.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: badge.rarity.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unlocked ${_formatDate(badge.awardedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedBadgeCard(BadgeProgress progress) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () => _showBadgeDetails(progress: progress),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    progress.icon,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  Icon(
                    Icons.lock,
                    size: 24,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                progress.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                progress.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: progress.rarity.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: progress.rarity.color.withValues(alpha: 0.5), width: 1),
                ),
                child: Text(
                  progress.rarity.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progress.rarity.color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress.progress,
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.current}/${progress.target}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
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

  void _showBadgeDetails({UserBadge? badge, BadgeProgress? progress}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              badge?.icon ?? progress?.icon ?? Icons.emoji_events,
              size: 80,
              color: badge != null
                  ? badge.color
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              badge?.name ?? progress?.name ?? '',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge?.description ?? progress?.description ?? '',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (badge != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Unlocked ${_formatDate(badge.awardedAt)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else if (progress != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Progress: ${progress.current}/${progress.target}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress.progress),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
