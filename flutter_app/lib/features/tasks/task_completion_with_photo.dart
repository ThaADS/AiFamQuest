/// Task completion with photo screen
///
/// Enhanced completion for tasks with photoRequired flag

import 'package:flutter/material.dart';
import '../../widgets/photo_upload_widget.dart';
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
  String? _photoUrl;
  bool _isSubmitting = false;

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
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                    });
                  },
                  required: widget.task['photo_required'] == true,
                  taskId: widget.task['id'],
                ),

                const SizedBox(height: 24),

                // Optional note
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                    hintText: 'Add any comments about the task...',
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 80),
              ],
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
    super.dispose();
  }
}
