/// Photo cache service for offline photo support
///
/// Handles local photo storage and upload queueing when offline

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/media_models.dart';
import '../api/client.dart';

class PhotoCacheService {
  static final PhotoCacheService instance = PhotoCacheService._();
  PhotoCacheService._();

  static const String _queueBoxName = 'photo_upload_queue';
  Box<Map>? _queueBox;

  Future<void> initialize() async {
    if (_queueBox == null) {
      _queueBox = await Hive.openBox<Map>(_queueBoxName);
    }
  }

  /// Save photo locally for offline support
  Future<String> savePhotoLocally(File photo, String taskId) async {
    await initialize();

    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${directory.path}/photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${taskId}_$timestamp.jpg';
    final localPath = '${photosDir.path}/$filename';

    await photo.copy(localPath);
    return localPath;
  }

  /// Queue photo for upload when online
  Future<void> queuePhotoUpload(String localPath, String taskId) async {
    await initialize();

    final queueItem = PhotoUploadQueueItem(
      id: const Uuid().v4(),
      localPath: localPath,
      taskId: taskId,
      queuedAt: DateTime.now(),
    );

    await _queueBox!.put(queueItem.id, queueItem.toJson());
  }

  /// Get all queued photos
  Future<List<PhotoUploadQueueItem>> getQueuedPhotos() async {
    await initialize();

    final items = <PhotoUploadQueueItem>[];
    for (final key in _queueBox!.keys) {
      final data = _queueBox!.get(key);
      if (data != null) {
        items.add(PhotoUploadQueueItem.fromJson(Map<String, dynamic>.from(data)));
      }
    }

    return items;
  }

  /// Upload all queued photos
  Future<Map<String, String>> syncPhotos() async {
    await initialize();

    final uploadedUrls = <String, String>{}; // taskId -> photoUrl
    final queue = await getQueuedPhotos();

    for (final item in queue) {
      try {
        // Check if file still exists
        final file = File(item.localPath);
        if (!await file.exists()) {
          // Remove from queue if file is gone
          await _queueBox!.delete(item.id);
          continue;
        }

        // Try to upload
        final response = await ApiClient.instance.uploadPhoto(file);

        // Store URL mapping
        uploadedUrls[item.taskId] = response['url'] as String;

        // Remove from queue on success
        await _queueBox!.delete(item.id);

        // Delete local file after successful upload
        await file.delete();
      } catch (e) {
        // Update retry count
        final updated = item.copyWith(
          retryCount: item.retryCount + 1,
          lastError: e.toString(),
        );
        await _queueBox!.put(item.id, updated.toJson());

        // If too many retries, remove from queue
        if (updated.retryCount >= 5) {
          await _queueBox!.delete(item.id);
        }
      }
    }

    return uploadedUrls;
  }

  /// Get local photo path if exists
  String? getLocalPhotoPath(String taskId) {
    final directory = Directory(
        '${Directory.systemTemp.path}/photos'); // This should be updated to use proper path
    if (!directory.existsSync()) {
      return null;
    }

    final files = directory.listSync();
    for (final file in files) {
      if (file.path.contains(taskId)) {
        return file.path;
      }
    }

    return null;
  }

  /// Clear all queued photos
  Future<void> clearQueue() async {
    await initialize();
    await _queueBox!.clear();
  }

  /// Get queue size
  Future<int> getQueueSize() async {
    await initialize();
    return _queueBox!.length;
  }
}
