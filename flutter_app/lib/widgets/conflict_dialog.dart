import 'package:flutter/material.dart';
import '../services/conflict_resolver.dart';

/// Conflict resolution dialog for manual conflict review
/// Shows client vs server versions and allows user to choose resolution
class ConflictDialog extends StatefulWidget {
  final ConflictData conflict;
  final Function(ConflictResolution) onResolve;

  const ConflictDialog({
    Key? key,
    required this.conflict,
    required this.onResolve,
  }) : super(key: key);

  @override
  State<ConflictDialog> createState() => _ConflictDialogState();
}

class _ConflictDialogState extends State<ConflictDialog> {
  late Map<String, ConflictField> _diff;
  bool _showDiffOnly = true;

  @override
  void initState() {
    super.initState();
    _diff = ConflictResolver.instance.getDiff(widget.conflict);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sync Conflict',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Conflict description
              _buildConflictDescription(),
              SizedBox(height: 16),

              // Toggle diff/full view
              _buildViewToggle(),
              SizedBox(height: 16),

              // Client version
              _buildVersionCard(
                title: 'Your Version (Local)',
                data: widget.conflict.clientData,
                timestamp: widget.conflict.clientData['updatedAt'],
                color: Colors.blue,
              ),

              SizedBox(height: 12),

              // Server version
              _buildVersionCard(
                title: 'Server Version',
                data: widget.conflict.serverData,
                timestamp: widget.conflict.serverData['updatedAt'],
                color: Colors.green,
              ),

              SizedBox(height: 16),

              // Diff viewer
              if (_diff.isNotEmpty) _buildDiffView(),
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildConflictDescription() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type: ${widget.conflict.entityType}',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Your changes and server changes conflict. Please choose which version to keep.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildVersionBadge('Client v${widget.conflict.clientVersion}', Colors.blue),
              SizedBox(width: 8),
              Icon(Icons.sync_problem, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              _buildVersionBadge('Server v${widget.conflict.serverVersion}', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildViewToggle() {
    return Row(
      children: [
        Text('View: ', style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(width: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              label: Text('Changes Only'),
              icon: Icon(Icons.compare_arrows, size: 16),
            ),
            ButtonSegment(
              value: false,
              label: Text('Full Data'),
              icon: Icon(Icons.article, size: 16),
            ),
          ],
          selected: {_showDiffOnly},
          onSelectionChanged: (Set<bool> selection) {
            setState(() {
              _showDiffOnly = selection.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildVersionCard({
    required String title,
    required Map<String, dynamic> data,
    required String? timestamp,
    required Color color,
  }) {
    final displayData = _showDiffOnly
        ? Map.fromEntries(
            data.entries.where((e) => _diff.containsKey(e.key)),
          )
        : data;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices, size: 16, color: color),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(
                    (((color.r * 255.0).round() & 0xff) * 0.7).toInt(),
                    (((color.g * 255.0).round() & 0xff) * 0.7).toInt(),
                    (((color.b * 255.0).round() & 0xff) * 0.7).toInt(),
                    1.0,
                  ),
                ),
              ),
            ],
          ),
          if (timestamp != null) ...[
            SizedBox(height: 4),
            Text(
              'Updated: ${_formatTimestamp(timestamp)}',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
          SizedBox(height: 8),
          ...displayData.entries.where((e) => !_isMetadataField(e.key)).map((e) {
            final hasConflict = _diff.containsKey(e.key);
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasConflict)
                    Icon(Icons.warning, size: 14, color: Colors.orange)
                  else
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                  SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatValue(e.value),
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDiffView() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 16, color: Colors.grey.shade700),
              SizedBox(width: 6),
              Text(
                'Differences (${_diff.length} fields)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 12),
          ..._diff.entries.map((e) {
            final field = e.value;
            return _buildDiffRow(e.key, field);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDiffRow(String fieldName, ConflictField field) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildDiffValue(
                  'Yours',
                  field.clientValue,
                  Colors.blue,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: _buildDiffValue(
                  'Server',
                  field.serverValue,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffValue(String label, dynamic value, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color.fromRGBO(
                (((color.r * 255.0).round() & 0xff) * 0.7).toInt(),
                (((color.g * 255.0).round() & 0xff) * 0.7).toInt(),
                (((color.b * 255.0).round() & 0xff) * 0.7).toInt(),
                1.0,
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            _formatValue(value),
            style: TextStyle(fontSize: 12, color: Colors.black87),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    final canMerge = ConflictResolver.instance.canMerge(widget.conflict);

    return [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          final resolution = ConflictResolution(
            strategy: ResolutionStrategy.lastWriterWins,
            resolvedData: widget.conflict.serverData,
            needsManualReview: false,
            explanation: 'User chose server version',
          );
          widget.onResolve(resolution);
          Navigator.of(context).pop();
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.green,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download, size: 16),
            SizedBox(width: 4),
            Text('Keep Server'),
          ],
        ),
      ),
      TextButton(
        onPressed: () {
          final resolution = ConflictResolution(
            strategy: ResolutionStrategy.lastWriterWins,
            resolvedData: widget.conflict.clientData,
            needsManualReview: false,
            explanation: 'User chose local version',
          );
          widget.onResolve(resolution);
          Navigator.of(context).pop();
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices, size: 16),
            SizedBox(width: 4),
            Text('Keep Mine'),
          ],
        ),
      ),
      if (canMerge)
        FilledButton(
          onPressed: () async {
            final resolution = await ConflictResolver.instance.merge(widget.conflict);
            widget.onResolve(resolution);
            Navigator.of(context).pop();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.merge, size: 16),
              SizedBox(width: 4),
              Text('Merge Both'),
            ],
          ),
        ),
    ];
  }

  bool _isMetadataField(String key) {
    return ['version', 'isDirty', 'updatedAt', 'createdAt'].contains(key);
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) return value.join(', ');
    if (value is Map) return value.toString();
    return value.toString();
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}

/// Helper function to show conflict dialog
Future<void> showConflictDialog(
  BuildContext context,
  ConflictData conflict,
  Function(ConflictResolution) onResolve,
) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConflictDialog(
      conflict: conflict,
      onResolve: onResolve,
    ),
  );
}
