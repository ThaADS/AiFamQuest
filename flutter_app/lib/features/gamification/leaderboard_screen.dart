/// Leaderboard Screen
///
/// Family ranking with pull-to-refresh
/// Features:
/// - List of family members with rank, avatar, name, points
/// - Current user highlighted
/// - Medal emojis for top 3
/// - Pull to refresh
/// - Period filter (week/month/all-time)
/// - Empty state message
/// - Material 3 list design

import 'package:flutter/material.dart';
import '../../models/gamification_models.dart';
import '../../api/gamification_client.dart';

class LeaderboardScreen extends StatefulWidget {
  final String familyId;
  final String currentUserId;

  const LeaderboardScreen({
    Key? key,
    required this.familyId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _client = GamificationClient.instance;

  List<LeaderboardEntry> _entries = [];
  String _period = 'week';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _client.getLeaderboard(
        widget.familyId,
        period: _period,
      );

      // Mark current user
      final updatedEntries = entries.map((e) {
        return LeaderboardEntry(
          rank: e.rank,
          userId: e.userId,
          displayName: e.displayName,
          avatarUrl: e.avatarUrl,
          points: e.points,
          isCurrentUser: e.userId == widget.currentUserId,
        );
      }).toList();

      setState(() {
        _entries = updatedEntries;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Leaderboard'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _period,
            onSelected: (value) {
              setState(() => _period = value);
              _loadLeaderboard();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'month', child: Text('This Month')),
              const PopupMenuItem(value: 'alltime', child: Text('All Time')),
            ],
            tooltip: 'Change period',
            icon: const Icon(Icons.calendar_today),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaderboard,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState(theme, colorScheme)
                : _entries.isEmpty
                    ? _buildEmptyState(theme, colorScheme)
                    : _buildLeaderboard(theme, colorScheme),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load leaderboard',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadLeaderboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.leaderboard, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('No leaderboard yet',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Complete tasks to earn points and climb the leaderboard!',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard(ThemeData theme, ColorScheme colorScheme) {
    // Split top 3 and rest
    final top3 = _entries.take(3).toList();
    final rest = _entries.length > 3 ? _entries.skip(3).toList() : <LeaderboardEntry>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Podium for top 3
        if (top3.isNotEmpty) ...[
          _buildPodium(top3, theme, colorScheme),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
        ],

        // Rest of the leaderboard
        ...rest.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildLeaderboardCard(entry, theme, colorScheme),
            )),
      ],
    );
  }

  Widget _buildPodium(
    List<LeaderboardEntry> top3,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Reorder for podium visual: 2nd, 1st, 3rd
    final podiumOrder = <LeaderboardEntry?>[];
    if (top3.length > 1) podiumOrder.add(top3[1]); // 2nd place
    if (top3.isNotEmpty) podiumOrder.add(top3[0]); // 1st place
    if (top3.length > 2) podiumOrder.add(top3[2]); // 3rd place

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: podiumOrder.asMap().entries.map((entry) {
            final leaderboardEntry = entry.value;

            if (leaderboardEntry == null) {
              return const SizedBox(width: 100);
            }

            // Determine actual rank for height and color
            final rank = leaderboardEntry.rank;
            final height = rank == 1 ? 140.0 : rank == 2 ? 110.0 : 80.0;
            final color = rank == 1
                ? Colors.amber.shade400
                : rank == 2
                    ? Colors.grey.shade400
                    : Colors.orange.shade400;

            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: rank == 1 ? 36 : 28,
                    backgroundColor: color,
                    backgroundImage: leaderboardEntry.avatarUrl != null
                        ? NetworkImage(leaderboardEntry.avatarUrl!)
                        : null,
                    child: leaderboardEntry.avatarUrl == null
                        ? Text(
                            leaderboardEntry.displayName.isNotEmpty
                                ? leaderboardEntry.displayName[0].toUpperCase()
                                : '?',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),

                  // Medal emoji
                  Text(
                    leaderboardEntry.rankEmoji,
                    style: TextStyle(fontSize: rank == 1 ? 40 : 32),
                  ),
                  const SizedBox(height: 4),

                  // Name
                  Text(
                    leaderboardEntry.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: leaderboardEntry.isCurrentUser
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Points
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '${leaderboardEntry.points}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Podium
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color,
                          color.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      border: Border.all(
                        color: leaderboardEntry.isCurrentUser
                            ? colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLeaderboardCard(
    LeaderboardEntry entry,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isCurrentUser = entry.isCurrentUser;

    return Card(
      elevation: isCurrentUser ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      color: isCurrentUser ? colorScheme.primaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rank with medal emoji
            SizedBox(
              width: 40,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (entry.rankEmoji.isNotEmpty)
                    Text(
                      entry.rankEmoji,
                      style: const TextStyle(fontSize: 24),
                    )
                  else
                    Text(
                      '${entry.rank}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.secondaryContainer,
              backgroundImage:
                  entry.avatarUrl != null ? NetworkImage(entry.avatarUrl!) : null,
              child: entry.avatarUrl == null
                  ? Text(
                      entry.displayName.isNotEmpty
                          ? entry.displayName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        title: Row(
          children: [
            Text(
              entry.displayName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                color: isCurrentUser
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'You',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 20,
              color: Colors.amber.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              '${entry.points}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isCurrentUser
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
