/// Conflict resolution screen for manual conflict review
///
/// Shows all pending conflicts and allows user to resolve them
/// Integrates with ConflictResolver and SyncQueueService

import 'package:flutter/material.dart';
import '../services/sync_queue_service.dart';
import '../services/conflict_resolver.dart';
import '../widgets/conflict_dialog.dart';

class ConflictResolutionScreen extends StatefulWidget {
  const ConflictResolutionScreen({Key? key}) : super(key: key);

  @override
  State<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState extends State<ConflictResolutionScreen> {
  List<ConflictData> _conflicts = [];
  bool _loading = true;
  bool _resolving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConflicts();
  }

  Future<void> _loadConflicts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final conflicts = await SyncQueueService.instance.getPendingConflicts();
      setState(() {
        _conflicts = conflicts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load conflicts: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _resolveConflict(
    ConflictData conflict,
    ConflictResolution resolution,
  ) async {
    setState(() {
      _resolving = true;
      _errorMessage = null;
    });

    try {
      await SyncQueueService.instance.resolveConflictManual(
        conflict,
        resolution,
      );

      // Remove from list
      setState(() {
        _conflicts.removeWhere((c) => c.id == conflict.id);
        _resolving = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Conflict resolved: ${resolution.explanation}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Trigger sync after resolution
      SyncQueueService.instance.scheduleSyncIfNeeded();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resolve conflict: ${e.toString()}';
        _resolving = false;
      });
    }
  }

  Future<void> _autoResolveAll() async {
    setState(() {
      _resolving = true;
      _errorMessage = null;
    });

    try {
      final result = await SyncQueueService.instance.resolveConflictsBatch();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-resolved ${result.resolved} conflicts. ${result.needsManual} need manual review.',
            ),
            backgroundColor:
                result.needsManual > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Reload conflicts
      await _loadConflicts();
    } catch (e) {
      setState(() {
        _errorMessage = 'Auto-resolve failed: ${e.toString()}';
        _resolving = false;
      });
    }
  }

  Future<void> _showConflictDialog(ConflictData conflict) async {
    await showConflictDialog(
      context,
      conflict,
      (resolution) => _resolveConflict(conflict, resolution),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Conflicts'),
        backgroundColor: Colors.orange,
        actions: [
          if (_conflicts.isNotEmpty && !_resolving)
            IconButton(
              icon: const Icon(Icons.auto_fix_high),
              tooltip: 'Auto-resolve all',
              onPressed: _autoResolveAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadConflicts,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading conflicts...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_conflicts.isEmpty) {
      return _buildEmptyState();
    }

    return _buildConflictList();
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Conflicts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadConflicts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Conflicts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All changes are in sync!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictList() {
    return Column(
      children: [
        // Summary card
        _buildSummaryCard(),

        // Conflict list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _conflicts.length,
            itemBuilder: (context, index) {
              final conflict = _conflicts[index];
              return _buildConflictCard(conflict);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Sync Conflicts Detected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You have ${_conflicts.length} ${_conflicts.length == 1 ? 'conflict' : 'conflicts'} that need to be resolved.',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap on a conflict to review and choose which version to keep.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resolving ? null : _autoResolveAll,
                  icon: _resolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_resolving ? 'Resolving...' : 'Auto-Resolve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConflictCard(ConflictData conflict) {
    final canMerge = ConflictResolver.instance.canMerge(conflict);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: InkWell(
        onTap: () => _showConflictDialog(conflict),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getEntityColor(conflict.entityType)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      conflict.entityType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getEntityColor(conflict.entityType),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getConflictTitle(conflict),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Version badges
              Row(
                children: [
                  _buildVersionBadge(
                    'Local v${conflict.clientVersion}',
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.sync_problem,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  _buildVersionBadge(
                    'Server v${conflict.serverVersion}',
                    Colors.green,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Conflict description
              Text(
                _getConflictDescription(conflict),
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canMerge) ...[
                    TextButton.icon(
                      onPressed: () async {
                        final resolution =
                            await ConflictResolver.instance.merge(conflict);
                        _resolveConflict(conflict, resolution);
                      },
                      icon: const Icon(Icons.merge, size: 16),
                      label: const Text('Merge'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    onPressed: () => _showConflictDialog(conflict),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Review'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
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

  Widget _buildVersionBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color.fromRGBO(
            (((color.r * 255.0).round() & 0xff) * 0.7).toInt(),
            (((color.g * 255.0).round() & 0xff) * 0.7).toInt(),
            (((color.b * 255.0).round() & 0xff) * 0.7).toInt(),
            1.0,
          ),
        ),
      ),
    );
  }

  Color _getEntityColor(String entityType) {
    switch (entityType) {
      case 'task':
      case 'tasks':
        return Colors.blue;
      case 'event':
      case 'events':
        return Colors.green;
      case 'point':
      case 'points':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getConflictTitle(ConflictData conflict) {
    final data = conflict.clientData;
    return data['title'] ?? data['name'] ?? 'Unnamed ${conflict.entityType}';
  }

  String _getConflictDescription(ConflictData conflict) {
    final diff = ConflictResolver.instance.getDiff(conflict);
    final fieldCount = diff.length;

    if (fieldCount == 0) {
      return 'No visible differences (version conflict only)';
    } else if (fieldCount == 1) {
      final field = diff.entries.first;
      return '${field.key} was changed on both sides';
    } else {
      final fields = diff.keys.take(2).join(', ');
      return '$fieldCount fields changed: $fields${fieldCount > 2 ? '...' : ''}';
    }
  }
}
