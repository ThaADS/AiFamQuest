/// Photo upload widget for FamQuest
///
/// Reusable widget for capturing and uploading task completion photos
/// Supports camera, gallery, compression, and offline queueing

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../api/client.dart';
import '../services/photo_cache_service.dart';

class PhotoUploadWidget extends StatefulWidget {
  final Function(String photoUrl) onPhotoUploaded;
  final String? existingPhotoUrl;
  final bool required;
  final String? taskId; // For offline queueing

  const PhotoUploadWidget({
    Key? key,
    required this.onPhotoUploaded,
    this.existingPhotoUrl,
    this.required = false,
    this.taskId,
  }) : super(key: key);

  @override
  State<PhotoUploadWidget> createState() => _PhotoUploadWidgetState();
}

class _PhotoUploadWidgetState extends State<PhotoUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  String? _photoUrl;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.existingPhotoUrl;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _errorMessage = null;
        _isUploading = true;
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Compress image
      final File imageFile = File(pickedFile.path);
      final compressedFile = await _compressImage(imageFile);

      // Try to upload
      await _uploadPhoto(compressedFile);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = 'Failed to pick image: ${e.toString()}';
      });
    }
  }

  Future<File> _compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      return imageFile;
    }

    // Resize if larger than max dimensions
    img.Image resized = image;
    if (image.width > 1920 || image.height > 1080) {
      resized = img.copyResize(
        image,
        width: image.width > image.height ? 1920 : null,
        height: image.height > image.width ? 1080 : null,
      );
    }

    // Compress to JPEG with quality 85
    final compressedBytes = img.encodeJpg(resized, quality: 85);

    // Save compressed image
    final compressedFile = File('${imageFile.path}_compressed.jpg');
    await compressedFile.writeAsBytes(compressedBytes);

    return compressedFile;
  }

  Future<void> _uploadPhoto(File imageFile) async {
    try {
      // Check if file size is acceptable (max 5MB)
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('File too large. Maximum size is 5MB.');
      }

      // Try to upload to backend
      final response = await ApiClient.instance.uploadPhoto(imageFile);

      setState(() {
        _photoUrl = response['url'] as String?;
        _isUploading = false;
        _errorMessage = null;
      });

      widget.onPhotoUploaded(response['url'] as String);
    } catch (e) {
      // If upload fails, queue for offline sync if taskId provided
      if (widget.taskId != null) {
        try {
          final localPath = await PhotoCacheService.instance.savePhotoLocally(
            imageFile,
            widget.taskId!,
          );
          await PhotoCacheService.instance.queuePhotoUpload(localPath, widget.taskId!);

          setState(() {
            _photoUrl = 'local://$localPath'; // Temporary URL
            _isUploading = false;
            _errorMessage = 'Photo saved offline. Will upload when online.';
          });

          widget.onPhotoUploaded('local://$localPath');
        } catch (offlineError) {
          setState(() {
            _isUploading = false;
            _errorMessage = 'Failed to save photo: ${offlineError.toString()}';
          });
        }
      } else {
        setState(() {
          _isUploading = false;
          _errorMessage = 'Upload failed: ${e.toString()}';
        });
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoUrl = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Proof Photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (widget.required) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Required',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            if (_isUploading) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Uploading photo...'),
                  ],
                ),
              ),
            ] else if (_photoUrl != null) ...[
              // Photo preview
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _photoUrl!.startsWith('local://')
                        ? Image.file(
                            File(_photoUrl!.replaceFirst('local://', '')),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _photoUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 48),
                                ),
                              );
                            },
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: _removePhoto,
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (_photoUrl!.startsWith('local://'))
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Queued for upload',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ] else ...[
              // Upload buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _errorMessage!.contains('offline')
                      ? Colors.orange[100]
                      : Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _errorMessage!.contains('offline')
                          ? Icons.cloud_off
                          : Icons.error_outline,
                      color: _errorMessage!.contains('offline')
                          ? Colors.orange[900]
                          : Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: _errorMessage!.contains('offline')
                              ? Colors.orange[900]
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
