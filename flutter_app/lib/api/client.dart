import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../offline_queue.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  final _storage = const FlutterSecureStorage();
  String baseUrl = const String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');

  Future<bool> hasToken() async => (await _storage.read(key: 'accessToken'))?.isNotEmpty == true;
  Future<void> setToken(String token) async => _storage.write(key: 'accessToken', value: token);
  Future<String?> getToken() async => _storage.read(key: 'accessToken');

  Future<Map<String,dynamic>> login(String email, String password, {String? otp}) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'email': email, 'password': password, 'otp': otp}));
    if (res.statusCode == 200) { final data = jsonDecode(res.body); await setToken(data['accessToken']); return data; }
    throw Exception('Login failed: ${res.statusCode} ${res.body}');
  }

  Future<List<dynamic>> listTasks() async {
    final t = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/tasks'), headers: {'Authorization':'Bearer $t'});
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('List tasks failed');
  }

  Future<Map<String,dynamic>> createTask(Map<String,dynamic> body) async {
    final t = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/tasks'), headers: {'Authorization':'Bearer $t','Content-Type':'application/json'}, body: jsonEncode(body));
      if (res.statusCode == 200) return jsonDecode(res.body);
      throw Exception('Create task failed');
    } catch (_) {
      await OfflineQueue.instance.enqueue({'op':'POST','path':'/tasks','body':body});
      return {'queued': true};
    }
  }

  Future<void> flushQueue() async {
    final t = await getToken();
    final list = await OfflineQueue.instance.load();
    for (final op in list) {
      final method = op['op'], path = op['path'], body = op['body'];
      final uri = Uri.parse('$baseUrl$path');
      if (method == 'POST') {
        await http.post(uri, headers: {'Authorization':'Bearer $t','Content-Type':'application/json'}, body: jsonEncode(body));
      }
    }
    await OfflineQueue.instance.clear();
  }

  Future<List<dynamic>> listRewards() async {
    final t = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/rewards'), headers: {'Authorization':'Bearer $t'});
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('List rewards failed');
  }

  Future<Map<String,dynamic>> uploadVision(String filename, List<int> bytes, {String description = ""}) async {
    final t = await getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/ai/vision_upload'));
    req.headers['Authorization'] = 'Bearer $t';
    req.fields['description'] = description;
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode == 200) return jsonDecode(body);
    throw Exception('Vision upload failed: ${res.statusCode} $body');
  }

  Future<Map<String,dynamic>> aiPlan(Map<String,dynamic> weekCtx) async {
    final t = await getToken();
    final res = await http.post(Uri.parse('$baseUrl/ai/planner'), headers: {'Authorization':'Bearer $t', 'Content-Type':'application/json'}, body: jsonEncode({'weekContext': weekCtx}));
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('AI plan failed');
  }

  // ===== Apple Sign-In =====

  Future<Map<String,dynamic>> appleSignIn({
    required String authorizationCode,
    required String identityToken,
    required String userIdentifier,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/sso/apple/callback'),
      headers: {'Content-Type':'application/json'},
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

  Future<Map<String,dynamic>> setup2FA() async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/setup'),
      headers: {'Authorization':'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('2FA setup failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String,dynamic>> verify2FASetup({
    required String secret,
    required String code,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/verify-setup'),
      headers: {'Authorization':'Bearer $t', 'Content-Type':'application/json'},
      body: jsonEncode({'secret': secret, 'code': code}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('2FA verification failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String,dynamic>> verify2FA({
    required String email,
    required String password,
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'otp': code}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await setToken(data['accessToken']);
      return {'success': true};
    }

    throw Exception('2FA verification failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String,dynamic>> disable2FA({
    required String password,
    required String code,
  }) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/disable'),
      headers: {'Authorization':'Bearer $t', 'Content-Type':'application/json'},
      body: jsonEncode({'password': password, 'code': code}),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Disable 2FA failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String,dynamic>> regenerateBackupCodes() async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/2fa/backup-codes'),
      headers: {'Authorization':'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Regenerate backup codes failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String,dynamic>> getBackupCodes() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/auth/2fa/backup-codes'),
      headers: {'Authorization':'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get backup codes failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String,dynamic>> get2FAStatus() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/auth/2fa/status'),
      headers: {'Authorization':'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get 2FA status failed: ${res.statusCode} ${res.body}');
  }

  // ===== Photo Upload =====

  Future<Map<String, dynamic>> uploadPhoto(dynamic file) async {
    final t = await getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/media/upload'));
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
    throw Exception('List recurring tasks failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> createRecurringTask(Map<String, dynamic> body) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/recurring'),
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Create recurring task failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> updateRecurringTask(String id, Map<String, dynamic> body) async {
    final t = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/tasks/recurring/$id'),
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Update recurring task failed: ${res.statusCode} ${res.body}');
  }

  Future<void> deleteRecurringTask(String id) async {
    final t = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/tasks/recurring/$id'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Delete recurring task failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> pauseRecurringTask(String id) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/recurring/$id/pause'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200) {
      throw Exception('Pause recurring task failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> resumeRecurringTask(String id) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/recurring/$id/resume'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode != 200) {
      throw Exception('Resume recurring task failed: ${res.statusCode} ${res.body}');
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

  Future<List<dynamic>> previewOccurrences(String recurringTaskId, {int limit = 5}) async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/recurring/$recurringTaskId/preview?limit=$limit'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Preview occurrences failed: ${res.statusCode} ${res.body}');
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
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'photo_urls': photoUrls,
        'note': note,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Complete task with photo failed: ${res.statusCode} ${res.body}');
  }

  // ===== Parent Approval =====

  Future<List<dynamic>> getPendingApprovalTasks() async {
    final t = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/pending-approval'),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Get pending approval tasks failed: ${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> approveTask(String taskId, int qualityRating) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/approve'),
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
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
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'approved': false,
        'reason': reason,
      }),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Reject task failed: ${res.statusCode} ${res.body}');
  }

  // ===== Fairness Engine =====

  Future<Map<String, dynamic>> getFairnessData(String familyId, String range) async {
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
    throw Exception('Get fairness insights failed: ${res.statusCode} ${res.body}');
  }

  // ===== Helper Role Management =====

  Future<Map<String, dynamic>> createHelperInvite(Map<String, dynamic> body) async {
    final t = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/helpers/invite'),
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Create helper invite failed: ${res.statusCode} ${res.body}');
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
    throw Exception('Accept helper invite failed: ${res.statusCode} ${res.body}');
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
      throw Exception('Deactivate helper failed: ${res.statusCode} ${res.body}');
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
}
