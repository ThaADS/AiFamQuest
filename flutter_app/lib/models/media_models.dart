/// Media and photo upload models for FamQuest
///
/// Provides strongly-typed models for:
/// - Media upload responses
/// - Proof photos for task completion
/// - Photo metadata

/// Media upload response from backend
class MediaUploadResponse {
  final String url;
  final String mediaId;
  final String? thumbnailUrl;
  final int? fileSizeBytes;
  final String mimeType;
  final DateTime uploadedAt;

  MediaUploadResponse({
    required this.url,
    required this.mediaId,
    this.thumbnailUrl,
    this.fileSizeBytes,
    required this.mimeType,
    required this.uploadedAt,
  });

  factory MediaUploadResponse.fromJson(Map<String, dynamic> json) {
    return MediaUploadResponse(
      url: json['url'] ?? '',
      mediaId: json['media_id'] ?? json['mediaId'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? json['thumbnailUrl'],
      fileSizeBytes: json['file_size_bytes'] ?? json['fileSizeBytes'],
      mimeType: json['mime_type'] ?? json['mimeType'] ?? 'image/jpeg',
      uploadedAt: json['uploaded_at'] != null || json['uploadedAt'] != null
          ? DateTime.parse(json['uploaded_at'] ?? json['uploadedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'media_id': mediaId,
      'thumbnail_url': thumbnailUrl,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }
}

/// Proof photo for task completion
class ProofPhoto {
  final String url;
  final String? localPath; // For offline support
  final DateTime takenAt;
  final bool isUploaded;
  final String? uploadError;

  ProofPhoto({
    required this.url,
    this.localPath,
    required this.takenAt,
    this.isUploaded = false,
    this.uploadError,
  });

  factory ProofPhoto.fromJson(Map<String, dynamic> json) {
    return ProofPhoto(
      url: json['url'] ?? '',
      localPath: json['local_path'] ?? json['localPath'],
      takenAt: json['taken_at'] != null || json['takenAt'] != null
          ? DateTime.parse(json['taken_at'] ?? json['takenAt'])
          : DateTime.now(),
      isUploaded: json['is_uploaded'] ?? json['isUploaded'] ?? false,
      uploadError: json['upload_error'] ?? json['uploadError'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'local_path': localPath,
      'taken_at': takenAt.toIso8601String(),
      'is_uploaded': isUploaded,
      'upload_error': uploadError,
    };
  }

  ProofPhoto copyWith({
    String? url,
    String? localPath,
    DateTime? takenAt,
    bool? isUploaded,
    String? uploadError,
  }) {
    return ProofPhoto(
      url: url ?? this.url,
      localPath: localPath ?? this.localPath,
      takenAt: takenAt ?? this.takenAt,
      isUploaded: isUploaded ?? this.isUploaded,
      uploadError: uploadError ?? this.uploadError,
    );
  }
}

/// Photo upload queue item (for offline support)
class PhotoUploadQueueItem {
  final String id;
  final String localPath;
  final String taskId;
  final DateTime queuedAt;
  final int retryCount;
  final String? lastError;

  PhotoUploadQueueItem({
    required this.id,
    required this.localPath,
    required this.taskId,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastError,
  });

  factory PhotoUploadQueueItem.fromJson(Map<String, dynamic> json) {
    return PhotoUploadQueueItem(
      id: json['id'] ?? '',
      localPath: json['local_path'] ?? json['localPath'] ?? '',
      taskId: json['task_id'] ?? json['taskId'] ?? '',
      queuedAt: json['queued_at'] != null || json['queuedAt'] != null
          ? DateTime.parse(json['queued_at'] ?? json['queuedAt'])
          : DateTime.now(),
      retryCount: json['retry_count'] ?? json['retryCount'] ?? 0,
      lastError: json['last_error'] ?? json['lastError'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'local_path': localPath,
      'task_id': taskId,
      'queued_at': queuedAt.toIso8601String(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  PhotoUploadQueueItem copyWith({
    int? retryCount,
    String? lastError,
  }) {
    return PhotoUploadQueueItem(
      id: id,
      localPath: localPath,
      taskId: taskId,
      queuedAt: queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
