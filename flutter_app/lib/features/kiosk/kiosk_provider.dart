/// Kiosk mode data provider with API integration
///
/// Provides data for kiosk displays (today view and week view)
/// with automatic refresh and caching support.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../api/client.dart';
import '../../models/kiosk_models.dart';

/// Provider for kiosk today data
final kioskTodayDataProvider = FutureProvider.autoDispose<KioskTodayData>((ref) async {
  final client = ApiClient.instance;
  final token = await client.getToken();

  if (token == null) {
    throw Exception('Not authenticated');
  }

  final response = await http.get(
    Uri.parse('${client.baseUrl}/kiosk/today'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return KioskTodayData.fromJson(data);
  } else {
    throw Exception('Failed to load kiosk today data: ${response.statusCode}');
  }
});

/// Provider for kiosk week data
final kioskWeekDataProvider = FutureProvider.autoDispose<KioskWeekData>((ref) async {
  final client = ApiClient.instance;
  final token = await client.getToken();

  if (token == null) {
    throw Exception('Not authenticated');
  }

  final response = await http.get(
    Uri.parse('${client.baseUrl}/kiosk/week'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return KioskWeekData.fromJson(data);
  } else {
    throw Exception('Failed to load kiosk week data: ${response.statusCode}');
  }
});

/// Provider for PIN verification
class KioskPinNotifier extends StateNotifier<AsyncValue<bool>> {
  KioskPinNotifier() : super(const AsyncValue.data(false));

  /// Verify kiosk exit PIN
  Future<bool> verifyPin(String pin) async {
    state = const AsyncValue.loading();

    try {
      final client = ApiClient.instance;
      final token = await client.getToken();

      if (token == null) {
        state = AsyncValue.error('Not authenticated', StackTrace.current);
        return false;
      }

      final response = await http.post(
        Uri.parse('${client.baseUrl}/kiosk/verify-pin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pin': pin}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final isValid = data['valid'] as bool? ?? false;
        state = AsyncValue.data(isValid);
        return isValid;
      } else {
        state = const AsyncValue.data(false);
        return false;
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      return false;
    }
  }
}

/// Provider for kiosk PIN verification
final kioskPinProvider = StateNotifierProvider<KioskPinNotifier, AsyncValue<bool>>((ref) {
  return KioskPinNotifier();
});

/// Extension methods for ApiClient (kiosk-specific)
extension KioskApiExtensions on ApiClient {
  /// Get today's kiosk data
  Future<KioskTodayData> getKioskToday() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/kiosk/today'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return KioskTodayData.fromJson(data);
    } else {
      throw Exception('Failed to load kiosk today data: ${response.statusCode}');
    }
  }

  /// Get week kiosk data
  Future<KioskWeekData> getKioskWeek() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/kiosk/week'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return KioskWeekData.fromJson(data);
    } else {
      throw Exception('Failed to load kiosk week data: ${response.statusCode}');
    }
  }

  /// Verify kiosk exit PIN
  Future<bool> verifyKioskPin(String pin) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/kiosk/verify-pin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['valid'] as bool? ?? false;
    } else {
      return false;
    }
  }
}
