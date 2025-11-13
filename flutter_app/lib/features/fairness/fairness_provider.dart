import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/client.dart';
import '../../models/fairness_models.dart';

/// Provider for fairness data with date range filtering
final fairnessProvider = FutureProvider.family<FairnessData, DateRange>(
  (ref, range) async {
    final client = ApiClient.instance;
    final familyId = 'current'; // TODO: Get from current user provider
    final data = await client.getFairnessData(familyId, range.apiValue);
    return FairnessData.fromJson(data);
  },
);

/// Provider for fairness insights
final fairnessInsightsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) async {
    final client = ApiClient.instance;
    final familyId = 'current'; // TODO: Get from current user provider
    return await client.getFairnessInsights(familyId);
  },
);

/// State provider for selected date range
final selectedDateRangeProvider = StateProvider<DateRange>((ref) => DateRange.thisWeek);

/// Provider for selected user (for filtering)
final selectedUserIdProvider = StateProvider<String?>((ref) => null);
