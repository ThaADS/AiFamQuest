/// Task completion with photo screen
///
/// Enhanced completion for tasks with photoRequired flag
/// Includes AI-powered cleaning tips via Gemini Vision
/// Supports offline-first with sync queue

import 'package:flutter/material.dart';
import '../../widgets/photo_upload_widget.dart';
import '../../widgets/cleaning_tips_card.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/sync_status_widget.dart';
import '../../api/client.dart';

class TaskCompletionWithPhotoScreen extends StatefulWidget {
  final Map<String, dynamic> task;

  const TaskCompletionWithPhotoScreen({Key? key, required this.task})
      : super(key: key);

  @override
  State<TaskCompletionWithPhotoScreen> createState() =>
      _TaskCompletionWithPhotoScreenState();
}

class _TaskCompletionWithPhotoScreenState
    extends State<TaskCompletionWithPhotoScreen> {
  final _noteController = TextEditingController();
  final _roomController = TextEditingController();
  final _surfaceController = TextEditingController();

  String? _photoUrl;
  bool _isSubmitting = false;
  Map<String, dynamic>? _cleaningTips;
  bool _isLoadingTips = false;
  String? _tipsError;

  Future<void> _getCleaningTips() async {
    if (_photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a photo first')),
      );
      return;
    }

    // Don't process local photos
    if (_photoUrl!.startsWith('local://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo must be uploaded before getting tips. Please wait for upload.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoadingTips = true;
      _tipsError = null;
    });

    try {
      final tips = await ApiClient.instance.getCleaningTips(
        imageUrl: _photoUrl!,
        room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
        surface: _surfaceController.text.trim().isEmpty ? null : _surfaceController.text.trim(),
        userInput: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      setState(() {
        _cleaningTips = tips;
        _isLoadingTips = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTips = false;
        _tipsError = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get cleaning tips: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _completeTask() async {
    if (widget.task['photo_required'] == true && _photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo is required')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiClient.instance.completeTaskWithPhoto(
        widget.task['id'],
        _photoUrl != null ? [_photoUrl!] : [],
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.task['parent_approval'] == true
                  ? 'Task submitted for approval'
                  : 'Task completed! +${widget.task['points']} points',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Task'),
        actions: const [
          SyncStatusWidget(),
        ],
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : OfflineIndicator(
              child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Task summary
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task['title'] ?? 'Task',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (widget.task['description'] != null) ...[
                          const SizedBox(height: 8),
                          Text(widget.task['description']),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.task['points'] ?? 0} points',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Photo upload
                PhotoUploadWidget(
                  onPhotoUploaded: (url) {
                    setState(() {
                      _photoUrl = url;
                      // Reset tips when photo changes
                      _cleaningTips = null;
                      _tipsError = null;
                    });
                  },
                  required: widget.task['photo_required'] == true,
                  taskId: widget.task['id'],
                ),

                // Get Cleaning Tips Button
                if (_photoUrl != null && !_photoUrl!.startsWith('local://')) ...[
                  const SizedBox(height: 16),
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Get AI Cleaning Tips',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Optional context for better tips:',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _roomController,
                                  decoration: const InputDecoration(
                                    labelText: 'Room',
                                    border: OutlineInputBorder(),
                                    hintText: 'e.g., Kitchen',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _surfaceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Surface',
                                    border: OutlineInputBorder(),
                                    hintText: 'e.g., Marble',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingTips ? null : _getCleaningTips,
                              icon: _isLoadingTips
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.lightbulb),
                              label: Text(_isLoadingTips ? 'Analyzing...' : 'Get Cleaning Tips'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Display cleaning tips
                if (_cleaningTips != null) ...[
                  const SizedBox(height: 16),
                  CleaningTipsCard(
                    tips: _cleaningTips!,
                    onRefresh: _getCleaningTips,
                  ),
                ],

                // Display loading state
                if (_isLoadingTips) ...[
                  const SizedBox(height: 16),
                  const CleaningTipsCard(
                    tips: {},
                    isLoading: true,
                  ),
                ],

                const SizedBox(height: 24),

                // Optional note
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                    hintText: 'Describe the stain or add comments...',
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
      floatingActionButton: _isSubmitting
          ? null
          : FloatingActionButton.extended(
              onPressed: _completeTask,
              icon: const Icon(Icons.check),
              label: Text(widget.task['parent_approval'] == true
                  ? 'Submit for Approval'
                  : 'Complete Task'),
            ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _roomController.dispose();
    _surfaceController.dispose();
    super.dispose();
  }
}
