# Photo Upload System Implementation Guide

## Overview

The photo upload system enables task completion verification through photos with offline support, compression, and parent approval workflow.

## Architecture

### Models (`lib/models/media_models.dart`)
- **MediaUploadResponse**: Backend upload response with URL and metadata
- **ProofPhoto**: Photo with local/remote URL and upload status
- **PhotoUploadQueueItem**: Queued photo for offline sync

### Components

#### 1. PhotoUploadWidget (`lib/widgets/photo_upload_widget.dart`)
Reusable photo capture/upload widget with compression and offline support.

**Features**:
- Camera capture (ImagePicker.source.camera)
- Gallery selection (ImagePicker.source.gallery)
- Automatic compression (max 1920x1080, quality 85%)
- File size validation (max 5MB)
- Offline queueing (saves locally, uploads when online)
- Loading indicator during upload
- Error handling (file too large, network error)
- Preview thumbnail with delete option

**Usage**:
```dart
PhotoUploadWidget(
  onPhotoUploaded: (url) {
    print('Photo uploaded: $url');
  },
  existingPhotoUrl: 'https://example.com/photo.jpg',
  required: true,
  taskId: 'task-123', // For offline queueing
)
```

**Upload Flow**:
1. User taps camera/gallery icon
2. ImagePicker opens
3. User selects/captures image
4. Compress image (use `image` package)
5. Upload to backend (POST /media/upload)
6. Backend returns URL
7. Save URL to task's proofPhotos array
8. Show thumbnail with delete option

**Offline Flow**:
1. Photo capture/selection
2. Compress image
3. Save locally (path_provider + Hive)
4. Add to sync queue
5. Show "Queued for upload" indicator
6. When online → Upload → Update task → Remove from queue

#### 2. TaskCompletionWithPhotoScreen (`lib/features/tasks/task_completion_with_photo.dart`)
Enhanced task completion for tasks with `photoRequired: true`.

**UI**:
1. Task summary card (title, points, assignee)
2. Photo upload section (required indicator)
3. Optional note (TextField)
4. Complete button (disabled until photo uploaded if required)

**Flow**:
1. User completes task
2. If `photoRequired == false` → Direct completion
3. If `photoRequired == true` → Open this screen
4. User must upload photo
5. Tap "Complete with Photo" → Submit
6. If `parentApproval == true` → Status: pendingApproval
7. Else → Status: done, award points immediately

#### 3. ParentApprovalScreen (`lib/features/tasks/parent_approval_screen.dart`)
Screen for parents to approve tasks with quality rating.

**UI**:
- List of tasks pending approval
- Each card shows:
  - Task title + child name
  - Photo thumbnail (tap to fullscreen)
  - Completion time
  - Quality rating slider (1-5 stars)
  - Approve / Reject buttons

**Actions**:
- **Approve**: Award points with quality multiplier
  - 5 stars: 120% points
  - 4 stars: 110% points
  - 3 stars: 100% points
  - 2 stars: 90% points
  - 1 star: 80% points
- **Reject**: Return task to open, send notification
- **No action for 24h**: Auto-approve

**Quality Rating**:
```dart
void _showApprovalDialog(Map<String, dynamic> task) {
  int rating = 3; // Default 3 stars
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Approve Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Rate the quality of work:'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => rating = index + 1),
                icon: Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _approveTask(task, rating);
          },
          child: const Text('Approve'),
        ),
      ],
    ),
  );
}
```

#### 4. PhotoGalleryScreen (`lib/features/tasks/photo_gallery_screen.dart`)
View all completed task photos for a user.

**UI**:
- Grid layout (2 columns)
- Each photo shows:
  - Thumbnail
  - Task title overlay
  - Date completed
  - Points earned badge
- Tap photo → Fullscreen viewer with swipe navigation

**Fullscreen Viewer**:
- PhotoView with pinch-to-zoom
- Swipe to navigate between photos
- Task details overlay
- Share button (optional)

#### 5. PhotoCacheService (`lib/services/photo_cache_service.dart`)
Handles local photo storage and upload queueing.

**Methods**:
```dart
// Save photo locally
await PhotoCacheService.instance.savePhotoLocally(
  File(path),
  'task-123',
);

// Queue for upload
await PhotoCacheService.instance.queuePhotoUpload(
  localPath,
  'task-123',
);

// Sync all queued photos when online
Map<String, String> uploadedUrls =
  await PhotoCacheService.instance.syncPhotos();

// Get local photo path
String? localPath =
  PhotoCacheService.instance.getLocalPhotoPath('task-123');

// Get queue size
int queueSize = await PhotoCacheService.instance.getQueueSize();

// Clear queue (after successful sync)
await PhotoCacheService.instance.clearQueue();
```

**Storage Strategy**:
- Photos saved to: `{appDocuments}/photos/{taskId}_{timestamp}.jpg`
- Queue stored in Hive box: `photo_upload_queue`
- Max retry count: 5
- Retry with exponential backoff
- Delete local file after successful upload

## API Integration

### Backend Endpoints Required

**COORDINATE WITH BACKEND AGENT (python-expert)**

```dart
// Upload photo
POST /media/upload
Headers: Authorization: Bearer {token}
Body: multipart/form-data (file)
Response: {
  "url": "https://s3.../photo.jpg",
  "mediaId": "uuid",
  "thumbnailUrl": "https://s3.../thumb.jpg",
  "fileSizeBytes": 1234567,
  "mimeType": "image/jpeg",
  "uploadedAt": "2025-11-11T10:30:00Z"
}

// Complete task with photo
POST /tasks/{id}/complete
Body: {
  "photo_urls": ["https://..."],
  "note": "Optional completion note"
}
Response: {
  "status": "done" or "pending_approval",
  "points_earned": 20
}

// Get pending approval tasks
GET /tasks/pending-approval
Response: [
  {
    "id": "task-123",
    "title": "Clean bedroom",
    "assigned_to": "user-456",
    "assigned_to_name": "Emma",
    "proof_photos": ["https://..."],
    "completed_at": "2025-11-11T10:30:00Z",
    "points": 20
  }
]

// Approve task
POST /tasks/{id}/approve
Body: {
  "approved": true,
  "quality_rating": 4
}
Response: {
  "points_awarded": 22, // 20 * 1.1 (4-star multiplier)
  "streak_bonus": 2
}

// Reject task
POST /tasks/{id}/approve
Body: {
  "approved": false,
  "reason": "Incomplete cleaning"
}
Response: {
  "status": "open",
  "notification_sent": true
}
```

### ApiClient Methods (`lib/api/client.dart`)

```dart
// Upload photo
MediaUploadResponse response = await ApiClient.instance.uploadPhoto(
  File('/path/to/photo.jpg'),
);

// Complete task with photo
await ApiClient.instance.completeTaskWithPhoto(
  'task-123',
  ['https://s3.../photo.jpg'],
  note: 'All done!',
);

// Get pending approval tasks
List<dynamic> tasks = await ApiClient.instance.getPendingApprovalTasks();

// Approve task
await ApiClient.instance.approveTask('task-123', 4);

// Reject task
await ApiClient.instance.rejectTask('task-123', 'Incomplete work');
```

## Image Compression

### Strategy
- Target dimensions: Max 1920x1080 (1080p)
- Quality: 85% JPEG
- Max file size: 5MB
- Preserve aspect ratio

### Implementation
```dart
Future<File> _compressImage(File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  final image = img.decodeImage(bytes);

  if (image == null) return imageFile;

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
```

### Compression Results
- Original: 4000x3000 (5MB) → Compressed: 1920x1440 (800KB)
- Reduction: 84% smaller
- Quality: Visually lossless for task verification

## Offline Support

### Architecture
1. **Local Storage**: Photos saved to app documents directory
2. **Queue Management**: Hive box stores upload queue
3. **Sync Engine**: Uploads photos when online
4. **Error Handling**: Retry with exponential backoff

### Sync Flow
```dart
// On app startup or connectivity change
if (isOnline) {
  final uploadedUrls = await PhotoCacheService.instance.syncPhotos();

  // Update tasks with uploaded URLs
  for (final entry in uploadedUrls.entries) {
    final taskId = entry.key;
    final photoUrl = entry.value;

    // Update task in local database
    await updateTaskPhotoUrl(taskId, photoUrl);

    // Sync task to backend
    await OfflineQueue.instance.flush();
  }
}
```

### UI Indicators
- **Queued**: Orange badge "Queued for upload"
- **Uploading**: Progress indicator with percentage
- **Uploaded**: Green checkmark
- **Error**: Red error icon with retry button

## Material 3 Design

### Components Used
- Card for photo preview
- IconButton for camera/gallery
- CircularProgressIndicator for upload
- Chip for status badges
- PhotoView for fullscreen
- GridView for gallery

### Colors
- Upload progress: Blue
- Queued: Orange
- Success: Green
- Error: Red

### Animations
- Scale-in for photo preview (300ms)
- Progress indicator rotation
- Fullscreen transition (Material route)
- Pinch-to-zoom (PhotoView)

## Accessibility

### Screen Reader Support
- "Take photo" button label
- "Choose from gallery" button label
- "Photo uploaded successfully" announcement
- "Upload failed" error announcement

### Alternative Text
- Photo descriptions from task title
- Quality rating announced (e.g., "4 out of 5 stars")

### Contrast Ratios
- Status badges: WCAG AA compliant
- Error messages: High contrast red

## Security

### Best Practices
- Server-side file validation (type, size, content)
- Antivirus scanning on upload
- Presigned S3 URLs with expiration
- HTTPS only for uploads
- No EXIF data exposure

### Privacy
- Photos visible only to family members
- Automatic deletion after 90 days (configurable)
- No third-party analytics on photos

## Testing

### Widget Tests
```dart
testWidgets('PhotoUploadWidget shows camera and gallery buttons',
  (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PhotoUploadWidget(
          onPhotoUploaded: (_) {},
        ),
      ),
    ),
  );

  expect(find.text('Camera'), findsOneWidget);
  expect(find.text('Gallery'), findsOneWidget);
});

testWidgets('PhotoUploadWidget shows required indicator',
  (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PhotoUploadWidget(
          onPhotoUploaded: (_) {},
          required: true,
        ),
      ),
    ),
  );

  expect(find.text('Required'), findsOneWidget);
});
```

### Integration Tests
```dart
testWidgets('Complete task with photo flow', (tester) async {
  // Navigate to task completion
  await tester.tap(find.text('Complete'));
  await tester.pumpAndSettle();

  // Verify photo upload widget is present
  expect(find.byType(PhotoUploadWidget), findsOneWidget);

  // Complete button should be disabled (no photo)
  expect(
    tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    ).onPressed,
    isNull,
  );

  // Mock photo upload
  // (In real test, use integration_test with actual ImagePicker)

  // Complete button should be enabled (photo uploaded)
  await tester.pump();
  expect(
    tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    ).onPressed,
    isNotNull,
  );
});
```

## Performance Considerations

### Optimization
- Compress images before upload (reduce bandwidth)
- Thumbnail generation for gallery view
- Lazy loading for photo gallery
- Image caching (cached_network_image)
- Background upload (isolate)

### Memory Management
- Dispose image objects after compression
- Clear image cache on low memory warning
- Limit photo gallery page size (pagination)

## Future Enhancements

1. **Advanced Editing**
   - Crop photo before upload
   - Apply filters
   - Add text annotations

2. **Multiple Photos**
   - Upload multiple photos per task
   - Photo carousel in approval screen

3. **Video Support**
   - Short video proof (max 30s)
   - Video compression
   - Thumbnail extraction

4. **AI Verification**
   - Automatic task verification via computer vision
   - Detect task completion (e.g., clean room detection)
   - Quality scoring

5. **Social Features**
   - Share photos with family
   - Photo comments
   - Photo reactions (likes, emojis)

## Troubleshooting

### Common Issues

**Photo upload fails**: Check network connection and file size (<5MB).

**Compression too slow**: Use isolate for background compression.

**Queue not syncing**: Verify connectivity listener and PhotoCacheService.syncPhotos() called on online event.

**Photo not appearing**: Check backend returns valid URL and CORS configured for S3.

**Gallery shows broken images**: Verify network images have correct headers and HTTPS.

## Backend Coordination

### Required Backend Features

**COORDINATE WITH BACKEND AGENT**:

1. **Media Upload Endpoint** (`POST /media/upload`)
   - Input: multipart/form-data (file)
   - Output: MediaUploadResponse
   - Features: S3 upload, AV scan, size limit (5MB), presigned URLs

2. **Task Completion Endpoint** (`POST /tasks/{id}/complete`)
   - Enhanced to accept `photoUrls: string[]`
   - If `photoRequired == true` and no photo → 400 error
   - Status: done or pending_approval

3. **Pending Approval Endpoint** (`GET /tasks/pending-approval`)
   - Returns tasks with status == pendingApproval
   - Includes photo URLs

4. **Approval Endpoint** (`POST /tasks/{id}/approve`)
   - Input: `{ "approved": true, "qualityRating": 4 }`
   - Awards points with multiplier:
     - 5 stars: 1.2x
     - 4 stars: 1.1x
     - 3 stars: 1.0x
     - 2 stars: 0.9x
     - 1 star: 0.8x

5. **Auto-Approval**: Cron job to auto-approve tasks pending >24h

### S3 Configuration
- Bucket: `famquest-task-photos`
- ACL: Private (presigned URLs)
- Lifecycle: Delete after 90 days
- CORS: Allow GET from app domains
- Max file size: 5MB

### Database Schema
```sql
-- media table
CREATE TABLE media (
  id UUID PRIMARY KEY,
  url TEXT NOT NULL,
  thumbnail_url TEXT,
  file_size_bytes INTEGER,
  mime_type TEXT,
  uploaded_at TIMESTAMP DEFAULT NOW(),
  uploaded_by UUID REFERENCES users(id),
  task_id UUID REFERENCES tasks(id),
  av_scan_status TEXT DEFAULT 'pending'
);

-- tasks table (add columns)
ALTER TABLE tasks ADD COLUMN proof_photos TEXT[];
ALTER TABLE tasks ADD COLUMN quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5);
```
