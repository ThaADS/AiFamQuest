import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_models.dart';
import '../api/client.dart';
import '../features/study/spaced_repetition_scheduler.dart';

/// State for study items
class StudyItemsState {
  final List<StudyItem> items;
  final bool isLoading;
  final String? error;

  const StudyItemsState({
    required this.items,
    this.isLoading = false,
    this.error,
  });

  StudyItemsState copyWith({
    List<StudyItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return StudyItemsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for study items (per user)
class StudyItemsNotifier extends StateNotifier<StudyItemsState> {
  final String userId;

  StudyItemsNotifier(this.userId) : super(const StudyItemsState(items: [])) {
    loadStudyItems();
  }

  Future<void> loadStudyItems() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final items = await ApiClient.getStudyItems(userId);
      state = StudyItemsState(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createStudyPlan({
    required String subject,
    required String topic,
    required String examDate,
    required StudyDifficulty difficulty,
    required int availableTime,
  }) async {
    try {
      final request = CreateStudyPlanRequest(
        userId: userId,
        subject: subject,
        topic: topic,
        examDate: examDate,
        difficulty: difficulty,
        availableTime: availableTime,
      );

      await ApiClient.createStudyPlan(request);

      await loadStudyItems();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateStudyItemStatus(
    String studyItemId,
    StudyStatus status,
  ) async {
    try {
      await ApiClient.updateStudyItemStatus(studyItemId, status);
      await loadStudyItems();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteStudyItem(String studyItemId) async {
    try {
      await ApiClient.deleteStudyItem(studyItemId);
      await loadStudyItems();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

/// Provider factory for study items by user ID
final studyItemsProvider = StateNotifierProvider.family<StudyItemsNotifier, StudyItemsState, String>(
  (ref, userId) => StudyItemsNotifier(userId),
);

/// State for study sessions
class StudySessionsState {
  final List<StudySession> sessions;
  final bool isLoading;
  final String? error;

  const StudySessionsState({
    required this.sessions,
    this.isLoading = false,
    this.error,
  });

  StudySessionsState copyWith({
    List<StudySession>? sessions,
    bool? isLoading,
    String? error,
  }) {
    return StudySessionsState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for study sessions (per study item)
class StudySessionsNotifier extends StateNotifier<StudySessionsState> {
  final String studyItemId;

  StudySessionsNotifier(this.studyItemId) : super(const StudySessionsState(sessions: [])) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sessions = await ApiClient.getStudySessions(studyItemId);
      state = StudySessionsState(sessions: sessions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> completeSession({
    required String sessionId,
    String? notes,
    int? quizScore,
    int? quizTotal,
  }) async {
    try {
      await ApiClient.completeStudySession(
        sessionId,
        notes: notes,
        quizScore: quizScore,
        quizTotal: quizTotal,
      );

      await loadSessions();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Get today's sessions
  List<StudySession> get todaySessions {
    return SpacedRepetitionScheduler.getTodaySessions(state.sessions);
  }

  /// Get upcoming sessions (next 7 days)
  List<StudySession> get upcomingSessions {
    return SpacedRepetitionScheduler.getUpcomingSessions(state.sessions);
  }

  /// Get overdue sessions
  List<StudySession> get overdueSessions {
    return SpacedRepetitionScheduler.getOverdueSessions(state.sessions);
  }
}

/// Provider factory for study sessions by study item ID
final studySessionsProvider = StateNotifierProvider.family<StudySessionsNotifier, StudySessionsState, String>(
  (ref, studyItemId) => StudySessionsNotifier(studyItemId),
);

/// Provider for study statistics
final studyStatisticsProvider = Provider.family<StudyStatistics?, String>((ref, userId) {
  final studyItemsState = ref.watch(studyItemsProvider(userId));

  if (studyItemsState.isLoading || studyItemsState.items.isEmpty) {
    return null;
  }

  // Load sessions for all study items
  final sessionsByItem = <List<StudySession>>[];
  for (final item in studyItemsState.items) {
    final sessionsState = ref.watch(studySessionsProvider(item.id));
    sessionsByItem.add(sessionsState.sessions);
  }

  return SpacedRepetitionScheduler.calculateStatistics(
    studyItemsState.items,
    sessionsByItem,
  );
});

/// Provider for next review calculation
final nextReviewProvider = Provider.family<ScheduledReview, NextReviewParams>((ref, params) {
  return SpacedRepetitionScheduler.calculateNextReview(
    lastReviewDate: params.lastReviewDate,
    quality: params.quality,
    easinessFactor: params.easinessFactor,
    repetitions: params.repetitions,
  );
});

/// Parameters for next review calculation
class NextReviewParams {
  final DateTime lastReviewDate;
  final int quality;
  final double easinessFactor;
  final int repetitions;

  const NextReviewParams({
    required this.lastReviewDate,
    required this.quality,
    this.easinessFactor = 2.5,
    this.repetitions = 0,
  });
}
