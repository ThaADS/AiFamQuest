import 'package:freezed_annotation/freezed_annotation.dart';

part 'study_models.freezed.dart';
part 'study_models.g.dart';

/// Study difficulty levels
enum StudyDifficulty {
  @JsonValue('easy')
  easy,
  @JsonValue('medium')
  medium,
  @JsonValue('hard')
  hard,
}

/// Study item status
enum StudyStatus {
  @JsonValue('planning')
  planning,
  @JsonValue('active')
  active,
  @JsonValue('completed')
  completed,
  @JsonValue('cancelled')
  cancelled,
}

/// Quiz question types
enum QuizQuestionType {
  @JsonValue('text')
  text,
  @JsonValue('multiple_choice')
  multipleChoice,
}

/// Quiz question model
@freezed
class QuizQuestion with _$QuizQuestion {
  const factory QuizQuestion({
    required String q, // Question text
    String? a, // Answer for text questions
    @JsonKey(name: 'type') required QuizQuestionType questionType,
    List<String>? options, // For multiple choice
    String? answer, // Correct answer for multiple choice
  }) = _QuizQuestion;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) =>
      _$QuizQuestionFromJson(json);
}

/// Quiz model
@freezed
class StudyQuiz with _$StudyQuiz {
  const factory StudyQuiz({
    required int sessionIndex,
    required List<QuizQuestion> questions,
  }) = _StudyQuiz;

  factory StudyQuiz.fromJson(Map<String, dynamic> json) =>
      _$StudyQuizFromJson(json);
}

/// Study session milestone
@freezed
class StudyMilestone with _$StudyMilestone {
  const factory StudyMilestone({
    required String date,
    required String checkpoint,
  }) = _StudyMilestone;

  factory StudyMilestone.fromJson(Map<String, dynamic> json) =>
      _$StudyMilestoneFromJson(json);
}

/// Study session plan item
@freezed
class StudySessionPlan with _$StudySessionPlan {
  const factory StudySessionPlan({
    required String date,
    required int duration,
    required String focus,
    required List<String> tasks,
    required String difficulty,
  }) = _StudySessionPlan;

  factory StudySessionPlan.fromJson(Map<String, dynamic> json) =>
      _$StudySessionPlanFromJson(json);
}

/// Complete study plan from AI
@freezed
class StudyPlan with _$StudyPlan {
  const factory StudyPlan({
    required List<StudySessionPlan> plan,
    required List<StudyMilestone> milestones,
    required List<StudyQuiz> quizzes,
    required double totalEstimatedHours,
    required double confidenceScore,
  }) = _StudyPlan;

  factory StudyPlan.fromJson(Map<String, dynamic> json) =>
      _$StudyPlanFromJson(json);
}

/// Study item (main model)
@freezed
class StudyItem with _$StudyItem {
  const factory StudyItem({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String subject,
    required String topic,
    @JsonKey(name: 'test_date') required DateTime testDate,
    @JsonKey(name: 'study_plan') required StudyPlan studyPlan,
    required StudyStatus status,
    required StudyDifficulty difficulty,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _StudyItem;

  factory StudyItem.fromJson(Map<String, dynamic> json) =>
      _$StudyItemFromJson(json);
}

/// Study session (individual session)
@freezed
class StudySession with _$StudySession {
  const factory StudySession({
    required String id,
    @JsonKey(name: 'study_item_id') required String studyItemId,
    @JsonKey(name: 'scheduled_at') required DateTime scheduledAt,
    required int duration,
    required String focus,
    required List<String> tasks,
    required bool completed,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    @JsonKey(name: 'quiz_score') int? quizScore,
    @JsonKey(name: 'quiz_total') int? quizTotal,
    String? notes,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _StudySession;

  factory StudySession.fromJson(Map<String, dynamic> json) =>
      _$StudySessionFromJson(json);
}

/// Request model for creating a study plan
@freezed
class CreateStudyPlanRequest with _$CreateStudyPlanRequest {
  const factory CreateStudyPlanRequest({
    required String userId,
    required String subject,
    required String topic,
    required String examDate,
    required StudyDifficulty difficulty,
    required int availableTime,
  }) = _CreateStudyPlanRequest;

  factory CreateStudyPlanRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateStudyPlanRequestFromJson(json);

  @override
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'subject': subject,
      'topic': topic,
      'examDate': examDate,
      'difficulty': difficulty.name,
      'availableTime': availableTime,
    };
  }
}

/// Response model from AI homework coach
@freezed
class StudyPlanResponse with _$StudyPlanResponse {
  const factory StudyPlanResponse({
    required bool success,
    required StudyItem studyItem,
    required StudyPlan plan,
  }) = _StudyPlanResponse;

  factory StudyPlanResponse.fromJson(Map<String, dynamic> json) =>
      _$StudyPlanResponseFromJson(json);
}

/// Extension for difficulty display
extension StudyDifficultyX on StudyDifficulty {
  String get displayName {
    switch (this) {
      case StudyDifficulty.easy:
        return 'Easy';
      case StudyDifficulty.medium:
        return 'Medium';
      case StudyDifficulty.hard:
        return 'Hard';
    }
  }

  String get emoji {
    switch (this) {
      case StudyDifficulty.easy:
        return '😊';
      case StudyDifficulty.medium:
        return '🤔';
      case StudyDifficulty.hard:
        return '😰';
    }
  }

  int get sessionCount {
    switch (this) {
      case StudyDifficulty.easy:
        return 3;
      case StudyDifficulty.medium:
        return 5;
      case StudyDifficulty.hard:
        return 7;
    }
  }
}

/// Extension for status display
extension StudyStatusX on StudyStatus {
  String get displayName {
    switch (this) {
      case StudyStatus.planning:
        return 'Planning';
      case StudyStatus.active:
        return 'Active';
      case StudyStatus.completed:
        return 'Completed';
      case StudyStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get emoji {
    switch (this) {
      case StudyStatus.planning:
        return '📝';
      case StudyStatus.active:
        return '📚';
      case StudyStatus.completed:
        return '✅';
      case StudyStatus.cancelled:
        return '❌';
    }
  }
}
