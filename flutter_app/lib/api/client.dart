import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../offline_queue.dart';
import '../services/sync_queue_service.dart';
import '../services/local_storage.dart';
import '../models/study_models.dart';
import '../core/app_logger.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  final _storage = const FlutterSecureStorage();
  final _connectivity = Connectivity();
  
  // Dynamic base URL handling
  String get baseUrl {
    // 1. Check .env for explicit override (Production/Custom)
    final envUrl = dotenv.env['API_BASE'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // 2. Check for Android Emulator
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    
    // 3. Fallback to localhost (iOS/Web)
    return 'http://localhost:8000';
  }

  Future<bool> hasToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && !session.isExpired) return true;
    return (await _storage.read(key: 'accessToken'))?.isNotEmpty == true;
  }

  Future<void> setToken(String token) async =>
      _storage.write(key: 'accessToken', value: token);

  Future<String?> getToken() async {
    // Prefer Supabase session token as it handles refresh automatically
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && !session.isExpired) {
      return session.accessToken;
    }
    return _storage.read(key: 'accessToken');
  }

  Future<Map<String, dynamic>> login(String email, String password,
      {String? otp}) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'otp': otp}));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await setToken(data['accessToken']);
      return data;
    }
    throw Exception('Login failed: ${res.statusCode} ${res.body}');
  }

  Future<List<dynamic>> listTasks() async {
    final t = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/tasks'),
        headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('List tasks failed');
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async {
    final t = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/tasks'),
          headers: {
            'Authorization': 'Bearer $t',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(body));
      if (res.statusCode == 200) return jsonDecode(res.body);
      throw Exception('Create task failed');
    } catch (_) {
      await OfflineQueue.instance
          .enqueue({'op': 'POST', 'path': '/tasks', 'body': body});
      return {'queued': true};
    }
  }

  Future<Map<String, dynamic>> updateTask(
      String taskId, Map<String, dynamic> body) async {
    final t = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Update task failed: ${res.statusCode} ${res.body}');
  }

  Future<void> deleteTask(String taskId) async {
    final t = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Delete task failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<Map<String, dynamic>> claimTask(String taskId) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/claim'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Claim task failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> releaseTask(String taskId) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/release'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Release task failed: ${res.statusCode} ${res.body}');
  }

  Future<void> flushQueue() async {
    final t = await getToken();
    final list = await OfflineQueue.instance.load();
    for (final op in list) {
      final method = op['op'], path = op['path'], body = op['body'];
      final uri = Uri.parse('$baseUrl$path');
      if (method == 'POST') {
        await http.post(uri,
            headers: {
              'Authorization': 'Bearer $t',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(body));
      }
    }
    await OfflineQueue.instance.clear();
  }

  Future<List<dynamic>> listRewards() async {
    final t = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/rewards'),
        headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('List rewards failed');
  }

  /// Upload photo and get AI-powered cleaning tips
  ///
  /// Calls `/api/ai/vision-tips` endpoint which:
  /// - Uploads photo to server
  /// - Analyzes with AI Vision (OpenRouter)
  /// - Returns cleaning advice with steps, products, warnings
  ///
  /// Returns:
  /// {
  ///   "url": "http://..../photo.jpg",
  ///   "tips": {
  ///     "detected": {"surface": "marble", "stain": "red_wine", "confidence": 0.87},
  ///     "steps": ["Blot immediately...", "Mix baking soda..."],
  ///     "products": {"recommended": [...], "avoid": [...]},
  ///     "warnings": ["Marble is porous..."],
  ///     "estimatedMinutes": 15,
  ///     "difficulty": 2
  ///   }
  /// }
  Future<Map<String, dynamic>> uploadVisionTips(
    String filename,
    List<int> bytes, {
    String description = '',
  }) async {
    final t = await getToken();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ai/vision-tips'),
    );
    req.headers['Authorization'] = 'Bearer $t';
    req.fields['description'] = description;
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200) {
      return jsonDecode(body);
    }

    throw Exception('Vision tips failed: ${res.statusCode} $body');
  }

  @Deprecated('Use uploadVisionTips instead')
  Future<Map<String, dynamic>> uploadVision(String filename, List<int> bytes,
      {String description = ''}) async {
    return uploadVisionTips(filename, bytes, description: description);
  }

  Future<Map<String, dynamic>> aiPlan(Map<String, dynamic> weekCtx) async {
    final t = await getToken();
    final res = await http.post(Uri.parse('$baseUrl/ai/planner'),
        headers: {
          'Authorization': 'Bearer $t',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'weekContext': weekCtx}));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('AI plan failed');
  }

  Future<Map<String, dynamic>> getProfile() async {
    final t = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $t'});
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get profile failed');
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> body) async {
    final t = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/events'),
          headers: {
            'Authorization': 'Bearer $t',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(body));
      if (res.statusCode == 200) return jsonDecode(res.body);
      throw Exception('Create event failed');
    } catch (_) {
      await OfflineQueue.instance
          .enqueue({'op': 'POST', 'path': '/events', 'body': body});
      return {'queued': true};
    }
  }

  // ===== Apple Sign-In =====

  Future<Map<String, dynamic>> appleSignIn({
    required String authorizationCode,
    required String identityToken,
    required String userIdentifier,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/sso/apple/callback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'authorization_code': authorizationCode,
        'identity_token': identityToken,
        'user_identifier': userIdentifier,
        'email': email,
        'given_name': givenName,
        'family_name': familyName,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      // Check if 2FA is required
      if (data['requires2FA'] == true) {
        return {'requires2FA': true, 'email': data['email']};
      }
      // Otherwise, store token and return success
      await setToken(data['accessToken']);
      return data;
    }

    throw Exception('Apple Sign-In failed: ${res.statusCode} ${res.body}');
  }

  // ===== 2FA Management =====

  Future<Map<String, dynamic>> setup2FA() async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/setup'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('2FA setup failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> verify2FASetup({
    required String secret,
    required String code,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/verify-setup'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'secret': secret, 'code': code}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('2FA verification failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> verify2FA({
    required String email,
    required String password,
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'otp': code}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await setToken(data['accessToken']);
      return {'success': true};
    }

    throw Exception('2FA verification failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> disable2FA({
    required String password,
    required String code,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/disable'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'password': password, 'code': code}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Disable 2FA failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> regenerateBackupCodes() async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/backup-codes'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Regenerate backup codes failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> getBackupCodes() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/auth/2fa/backup-codes'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get backup codes failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> get2FAStatus() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/auth/2fa/status'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get 2FA status failed: ${res.statusCode} ${res.body}');
  }

  // ===== Photo Upload =====

  Future<Map<String, dynamic>> uploadPhoto(dynamic file) async {
    final t = await getToken();
    final req =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/media/upload'));
    req.headers['Authorization'] = 'Bearer $t';

    // Handle both File and XFile types
    if (file is http.MultipartFile) {
      req.files.add(file);
    } else {
      // Assume it's a File object
      req.files.add(await http.MultipartFile.fromPath('file', file.path));
    }

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200) return jsonDecode(body);
    throw Exception('Photo upload failed: ${res.statusCode} $body');
  }

  // ===== Recurring Tasks =====

  Future<List<dynamic>> listRecurringTasks() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/recurring'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'List recurring tasks failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> createRecurringTask(
      Map<String, dynamic> body) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/recurring'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Create recurring task failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> updateRecurringTask(
      String id, Map<String, dynamic> body) async {
    final t = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/tasks/recurring/$id'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Update recurring task failed: ${res.statusCode} ${res.body}');
  }

  Future<void> deleteRecurringTask(String id) async {
    final t = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/tasks/recurring/$id'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
          'Delete recurring task failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> pauseRecurringTask(String id) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/recurring/$id/pause'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200) {
      throw Exception(
          'Pause recurring task failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> resumeRecurringTask(String id) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/recurring/$id/resume'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200) {
      throw Exception(
          'Resume recurring task failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<List<dynamic>> getOccurrences(String recurringTaskId) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/recurring/$recurringTaskId/occurrences'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get occurrences failed: ${res.statusCode} ${res.body}');
  }

  Future<List<dynamic>> previewOccurrences(String recurringTaskId,
      {int limit = 5}) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse(
          '$baseUrl/tasks/recurring/$recurringTaskId/preview?limit=$limit'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Preview occurrences failed: ${res.statusCode} ${res.body}');
  }

  // ===== Task Completion with Photo =====

  Future<Map<String, dynamic>> completeTaskWithPhoto(
    String taskId,
    List<String> photoUrls, {
    String? note,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/complete'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'photo_urls': photoUrls,
        'note': note,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Complete task with photo failed: ${res.statusCode} ${res.body}');
  }

  // ===== Parent Approval =====

  Future<List<dynamic>> getPendingApprovalTasks() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/pending-approval'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Get pending approval tasks failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> approveTask(
      String taskId, int qualityRating) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/approve'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'approved': true,
        'quality_rating': qualityRating,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Approve task failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> rejectTask(String taskId, String reason) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/approve'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'approved': false,
        'reason': reason,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Reject task failed: ${res.statusCode} ${res.body}');
  }

  // ===== Fairness Engine =====

  Future<Map<String, dynamic>> getFairnessData(
      String familyId, String range) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/fairness/family/$familyId?range=$range'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get fairness data failed: ${res.statusCode} ${res.body}');
  }

  Future<List<String>> getFairnessInsights(String familyId) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/fairness/insights/$familyId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<String>.from(data['insights'] ?? []);
    }
    throw Exception(
        'Get fairness insights failed: ${res.statusCode} ${res.body}');
  }

  // ===== Helper Role Management =====

  Future<Map<String, dynamic>> createHelperInvite(
      Map<String, dynamic> body) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/helpers/invite'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Create helper invite failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> verifyHelperCode(String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/helpers/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Verify helper code failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> acceptHelperInvite(String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/helpers/accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['accessToken'] != null) {
        await setToken(data['accessToken']);
      }
      return data;
    }
    throw Exception(
        'Accept helper invite failed: ${res.statusCode} ${res.body}');
  }

  Future<List<dynamic>> listHelpers() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/helpers'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('List helpers failed: ${res.statusCode} ${res.body}');
  }

  Future<void> deactivateHelper(String helperId) async {
    final t = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/helpers/$helperId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
          'Deactivate helper failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<List<dynamic>> getHelperTasks() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/helpers/tasks'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get helper tasks failed: ${res.statusCode} ${res.body}');
  }

  // ===== AI Task Planner (Backend API) =====

  /// Generate AI-powered weekly task plan using backend /ai/plan-week endpoint
  Future<Map<String, dynamic>> aiPlanWeek({
    required String startDate,
    Map<String, dynamic>? preferences,
  }) async {
    final t = await getToken();

    final res = await http.post(
      Uri.parse('$baseUrl/ai/plan-week'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'start_date': startDate,
        'preferences': preferences ?? {},
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('AI plan week failed: ${res.statusCode} ${res.body}');
  }

  /// Apply AI-generated plan (create task assignments)
  Future<Map<String, dynamic>> aiApplyPlan({
    required List<dynamic> weekPlan,
    Map<String, dynamic>? fairness,
  }) async {
    final t = await getToken();

    final res = await http.post(
      Uri.parse('$baseUrl/ai/apply-plan'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'week_plan': weekPlan,
        'fairness': fairness,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Apply plan failed: ${res.statusCode} ${res.body}');
  }

  // ===== AI Vision Cleaning Tips =====

  /// Get AI-powered cleaning tips for a photo using Gemini Vision
  ///
  /// Analyzes photos of stains/messes and provides:
  /// - Surface and stain detection
  /// - Step-by-step cleaning instructions
  /// - Product recommendations and warnings
  /// - Time estimates and difficulty rating
  ///
  /// [imageUrl] - URL of the uploaded photo (from Supabase Storage)
  /// [room] - Optional room context (kitchen, bathroom, bedroom, etc.)
  /// [surface] - Optional surface type (marble, wood, fabric, tile, etc.)
  /// [userInput] - Optional user description of the stain/mess
  Future<Map<String, dynamic>> getCleaningTips({
    required String imageUrl,
    String? room,
    String? surface,
    String? userInput,
  }) async {
    final t = await getToken();

    // Supabase Edge Function URL format
    final edgeFunctionUrl = baseUrl.replaceAll('/v1', '/functions/v1');

    final res = await http.post(
      Uri.parse('$edgeFunctionUrl/ai-vision-tips'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'image_url': imageUrl,
        'context': {
          if (room != null) 'room': room,
          if (surface != null) 'surface': surface,
          if (userInput != null) 'userInput': userInput,
        },
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get cleaning tips failed: ${res.statusCode} ${res.body}');
  }

  // ===== Version Conflict Handling =====

  /// Update task with version check
  Future<Map<String, dynamic>> updateTaskWithVersion(
    String taskId,
    Map<String, dynamic> data,
    int version,
  ) async {
    final t = await getToken();

    // Add version header for optimistic locking
    final res = await http.put(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
        'If-Match': version.toString(),
      },
      body: jsonEncode(data),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else if (res.statusCode == 409) {
      // Conflict detected
      final serverData = jsonDecode(res.body);
      throw ConflictException(
        serverVersion: serverData['version'] ?? version + 1,
        serverData: serverData,
        message: 'Task version conflict: server has newer version',
      );
    } else if (res.statusCode == 412) {
      // Precondition failed (version mismatch)
      final serverData = jsonDecode(res.body);
      throw ConflictException(
        serverVersion: serverData['version'] ?? version + 1,
        serverData: serverData,
        message: 'Task version mismatch',
      );
    }

    throw Exception('Update task failed: ${res.statusCode} ${res.body}');
  }

  /// Update event with version check
  Future<Map<String, dynamic>> updateEventWithVersion(
    String eventId,
    Map<String, dynamic> data,
    int version,
  ) async {
    final t = await getToken();

    final res = await http.put(
      Uri.parse('$baseUrl/events/$eventId'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
        'If-Match': version.toString(),
      },
      body: jsonEncode(data),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else if (res.statusCode == 409 || res.statusCode == 412) {
      // Conflict detected
      final serverData = jsonDecode(res.body);
      throw ConflictException(
        serverVersion: serverData['version'] ?? version + 1,
        serverData: serverData,
        message: 'Event version conflict',
      );
    }

    throw Exception('Update event failed: ${res.statusCode} ${res.body}');
  }

  /// Delete task with version check
  Future<void> deleteTaskWithVersion(String taskId, int version) async {
    final t = await getToken();

    final res = await http.delete(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: {
        'Authorization': 'Bearer $t',
        'If-Match': version.toString(),
      },
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      return;
    } else if (res.statusCode == 409 || res.statusCode == 412) {
      // Conflict detected
      final serverData = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      throw ConflictException(
        serverVersion: serverData['version'] ?? version + 1,
        serverData: serverData,
        message: 'Cannot delete: task was modified on server',
      );
    }

    throw Exception('Delete task failed: ${res.statusCode} ${res.body}');
  }

  /// Delete event with version check
  Future<void> deleteEventWithVersion(String eventId, int version) async {
    final t = await getToken();

    final res = await http.delete(
      Uri.parse('$baseUrl/events/$eventId'),
      headers: {
        'Authorization': 'Bearer $t',
        'If-Match': version.toString(),
      },
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      return;
    } else if (res.statusCode == 409 || res.statusCode == 412) {
      // Conflict detected
      final serverData = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      throw ConflictException(
        serverVersion: serverData['version'] ?? version + 1,
        serverData: serverData,
        message: 'Cannot delete: event was modified on server',
      );
    }

    throw Exception('Delete event failed: ${res.statusCode} ${res.body}');
  }

  /// Fetch latest version from server
  Future<Map<String, dynamic>> fetchLatestTask(String taskId) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Fetch task failed: ${res.statusCode} ${res.body}');
  }

  /// Fetch latest event from server
  Future<Map<String, dynamic>> fetchLatestEvent(String eventId) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/events/$eventId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Fetch event failed: ${res.statusCode} ${res.body}');
  }

  // ===== Voice Commands with Gemini =====

  /// Process voice command using Gemini NLU
  ///
  /// [audioText] - Transcribed text from STT
  /// [locale] - Language code (nl-NL, en-US, de-DE, fr-FR)
  /// [userNames] - List of family member names for entity recognition
  ///
  /// Returns intent with extracted entities:
  /// - intent: create_task | complete_task | show_tasks | etc.
  /// - task_title: string (if applicable)
  /// - assignee: string (if mentioned)
  /// - datetime: ISO string (if mentioned)
  /// - confidence: 0.0-1.0
  Future<Map<String, dynamic>> parseVoiceIntent({
    required String audioText,
    required String locale,
    List<String>? userNames,
  }) async {
    final t = await getToken();

    // Supabase Edge Function URL format
    final edgeFunctionUrl = baseUrl.replaceAll('/v1', '/functions/v1');

    final res = await http.post(
      Uri.parse('$edgeFunctionUrl/voice-intent-parser'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'audio_text': audioText,
        'locale': locale,
        'user_names': userNames ?? [],
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Parse voice intent failed: ${res.statusCode} ${res.body}');
  }

  /// Complete task (mark as done)
  ///
  /// [taskId] - Task ID to complete
  /// [photoUrls] - Optional proof photos
  /// [note] - Optional completion note
  Future<Map<String, dynamic>> completeTask(
    String taskId, {
    List<String>? photoUrls,
    String? note,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/complete'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'photo_urls': photoUrls ?? [],
        'note': note,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Complete task failed: ${res.statusCode} ${res.body}');
  }

  // ===== Study Items & Homework Coach =====

  /// Create study plan using AI homework coach
  ///
  /// Generates backward planning with spaced repetition using Gemini
  /// Returns complete study plan with sessions and quizzes
  static Future<StudyPlanResponse> createStudyPlan(
    CreateStudyPlanRequest request,
  ) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();

    // Supabase Edge Function URL format
    final edgeFunctionUrl = instance.baseUrl.replaceAll('/v1', '/functions/v1');

    final res = await http.post(
      Uri.parse('$edgeFunctionUrl/ai-homework-coach'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(request.toJson()),
    );

    if (res.statusCode == 200) {
      return StudyPlanResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Create study plan failed: ${res.statusCode} ${res.body}');
  }

  /// Get study item by ID
  static Future<StudyItem> getStudyItem(String studyItemId) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();
    final res = await http.get(
      Uri.parse('${instance.baseUrl}/study-items/$studyItemId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      return StudyItem.fromJson(jsonDecode(res.body));
    }
    throw Exception('Get study item failed: ${res.statusCode} ${res.body}');
  }

  /// Get all study items for a user
  static Future<List<StudyItem>> getStudyItems(String userId) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();
    final res = await http.get(
      Uri.parse('${instance.baseUrl}/study-items?user_id=$userId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((json) => StudyItem.fromJson(json)).toList();
    }
    throw Exception('Get study items failed: ${res.statusCode} ${res.body}');
  }

  /// Get all study sessions for a study item
  static Future<List<StudySession>> getStudySessions(String studyItemId) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();
    final res = await http.get(
      Uri.parse(
          '${instance.baseUrl}/study-sessions?study_item_id=$studyItemId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((json) => StudySession.fromJson(json)).toList();
    }
    throw Exception('Get study sessions failed: ${res.statusCode} ${res.body}');
  }

  /// Get a single study session by ID
  static Future<StudySession> getStudySession(String sessionId) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();
    final res = await http.get(
      Uri.parse('${instance.baseUrl}/study-sessions/$sessionId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      return StudySession.fromJson(jsonDecode(res.body));
    }
    throw Exception('Get study session failed: ${res.statusCode} ${res.body}');
  }

  /// Complete a study session
  ///
  /// [sessionId] - Session to complete
  /// [notes] - Optional study notes
  /// [quizScore] - Quiz score (if quiz was taken)
  /// [quizTotal] - Quiz total questions (if quiz was taken)
  static Future<void> completeStudySession(
    String sessionId, {
    String? notes,
    int? quizScore,
    int? quizTotal,
  }) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();
    final res = await http.post(
      Uri.parse('${instance.baseUrl}/study-sessions/$sessionId/complete'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'notes': notes,
        'quiz_score': quizScore,
        'quiz_total': quizTotal,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(
          'Complete study session failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Update study item status
  static Future<void> updateStudyItemStatus(
    String studyItemId,
    StudyStatus status,
  ) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();
    final res = await http.patch(
      Uri.parse('${instance.baseUrl}/study-items/$studyItemId'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status.name}),
    );

    if (res.statusCode != 200) {
      throw Exception(
          'Update study item failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Delete a study item and all its sessions
  static Future<void> deleteStudyItem(String studyItemId) async {
    final instance = ApiClient.instance;
    final t = await instance.getToken();
    final res = await http.delete(
      Uri.parse('${instance.baseUrl}/study-items/$studyItemId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
          'Delete study item failed: ${res.statusCode} ${res.body}');
    }
  }

  // ===== Offline-First Helper Methods =====

  /// Check if device is online
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Create task with offline support
  Future<Map<String, dynamic>> createTaskOffline(
      Map<String, dynamic> taskData) async {
    final taskId = taskData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    taskData['id'] = taskId;

    // Write to local storage first (optimistic UI)
    await FamQuestStorage.instance.put('tasks', taskId, taskData);

    // Queue for sync
    await SyncQueueService.instance.addToQueue(
      entityType: 'tasks',
      entityId: taskId,
      data: taskData,
      operation: 'create',
    );

    // Try online sync if connected
    if (await isOnline()) {
      try {
        final result = await createTask(taskData);
        // Update with server response
        await FamQuestStorage.instance.put('tasks', taskId, result);
        await FamQuestStorage.instance.markClean('tasks', taskId);
        return result;
      } catch (e) {
        // Failed but queued - return local data
        return taskData;
      }
    }

    return taskData;
  }

  /// Update task with offline support
  Future<Map<String, dynamic>> updateTaskOffline(
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    // Get current local version
    final localTask = await FamQuestStorage.instance.get('tasks', taskId);
    final version = localTask?['version'] ?? 1;

    // Merge updates
    final updatedTask = {...?localTask, ...updates};
    updatedTask['version'] = version;

    // Write to local storage first (optimistic UI)
    await FamQuestStorage.instance.put('tasks', taskId, updatedTask);

    // Queue for sync
    await SyncQueueService.instance.addToQueue(
      entityType: 'tasks',
      entityId: taskId,
      data: updatedTask,
      operation: 'update',
    );

    // Try online sync if connected
    if (await isOnline()) {
      try {
        final result = await updateTaskWithVersion(taskId, updatedTask, version);
        // Update with server response
        await FamQuestStorage.instance.put('tasks', taskId, result);
        await FamQuestStorage.instance.markClean('tasks', taskId);
        return result;
      } on ConflictException {
        // Conflict will be handled by sync service
        rethrow;
      } catch (e) {
        // Failed but queued - return local data
        return updatedTask;
      }
    }

    return updatedTask;
  }

  /// Delete task with offline support
  Future<void> deleteTaskOffline(String taskId) async {
    // Get current local version
    final localTask = await FamQuestStorage.instance.get('tasks', taskId);
    final version = localTask?['version'] ?? 1;

    // Soft delete in local storage
    await FamQuestStorage.instance.delete('tasks', taskId);

    // Queue for sync
    await SyncQueueService.instance.addToQueue(
      entityType: 'tasks',
      entityId: taskId,
      data: {'id': taskId, 'version': version},
      operation: 'delete',
    );

    // Try online sync if connected
    if (await isOnline()) {
      try {
        await deleteTaskWithVersion(taskId, version);
        await FamQuestStorage.instance.hardDelete('tasks', taskId);
      } catch (e) {
        // Failed but queued
      }
    }
  }

  /// Create event with offline support
  Future<Map<String, dynamic>> createEventOffline(
      Map<String, dynamic> eventData) async {
    final eventId = eventData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    eventData['id'] = eventId;

    // Write to local storage first
    await FamQuestStorage.instance.put('events', eventId, eventData);

    // Queue for sync
    await SyncQueueService.instance.addToQueue(
      entityType: 'events',
      entityId: eventId,
      data: eventData,
      operation: 'create',
    );

    return eventData;
  }

  /// Update event with offline support
  Future<Map<String, dynamic>> updateEventOffline(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    // Get current local version
    final localEvent = await FamQuestStorage.instance.get('events', eventId);
    final version = localEvent?['version'] ?? 1;

    // Merge updates
    final updatedEvent = {...?localEvent, ...updates};
    updatedEvent['version'] = version;

    // Write to local storage first
    await FamQuestStorage.instance.put('events', eventId, updatedEvent);

    // Queue for sync
    await SyncQueueService.instance.addToQueue(
      entityType: 'events',
      entityId: eventId,
      data: updatedEvent,
      operation: 'update',
    );

    // Try online sync if connected
    if (await isOnline()) {
      try {
        final result = await updateEventWithVersion(eventId, updatedEvent, version);
        await FamQuestStorage.instance.put('events', eventId, result);
        await FamQuestStorage.instance.markClean('events', eventId);
        return result;
      } on ConflictException {
        rethrow;
      } catch (e) {
        return updatedEvent;
      }
    }

    return updatedEvent;
  }

  /// Delete event with offline support
  Future<void> deleteEventOffline(String eventId) async {
    final localEvent = await FamQuestStorage.instance.get('events', eventId);
    final version = localEvent?['version'] ?? 1;

    await FamQuestStorage.instance.delete('events', eventId);

    await SyncQueueService.instance.addToQueue(
      entityType: 'events',
      entityId: eventId,
      data: {'id': eventId, 'version': version},
      operation: 'delete',
    );

    if (await isOnline()) {
      try {
        await deleteEventWithVersion(eventId, version);
        await FamQuestStorage.instance.hardDelete('events', eventId);
      } catch (e) {
        // Failed but queued
      }
    }
  }

  /// Get tasks from local storage (offline-first)
  Future<List<Map<String, dynamic>>> getTasksOffline() async {
    final tasks = await FamQuestStorage.instance.getAll('tasks');
    return tasks.where((t) => t['isDeleted'] != true).toList();
  }

  /// Get events from local storage (offline-first)
  Future<List<Map<String, dynamic>>> getEventsOffline() async {
    final events = await FamQuestStorage.instance.getAll('events');
    return events.where((e) => e['isDeleted'] != true).toList();
  }

  /// Get single task from local storage
  Future<Map<String, dynamic>?> getTaskOffline(String taskId) async {
    return FamQuestStorage.instance.get('tasks', taskId);
  }

  /// Get single event from local storage
  Future<Map<String, dynamic>?> getEventOffline(String eventId) async {
    return FamQuestStorage.instance.get('events', eventId);
  }

  // ===== Notification Center API =====

  /// List all notifications for current user
  ///
  /// Returns list of notifications sorted by created_at DESC
  Future<List<dynamic>> listNotifications() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('List notifications failed: ${res.statusCode} ${res.body}');
  }

  /// Mark notification as read
  ///
  /// [notificationId] - ID of notification to mark as read
  Future<void> markNotificationAsRead(String notificationId) async {
    final t = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
          'Mark notification as read failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    final t = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/notifications/mark-all-read'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
          'Mark all notifications as read failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Delete notification
  ///
  /// [notificationId] - ID of notification to delete
  Future<void> deleteNotification(String notificationId) async {
    final t = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/notifications/$notificationId'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
          'Delete notification failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Clear all notifications (delete all)
  Future<void> clearAllNotifications() async {
    final t = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/notifications/clear'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(
          'Clear all notifications failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['count'] as int;
    }
    throw Exception(
        'Get unread notification count failed: ${res.statusCode} ${res.body}');
  }

  // ===== In-App Purchase API =====

  /// Verify purchase receipt with backend
  ///
  /// [productId] - Product ID purchased
  /// [transactionId] - Transaction/purchase ID from store
  /// [receipt] - Receipt data from App Store or Google Play
  /// [platform] - 'ios' or 'android'
  ///
  /// Returns verification result with tier and expiry date
  Future<Map<String, dynamic>> verifyPurchaseReceipt({
    required String productId,
    required String transactionId,
    required String receipt,
    required String platform,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/purchases/verify'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'product_id': productId,
        'transaction_id': transactionId,
        'receipt': receipt,
        'platform': platform,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Verify purchase failed: ${res.statusCode} ${res.body}');
  }

  /// Get current subscription status for user
  ///
  /// Returns:
  /// {
  ///   "tier": "free"|"family_unlock"|"premium_monthly"|"premium_yearly",
  ///   "is_active": bool,
  ///   "expiry_date": ISO8601 string (nullable),
  ///   "auto_renew": bool,
  ///   "platform": "ios"|"android" (nullable)
  /// }
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/users/subscription-status'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Get subscription status failed: ${res.statusCode} ${res.body}');
  }

  /// Restore purchases from store (sync with backend)
  ///
  /// Call this after restoring purchases from store to sync backend status
  Future<Map<String, dynamic>> restorePurchasesBackend() async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/purchases/restore'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Restore purchases failed: ${res.statusCode} ${res.body}');
  }

  /// Cancel subscription (opens store subscription management)
  ///
  /// This endpoint returns the platform-specific URL to manage subscriptions
  Future<Map<String, dynamic>> getSubscriptionManagementUrl() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/purchases/manage-subscription'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(
        'Get subscription management URL failed: ${res.statusCode} ${res.body}');
  }

  // ============================================================================
  // GDPR Compliance Endpoints
  // ============================================================================

  /// Export all user data (GDPR Article 20 - Right to Data Portability)
  ///
  /// Returns user data in JSON format including:
  /// - Profile information
  /// - Tasks, events, points, badges
  /// - Study items and sessions
  /// - Settings and preferences
  Future<Map<String, dynamic>> exportUserData({bool includeFamily = false}) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/gdpr/export?include_family=$includeFamily'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Export user data failed: ${res.statusCode} ${res.body}');
  }

  /// Request account deletion (GDPR Article 17 - Right to be Forgotten)
  ///
  /// Marks account for deletion with 30-day grace period
  /// Returns deletion request details
  Future<Map<String, dynamic>> requestAccountDeletion({
    required String password,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/gdpr/delete-account'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': password}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Account deletion request failed: ${res.statusCode} ${res.body}');
  }

  /// Cancel pending account deletion (within 30-day grace period)
  Future<Map<String, dynamic>> cancelAccountDeletion() async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/gdpr/cancel-deletion'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Cancel deletion failed: ${res.statusCode} ${res.body}');
  }

  /// Get account deletion status
  Future<Map<String, dynamic>> getAccountDeletionStatus() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/gdpr/deletion-status'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get deletion status failed: ${res.statusCode} ${res.body}');
  }

  /// Set GDPR consent preferences
  ///
  /// Tracks user consent for:
  /// - Analytics tracking
  /// - Personalized content
  /// - Marketing communications
  Future<Map<String, dynamic>> setGdprConsent({
    required bool analyticsConsent,
    required bool marketingConsent,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/gdpr/consent'),
      headers: {
        'Authorization': 'Bearer $t',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'analytics_consent': analyticsConsent,
        'marketing_consent': marketingConsent,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Set GDPR consent failed: ${res.statusCode} ${res.body}');
  }

  /// Get current GDPR consent preferences
  Future<Map<String, dynamic>> getGdprConsent() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/gdpr/consent'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get GDPR consent failed: ${res.statusCode} ${res.body}');
  }

  // ============================================================================
  // Admin Revenue Dashboard Endpoints
  // ============================================================================

  /// Get revenue statistics (admin only)
  ///
  /// Returns:
  /// - Total revenue (all time, this month)
  /// - Active subscriptions count
  /// - Conversion rates (free → paid)
  /// - Churn rate
  /// - Revenue trend data (last 6 months)
  Future<Map<String, dynamic>> getRevenueStats() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/admin/revenue/stats'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get revenue stats failed: ${res.statusCode} ${res.body}');
  }

  /// Get subscription analytics (admin only)
  Future<Map<String, dynamic>> getSubscriptionAnalytics() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/admin/revenue/subscriptions'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get subscription analytics failed: ${res.statusCode} ${res.body}');
  }
}

/// Conflict exception for version mismatches
class ConflictException implements Exception {
  final int serverVersion;
  final Map<String, dynamic> serverData;
  final String message;

  ConflictException({
    required this.serverVersion,
    required this.serverData,
    required this.message,
  });

  @override
  String toString() => 'ConflictException: $message';
}
