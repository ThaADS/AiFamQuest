// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$QuizQuestionImpl _$$QuizQuestionImplFromJson(Map<String, dynamic> json) =>
    _$QuizQuestionImpl(
      q: json['q'] as String,
      a: json['a'] as String?,
      questionType: $enumDecode(_$QuizQuestionTypeEnumMap, json['type']),
      options:
          (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      answer: json['answer'] as String?,
    );

Map<String, dynamic> _$$QuizQuestionImplToJson(_$QuizQuestionImpl instance) =>
    <String, dynamic>{
      'q': instance.q,
      'a': instance.a,
      'type': _$QuizQuestionTypeEnumMap[instance.questionType]!,
      'options': instance.options,
      'answer': instance.answer,
    };

const _$QuizQuestionTypeEnumMap = {
  QuizQuestionType.text: 'text',
  QuizQuestionType.multipleChoice: 'multiple_choice',
};

_$StudyQuizImpl _$$StudyQuizImplFromJson(Map<String, dynamic> json) =>
    _$StudyQuizImpl(
      sessionIndex: (json['sessionIndex'] as num).toInt(),
      questions: (json['questions'] as List<dynamic>)
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$StudyQuizImplToJson(_$StudyQuizImpl instance) =>
    <String, dynamic>{
      'sessionIndex': instance.sessionIndex,
      'questions': instance.questions,
    };

_$StudyMilestoneImpl _$$StudyMilestoneImplFromJson(Map<String, dynamic> json) =>
    _$StudyMilestoneImpl(
      date: json['date'] as String,
      checkpoint: json['checkpoint'] as String,
    );

Map<String, dynamic> _$$StudyMilestoneImplToJson(
        _$StudyMilestoneImpl instance) =>
    <String, dynamic>{
      'date': instance.date,
      'checkpoint': instance.checkpoint,
    };

_$StudySessionPlanImpl _$$StudySessionPlanImplFromJson(
        Map<String, dynamic> json) =>
    _$StudySessionPlanImpl(
      date: json['date'] as String,
      duration: (json['duration'] as num).toInt(),
      focus: json['focus'] as String,
      tasks: (json['tasks'] as List<dynamic>).map((e) => e as String).toList(),
      difficulty: json['difficulty'] as String,
    );

Map<String, dynamic> _$$StudySessionPlanImplToJson(
        _$StudySessionPlanImpl instance) =>
    <String, dynamic>{
      'date': instance.date,
      'duration': instance.duration,
      'focus': instance.focus,
      'tasks': instance.tasks,
      'difficulty': instance.difficulty,
    };

_$StudyPlanImpl _$$StudyPlanImplFromJson(Map<String, dynamic> json) =>
    _$StudyPlanImpl(
      plan: (json['plan'] as List<dynamic>)
          .map((e) => StudySessionPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
      milestones: (json['milestones'] as List<dynamic>)
          .map((e) => StudyMilestone.fromJson(e as Map<String, dynamic>))
          .toList(),
      quizzes: (json['quizzes'] as List<dynamic>)
          .map((e) => StudyQuiz.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalEstimatedHours: (json['totalEstimatedHours'] as num).toDouble(),
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
    );

Map<String, dynamic> _$$StudyPlanImplToJson(_$StudyPlanImpl instance) =>
    <String, dynamic>{
      'plan': instance.plan,
      'milestones': instance.milestones,
      'quizzes': instance.quizzes,
      'totalEstimatedHours': instance.totalEstimatedHours,
      'confidenceScore': instance.confidenceScore,
    };

_$StudyItemImpl _$$StudyItemImplFromJson(Map<String, dynamic> json) =>
    _$StudyItemImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subject: json['subject'] as String,
      topic: json['topic'] as String,
      testDate: DateTime.parse(json['test_date'] as String),
      studyPlan: StudyPlan.fromJson(json['study_plan'] as Map<String, dynamic>),
      status: $enumDecode(_$StudyStatusEnumMap, json['status']),
      difficulty: $enumDecode(_$StudyDifficultyEnumMap, json['difficulty']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$StudyItemImplToJson(_$StudyItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'subject': instance.subject,
      'topic': instance.topic,
      'test_date': instance.testDate.toIso8601String(),
      'study_plan': instance.studyPlan,
      'status': _$StudyStatusEnumMap[instance.status]!,
      'difficulty': _$StudyDifficultyEnumMap[instance.difficulty]!,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$StudyStatusEnumMap = {
  StudyStatus.planning: 'planning',
  StudyStatus.active: 'active',
  StudyStatus.completed: 'completed',
  StudyStatus.cancelled: 'cancelled',
};

const _$StudyDifficultyEnumMap = {
  StudyDifficulty.easy: 'easy',
  StudyDifficulty.medium: 'medium',
  StudyDifficulty.hard: 'hard',
};

_$StudySessionImpl _$$StudySessionImplFromJson(Map<String, dynamic> json) =>
    _$StudySessionImpl(
      id: json['id'] as String,
      studyItemId: json['study_item_id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      duration: (json['duration'] as num).toInt(),
      focus: json['focus'] as String,
      tasks: (json['tasks'] as List<dynamic>).map((e) => e as String).toList(),
      completed: json['completed'] as bool,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      quizScore: (json['quiz_score'] as num?)?.toInt(),
      quizTotal: (json['quiz_total'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$StudySessionImplToJson(_$StudySessionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'study_item_id': instance.studyItemId,
      'scheduled_at': instance.scheduledAt.toIso8601String(),
      'duration': instance.duration,
      'focus': instance.focus,
      'tasks': instance.tasks,
      'completed': instance.completed,
      'completed_at': instance.completedAt?.toIso8601String(),
      'quiz_score': instance.quizScore,
      'quiz_total': instance.quizTotal,
      'notes': instance.notes,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

_$CreateStudyPlanRequestImpl _$$CreateStudyPlanRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$CreateStudyPlanRequestImpl(
      userId: json['userId'] as String,
      subject: json['subject'] as String,
      topic: json['topic'] as String,
      examDate: json['examDate'] as String,
      difficulty: $enumDecode(_$StudyDifficultyEnumMap, json['difficulty']),
      availableTime: (json['availableTime'] as num).toInt(),
    );

Map<String, dynamic> _$$CreateStudyPlanRequestImplToJson(
        _$CreateStudyPlanRequestImpl instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'subject': instance.subject,
      'topic': instance.topic,
      'examDate': instance.examDate,
      'difficulty': _$StudyDifficultyEnumMap[instance.difficulty]!,
      'availableTime': instance.availableTime,
    };

_$StudyPlanResponseImpl _$$StudyPlanResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$StudyPlanResponseImpl(
      success: json['success'] as bool,
      studyItem: StudyItem.fromJson(json['studyItem'] as Map<String, dynamic>),
      plan: StudyPlan.fromJson(json['plan'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$StudyPlanResponseImplToJson(
        _$StudyPlanResponseImpl instance) =>
    <String, dynamic>{
      'success': instance.success,
      'studyItem': instance.studyItem,
      'plan': instance.plan,
    };
