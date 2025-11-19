// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'study_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

QuizQuestion _$QuizQuestionFromJson(Map<String, dynamic> json) {
  return _QuizQuestion.fromJson(json);
}

/// @nodoc
mixin _$QuizQuestion {
  String get q => throw _privateConstructorUsedError; // Question text
  String? get a =>
      throw _privateConstructorUsedError; // Answer for text questions
  @JsonKey(name: 'type')
  QuizQuestionType get questionType => throw _privateConstructorUsedError;
  List<String>? get options =>
      throw _privateConstructorUsedError; // For multiple choice
  String? get answer => throw _privateConstructorUsedError;

  /// Serializes this QuizQuestion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $QuizQuestionCopyWith<QuizQuestion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $QuizQuestionCopyWith<$Res> {
  factory $QuizQuestionCopyWith(
          QuizQuestion value, $Res Function(QuizQuestion) then) =
      _$QuizQuestionCopyWithImpl<$Res, QuizQuestion>;
  @useResult
  $Res call(
      {String q,
      String? a,
      @JsonKey(name: 'type') QuizQuestionType questionType,
      List<String>? options,
      String? answer});
}

/// @nodoc
class _$QuizQuestionCopyWithImpl<$Res, $Val extends QuizQuestion>
    implements $QuizQuestionCopyWith<$Res> {
  _$QuizQuestionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? q = null,
    Object? a = freezed,
    Object? questionType = null,
    Object? options = freezed,
    Object? answer = freezed,
  }) {
    return _then(_value.copyWith(
      q: null == q
          ? _value.q
          : q // ignore: cast_nullable_to_non_nullable
              as String,
      a: freezed == a
          ? _value.a
          : a // ignore: cast_nullable_to_non_nullable
              as String?,
      questionType: null == questionType
          ? _value.questionType
          : questionType // ignore: cast_nullable_to_non_nullable
              as QuizQuestionType,
      options: freezed == options
          ? _value.options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      answer: freezed == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$QuizQuestionImplCopyWith<$Res>
    implements $QuizQuestionCopyWith<$Res> {
  factory _$$QuizQuestionImplCopyWith(
          _$QuizQuestionImpl value, $Res Function(_$QuizQuestionImpl) then) =
      __$$QuizQuestionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String q,
      String? a,
      @JsonKey(name: 'type') QuizQuestionType questionType,
      List<String>? options,
      String? answer});
}

/// @nodoc
class __$$QuizQuestionImplCopyWithImpl<$Res>
    extends _$QuizQuestionCopyWithImpl<$Res, _$QuizQuestionImpl>
    implements _$$QuizQuestionImplCopyWith<$Res> {
  __$$QuizQuestionImplCopyWithImpl(
      _$QuizQuestionImpl _value, $Res Function(_$QuizQuestionImpl) _then)
      : super(_value, _then);

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? q = null,
    Object? a = freezed,
    Object? questionType = null,
    Object? options = freezed,
    Object? answer = freezed,
  }) {
    return _then(_$QuizQuestionImpl(
      q: null == q
          ? _value.q
          : q // ignore: cast_nullable_to_non_nullable
              as String,
      a: freezed == a
          ? _value.a
          : a // ignore: cast_nullable_to_non_nullable
              as String?,
      questionType: null == questionType
          ? _value.questionType
          : questionType // ignore: cast_nullable_to_non_nullable
              as QuizQuestionType,
      options: freezed == options
          ? _value._options
          : options // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      answer: freezed == answer
          ? _value.answer
          : answer // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$QuizQuestionImpl implements _QuizQuestion {
  const _$QuizQuestionImpl(
      {required this.q,
      this.a,
      @JsonKey(name: 'type') required this.questionType,
      final List<String>? options,
      this.answer})
      : _options = options;

  factory _$QuizQuestionImpl.fromJson(Map<String, dynamic> json) =>
      _$$QuizQuestionImplFromJson(json);

  @override
  final String q;
// Question text
  @override
  final String? a;
// Answer for text questions
  @override
  @JsonKey(name: 'type')
  final QuizQuestionType questionType;
  final List<String>? _options;
  @override
  List<String>? get options {
    final value = _options;
    if (value == null) return null;
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// For multiple choice
  @override
  final String? answer;

  @override
  String toString() {
    return 'QuizQuestion(q: $q, a: $a, questionType: $questionType, options: $options, answer: $answer)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$QuizQuestionImpl &&
            (identical(other.q, q) || other.q == q) &&
            (identical(other.a, a) || other.a == a) &&
            (identical(other.questionType, questionType) ||
                other.questionType == questionType) &&
            const DeepCollectionEquality().equals(other._options, _options) &&
            (identical(other.answer, answer) || other.answer == answer));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, q, a, questionType,
      const DeepCollectionEquality().hash(_options), answer);

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$QuizQuestionImplCopyWith<_$QuizQuestionImpl> get copyWith =>
      __$$QuizQuestionImplCopyWithImpl<_$QuizQuestionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$QuizQuestionImplToJson(
      this,
    );
  }
}

abstract class _QuizQuestion implements QuizQuestion {
  const factory _QuizQuestion(
      {required final String q,
      final String? a,
      @JsonKey(name: 'type') required final QuizQuestionType questionType,
      final List<String>? options,
      final String? answer}) = _$QuizQuestionImpl;

  factory _QuizQuestion.fromJson(Map<String, dynamic> json) =
      _$QuizQuestionImpl.fromJson;

  @override
  String get q; // Question text
  @override
  String? get a; // Answer for text questions
  @override
  @JsonKey(name: 'type')
  QuizQuestionType get questionType;
  @override
  List<String>? get options; // For multiple choice
  @override
  String? get answer;

  /// Create a copy of QuizQuestion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$QuizQuestionImplCopyWith<_$QuizQuestionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StudyQuiz _$StudyQuizFromJson(Map<String, dynamic> json) {
  return _StudyQuiz.fromJson(json);
}

/// @nodoc
mixin _$StudyQuiz {
  int get sessionIndex => throw _privateConstructorUsedError;
  List<QuizQuestion> get questions => throw _privateConstructorUsedError;

  /// Serializes this StudyQuiz to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudyQuiz
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudyQuizCopyWith<StudyQuiz> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudyQuizCopyWith<$Res> {
  factory $StudyQuizCopyWith(StudyQuiz value, $Res Function(StudyQuiz) then) =
      _$StudyQuizCopyWithImpl<$Res, StudyQuiz>;
  @useResult
  $Res call({int sessionIndex, List<QuizQuestion> questions});
}

/// @nodoc
class _$StudyQuizCopyWithImpl<$Res, $Val extends StudyQuiz>
    implements $StudyQuizCopyWith<$Res> {
  _$StudyQuizCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudyQuiz
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionIndex = null,
    Object? questions = null,
  }) {
    return _then(_value.copyWith(
      sessionIndex: null == sessionIndex
          ? _value.sessionIndex
          : sessionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      questions: null == questions
          ? _value.questions
          : questions // ignore: cast_nullable_to_non_nullable
              as List<QuizQuestion>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudyQuizImplCopyWith<$Res>
    implements $StudyQuizCopyWith<$Res> {
  factory _$$StudyQuizImplCopyWith(
          _$StudyQuizImpl value, $Res Function(_$StudyQuizImpl) then) =
      __$$StudyQuizImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int sessionIndex, List<QuizQuestion> questions});
}

/// @nodoc
class __$$StudyQuizImplCopyWithImpl<$Res>
    extends _$StudyQuizCopyWithImpl<$Res, _$StudyQuizImpl>
    implements _$$StudyQuizImplCopyWith<$Res> {
  __$$StudyQuizImplCopyWithImpl(
      _$StudyQuizImpl _value, $Res Function(_$StudyQuizImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudyQuiz
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? sessionIndex = null,
    Object? questions = null,
  }) {
    return _then(_$StudyQuizImpl(
      sessionIndex: null == sessionIndex
          ? _value.sessionIndex
          : sessionIndex // ignore: cast_nullable_to_non_nullable
              as int,
      questions: null == questions
          ? _value._questions
          : questions // ignore: cast_nullable_to_non_nullable
              as List<QuizQuestion>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudyQuizImpl implements _StudyQuiz {
  const _$StudyQuizImpl(
      {required this.sessionIndex, required final List<QuizQuestion> questions})
      : _questions = questions;

  factory _$StudyQuizImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudyQuizImplFromJson(json);

  @override
  final int sessionIndex;
  final List<QuizQuestion> _questions;
  @override
  List<QuizQuestion> get questions {
    if (_questions is EqualUnmodifiableListView) return _questions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_questions);
  }

  @override
  String toString() {
    return 'StudyQuiz(sessionIndex: $sessionIndex, questions: $questions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudyQuizImpl &&
            (identical(other.sessionIndex, sessionIndex) ||
                other.sessionIndex == sessionIndex) &&
            const DeepCollectionEquality()
                .equals(other._questions, _questions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, sessionIndex,
      const DeepCollectionEquality().hash(_questions));

  /// Create a copy of StudyQuiz
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudyQuizImplCopyWith<_$StudyQuizImpl> get copyWith =>
      __$$StudyQuizImplCopyWithImpl<_$StudyQuizImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudyQuizImplToJson(
      this,
    );
  }
}

abstract class _StudyQuiz implements StudyQuiz {
  const factory _StudyQuiz(
      {required final int sessionIndex,
      required final List<QuizQuestion> questions}) = _$StudyQuizImpl;

  factory _StudyQuiz.fromJson(Map<String, dynamic> json) =
      _$StudyQuizImpl.fromJson;

  @override
  int get sessionIndex;
  @override
  List<QuizQuestion> get questions;

  /// Create a copy of StudyQuiz
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudyQuizImplCopyWith<_$StudyQuizImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StudyMilestone _$StudyMilestoneFromJson(Map<String, dynamic> json) {
  return _StudyMilestone.fromJson(json);
}

/// @nodoc
mixin _$StudyMilestone {
  String get date => throw _privateConstructorUsedError;
  String get checkpoint => throw _privateConstructorUsedError;

  /// Serializes this StudyMilestone to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudyMilestone
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudyMilestoneCopyWith<StudyMilestone> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudyMilestoneCopyWith<$Res> {
  factory $StudyMilestoneCopyWith(
          StudyMilestone value, $Res Function(StudyMilestone) then) =
      _$StudyMilestoneCopyWithImpl<$Res, StudyMilestone>;
  @useResult
  $Res call({String date, String checkpoint});
}

/// @nodoc
class _$StudyMilestoneCopyWithImpl<$Res, $Val extends StudyMilestone>
    implements $StudyMilestoneCopyWith<$Res> {
  _$StudyMilestoneCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudyMilestone
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? checkpoint = null,
  }) {
    return _then(_value.copyWith(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      checkpoint: null == checkpoint
          ? _value.checkpoint
          : checkpoint // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudyMilestoneImplCopyWith<$Res>
    implements $StudyMilestoneCopyWith<$Res> {
  factory _$$StudyMilestoneImplCopyWith(_$StudyMilestoneImpl value,
          $Res Function(_$StudyMilestoneImpl) then) =
      __$$StudyMilestoneImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String date, String checkpoint});
}

/// @nodoc
class __$$StudyMilestoneImplCopyWithImpl<$Res>
    extends _$StudyMilestoneCopyWithImpl<$Res, _$StudyMilestoneImpl>
    implements _$$StudyMilestoneImplCopyWith<$Res> {
  __$$StudyMilestoneImplCopyWithImpl(
      _$StudyMilestoneImpl _value, $Res Function(_$StudyMilestoneImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudyMilestone
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? checkpoint = null,
  }) {
    return _then(_$StudyMilestoneImpl(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      checkpoint: null == checkpoint
          ? _value.checkpoint
          : checkpoint // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudyMilestoneImpl implements _StudyMilestone {
  const _$StudyMilestoneImpl({required this.date, required this.checkpoint});

  factory _$StudyMilestoneImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudyMilestoneImplFromJson(json);

  @override
  final String date;
  @override
  final String checkpoint;

  @override
  String toString() {
    return 'StudyMilestone(date: $date, checkpoint: $checkpoint)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudyMilestoneImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.checkpoint, checkpoint) ||
                other.checkpoint == checkpoint));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, checkpoint);

  /// Create a copy of StudyMilestone
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudyMilestoneImplCopyWith<_$StudyMilestoneImpl> get copyWith =>
      __$$StudyMilestoneImplCopyWithImpl<_$StudyMilestoneImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudyMilestoneImplToJson(
      this,
    );
  }
}

abstract class _StudyMilestone implements StudyMilestone {
  const factory _StudyMilestone(
      {required final String date,
      required final String checkpoint}) = _$StudyMilestoneImpl;

  factory _StudyMilestone.fromJson(Map<String, dynamic> json) =
      _$StudyMilestoneImpl.fromJson;

  @override
  String get date;
  @override
  String get checkpoint;

  /// Create a copy of StudyMilestone
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudyMilestoneImplCopyWith<_$StudyMilestoneImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StudySessionPlan _$StudySessionPlanFromJson(Map<String, dynamic> json) {
  return _StudySessionPlan.fromJson(json);
}

/// @nodoc
mixin _$StudySessionPlan {
  String get date => throw _privateConstructorUsedError;
  int get duration => throw _privateConstructorUsedError;
  String get focus => throw _privateConstructorUsedError;
  List<String> get tasks => throw _privateConstructorUsedError;
  String get difficulty => throw _privateConstructorUsedError;

  /// Serializes this StudySessionPlan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudySessionPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudySessionPlanCopyWith<StudySessionPlan> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudySessionPlanCopyWith<$Res> {
  factory $StudySessionPlanCopyWith(
          StudySessionPlan value, $Res Function(StudySessionPlan) then) =
      _$StudySessionPlanCopyWithImpl<$Res, StudySessionPlan>;
  @useResult
  $Res call(
      {String date,
      int duration,
      String focus,
      List<String> tasks,
      String difficulty});
}

/// @nodoc
class _$StudySessionPlanCopyWithImpl<$Res, $Val extends StudySessionPlan>
    implements $StudySessionPlanCopyWith<$Res> {
  _$StudySessionPlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudySessionPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? duration = null,
    Object? focus = null,
    Object? tasks = null,
    Object? difficulty = null,
  }) {
    return _then(_value.copyWith(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      focus: null == focus
          ? _value.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as String,
      tasks: null == tasks
          ? _value.tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<String>,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudySessionPlanImplCopyWith<$Res>
    implements $StudySessionPlanCopyWith<$Res> {
  factory _$$StudySessionPlanImplCopyWith(_$StudySessionPlanImpl value,
          $Res Function(_$StudySessionPlanImpl) then) =
      __$$StudySessionPlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String date,
      int duration,
      String focus,
      List<String> tasks,
      String difficulty});
}

/// @nodoc
class __$$StudySessionPlanImplCopyWithImpl<$Res>
    extends _$StudySessionPlanCopyWithImpl<$Res, _$StudySessionPlanImpl>
    implements _$$StudySessionPlanImplCopyWith<$Res> {
  __$$StudySessionPlanImplCopyWithImpl(_$StudySessionPlanImpl _value,
      $Res Function(_$StudySessionPlanImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudySessionPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? date = null,
    Object? duration = null,
    Object? focus = null,
    Object? tasks = null,
    Object? difficulty = null,
  }) {
    return _then(_$StudySessionPlanImpl(
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      focus: null == focus
          ? _value.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as String,
      tasks: null == tasks
          ? _value._tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<String>,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudySessionPlanImpl implements _StudySessionPlan {
  const _$StudySessionPlanImpl(
      {required this.date,
      required this.duration,
      required this.focus,
      required final List<String> tasks,
      required this.difficulty})
      : _tasks = tasks;

  factory _$StudySessionPlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudySessionPlanImplFromJson(json);

  @override
  final String date;
  @override
  final int duration;
  @override
  final String focus;
  final List<String> _tasks;
  @override
  List<String> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  @override
  final String difficulty;

  @override
  String toString() {
    return 'StudySessionPlan(date: $date, duration: $duration, focus: $focus, tasks: $tasks, difficulty: $difficulty)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudySessionPlanImpl &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.focus, focus) || other.focus == focus) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, date, duration, focus,
      const DeepCollectionEquality().hash(_tasks), difficulty);

  /// Create a copy of StudySessionPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudySessionPlanImplCopyWith<_$StudySessionPlanImpl> get copyWith =>
      __$$StudySessionPlanImplCopyWithImpl<_$StudySessionPlanImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudySessionPlanImplToJson(
      this,
    );
  }
}

abstract class _StudySessionPlan implements StudySessionPlan {
  const factory _StudySessionPlan(
      {required final String date,
      required final int duration,
      required final String focus,
      required final List<String> tasks,
      required final String difficulty}) = _$StudySessionPlanImpl;

  factory _StudySessionPlan.fromJson(Map<String, dynamic> json) =
      _$StudySessionPlanImpl.fromJson;

  @override
  String get date;
  @override
  int get duration;
  @override
  String get focus;
  @override
  List<String> get tasks;
  @override
  String get difficulty;

  /// Create a copy of StudySessionPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudySessionPlanImplCopyWith<_$StudySessionPlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StudyPlan _$StudyPlanFromJson(Map<String, dynamic> json) {
  return _StudyPlan.fromJson(json);
}

/// @nodoc
mixin _$StudyPlan {
  List<StudySessionPlan> get plan => throw _privateConstructorUsedError;
  List<StudyMilestone> get milestones => throw _privateConstructorUsedError;
  List<StudyQuiz> get quizzes => throw _privateConstructorUsedError;
  double get totalEstimatedHours => throw _privateConstructorUsedError;
  double get confidenceScore => throw _privateConstructorUsedError;

  /// Serializes this StudyPlan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudyPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudyPlanCopyWith<StudyPlan> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudyPlanCopyWith<$Res> {
  factory $StudyPlanCopyWith(StudyPlan value, $Res Function(StudyPlan) then) =
      _$StudyPlanCopyWithImpl<$Res, StudyPlan>;
  @useResult
  $Res call(
      {List<StudySessionPlan> plan,
      List<StudyMilestone> milestones,
      List<StudyQuiz> quizzes,
      double totalEstimatedHours,
      double confidenceScore});
}

/// @nodoc
class _$StudyPlanCopyWithImpl<$Res, $Val extends StudyPlan>
    implements $StudyPlanCopyWith<$Res> {
  _$StudyPlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudyPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plan = null,
    Object? milestones = null,
    Object? quizzes = null,
    Object? totalEstimatedHours = null,
    Object? confidenceScore = null,
  }) {
    return _then(_value.copyWith(
      plan: null == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as List<StudySessionPlan>,
      milestones: null == milestones
          ? _value.milestones
          : milestones // ignore: cast_nullable_to_non_nullable
              as List<StudyMilestone>,
      quizzes: null == quizzes
          ? _value.quizzes
          : quizzes // ignore: cast_nullable_to_non_nullable
              as List<StudyQuiz>,
      totalEstimatedHours: null == totalEstimatedHours
          ? _value.totalEstimatedHours
          : totalEstimatedHours // ignore: cast_nullable_to_non_nullable
              as double,
      confidenceScore: null == confidenceScore
          ? _value.confidenceScore
          : confidenceScore // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudyPlanImplCopyWith<$Res>
    implements $StudyPlanCopyWith<$Res> {
  factory _$$StudyPlanImplCopyWith(
          _$StudyPlanImpl value, $Res Function(_$StudyPlanImpl) then) =
      __$$StudyPlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<StudySessionPlan> plan,
      List<StudyMilestone> milestones,
      List<StudyQuiz> quizzes,
      double totalEstimatedHours,
      double confidenceScore});
}

/// @nodoc
class __$$StudyPlanImplCopyWithImpl<$Res>
    extends _$StudyPlanCopyWithImpl<$Res, _$StudyPlanImpl>
    implements _$$StudyPlanImplCopyWith<$Res> {
  __$$StudyPlanImplCopyWithImpl(
      _$StudyPlanImpl _value, $Res Function(_$StudyPlanImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudyPlan
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plan = null,
    Object? milestones = null,
    Object? quizzes = null,
    Object? totalEstimatedHours = null,
    Object? confidenceScore = null,
  }) {
    return _then(_$StudyPlanImpl(
      plan: null == plan
          ? _value._plan
          : plan // ignore: cast_nullable_to_non_nullable
              as List<StudySessionPlan>,
      milestones: null == milestones
          ? _value._milestones
          : milestones // ignore: cast_nullable_to_non_nullable
              as List<StudyMilestone>,
      quizzes: null == quizzes
          ? _value._quizzes
          : quizzes // ignore: cast_nullable_to_non_nullable
              as List<StudyQuiz>,
      totalEstimatedHours: null == totalEstimatedHours
          ? _value.totalEstimatedHours
          : totalEstimatedHours // ignore: cast_nullable_to_non_nullable
              as double,
      confidenceScore: null == confidenceScore
          ? _value.confidenceScore
          : confidenceScore // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudyPlanImpl implements _StudyPlan {
  const _$StudyPlanImpl(
      {required final List<StudySessionPlan> plan,
      required final List<StudyMilestone> milestones,
      required final List<StudyQuiz> quizzes,
      required this.totalEstimatedHours,
      required this.confidenceScore})
      : _plan = plan,
        _milestones = milestones,
        _quizzes = quizzes;

  factory _$StudyPlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudyPlanImplFromJson(json);

  final List<StudySessionPlan> _plan;
  @override
  List<StudySessionPlan> get plan {
    if (_plan is EqualUnmodifiableListView) return _plan;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_plan);
  }

  final List<StudyMilestone> _milestones;
  @override
  List<StudyMilestone> get milestones {
    if (_milestones is EqualUnmodifiableListView) return _milestones;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_milestones);
  }

  final List<StudyQuiz> _quizzes;
  @override
  List<StudyQuiz> get quizzes {
    if (_quizzes is EqualUnmodifiableListView) return _quizzes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_quizzes);
  }

  @override
  final double totalEstimatedHours;
  @override
  final double confidenceScore;

  @override
  String toString() {
    return 'StudyPlan(plan: $plan, milestones: $milestones, quizzes: $quizzes, totalEstimatedHours: $totalEstimatedHours, confidenceScore: $confidenceScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudyPlanImpl &&
            const DeepCollectionEquality().equals(other._plan, _plan) &&
            const DeepCollectionEquality()
                .equals(other._milestones, _milestones) &&
            const DeepCollectionEquality().equals(other._quizzes, _quizzes) &&
            (identical(other.totalEstimatedHours, totalEstimatedHours) ||
                other.totalEstimatedHours == totalEstimatedHours) &&
            (identical(other.confidenceScore, confidenceScore) ||
                other.confidenceScore == confidenceScore));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_plan),
      const DeepCollectionEquality().hash(_milestones),
      const DeepCollectionEquality().hash(_quizzes),
      totalEstimatedHours,
      confidenceScore);

  /// Create a copy of StudyPlan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudyPlanImplCopyWith<_$StudyPlanImpl> get copyWith =>
      __$$StudyPlanImplCopyWithImpl<_$StudyPlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudyPlanImplToJson(
      this,
    );
  }
}

abstract class _StudyPlan implements StudyPlan {
  const factory _StudyPlan(
      {required final List<StudySessionPlan> plan,
      required final List<StudyMilestone> milestones,
      required final List<StudyQuiz> quizzes,
      required final double totalEstimatedHours,
      required final double confidenceScore}) = _$StudyPlanImpl;

  factory _StudyPlan.fromJson(Map<String, dynamic> json) =
      _$StudyPlanImpl.fromJson;

  @override
  List<StudySessionPlan> get plan;
  @override
  List<StudyMilestone> get milestones;
  @override
  List<StudyQuiz> get quizzes;
  @override
  double get totalEstimatedHours;
  @override
  double get confidenceScore;

  /// Create a copy of StudyPlan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudyPlanImplCopyWith<_$StudyPlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StudyItem _$StudyItemFromJson(Map<String, dynamic> json) {
  return _StudyItem.fromJson(json);
}

/// @nodoc
mixin _$StudyItem {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;
  @JsonKey(name: 'test_date')
  DateTime get testDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'study_plan')
  StudyPlan get studyPlan => throw _privateConstructorUsedError;
  StudyStatus get status => throw _privateConstructorUsedError;
  StudyDifficulty get difficulty => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this StudyItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudyItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudyItemCopyWith<StudyItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudyItemCopyWith<$Res> {
  factory $StudyItemCopyWith(StudyItem value, $Res Function(StudyItem) then) =
      _$StudyItemCopyWithImpl<$Res, StudyItem>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      String subject,
      String topic,
      @JsonKey(name: 'test_date') DateTime testDate,
      @JsonKey(name: 'study_plan') StudyPlan studyPlan,
      StudyStatus status,
      StudyDifficulty difficulty,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt});

  $StudyPlanCopyWith<$Res> get studyPlan;
}

/// @nodoc
class _$StudyItemCopyWithImpl<$Res, $Val extends StudyItem>
    implements $StudyItemCopyWith<$Res> {
  _$StudyItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudyItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? subject = null,
    Object? topic = null,
    Object? testDate = null,
    Object? studyPlan = null,
    Object? status = null,
    Object? difficulty = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      testDate: null == testDate
          ? _value.testDate
          : testDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      studyPlan: null == studyPlan
          ? _value.studyPlan
          : studyPlan // ignore: cast_nullable_to_non_nullable
              as StudyPlan,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as StudyStatus,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as StudyDifficulty,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  /// Create a copy of StudyItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StudyPlanCopyWith<$Res> get studyPlan {
    return $StudyPlanCopyWith<$Res>(_value.studyPlan, (value) {
      return _then(_value.copyWith(studyPlan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$StudyItemImplCopyWith<$Res>
    implements $StudyItemCopyWith<$Res> {
  factory _$$StudyItemImplCopyWith(
          _$StudyItemImpl value, $Res Function(_$StudyItemImpl) then) =
      __$$StudyItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'user_id') String userId,
      String subject,
      String topic,
      @JsonKey(name: 'test_date') DateTime testDate,
      @JsonKey(name: 'study_plan') StudyPlan studyPlan,
      StudyStatus status,
      StudyDifficulty difficulty,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt});

  @override
  $StudyPlanCopyWith<$Res> get studyPlan;
}

/// @nodoc
class __$$StudyItemImplCopyWithImpl<$Res>
    extends _$StudyItemCopyWithImpl<$Res, _$StudyItemImpl>
    implements _$$StudyItemImplCopyWith<$Res> {
  __$$StudyItemImplCopyWithImpl(
      _$StudyItemImpl _value, $Res Function(_$StudyItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudyItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? subject = null,
    Object? topic = null,
    Object? testDate = null,
    Object? studyPlan = null,
    Object? status = null,
    Object? difficulty = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$StudyItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      testDate: null == testDate
          ? _value.testDate
          : testDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      studyPlan: null == studyPlan
          ? _value.studyPlan
          : studyPlan // ignore: cast_nullable_to_non_nullable
              as StudyPlan,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as StudyStatus,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as StudyDifficulty,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudyItemImpl implements _StudyItem {
  const _$StudyItemImpl(
      {required this.id,
      @JsonKey(name: 'user_id') required this.userId,
      required this.subject,
      required this.topic,
      @JsonKey(name: 'test_date') required this.testDate,
      @JsonKey(name: 'study_plan') required this.studyPlan,
      required this.status,
      required this.difficulty,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt});

  factory _$StudyItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudyItemImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final String subject;
  @override
  final String topic;
  @override
  @JsonKey(name: 'test_date')
  final DateTime testDate;
  @override
  @JsonKey(name: 'study_plan')
  final StudyPlan studyPlan;
  @override
  final StudyStatus status;
  @override
  final StudyDifficulty difficulty;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'StudyItem(id: $id, userId: $userId, subject: $subject, topic: $topic, testDate: $testDate, studyPlan: $studyPlan, status: $status, difficulty: $difficulty, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudyItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.testDate, testDate) ||
                other.testDate == testDate) &&
            (identical(other.studyPlan, studyPlan) ||
                other.studyPlan == studyPlan) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, userId, subject, topic,
      testDate, studyPlan, status, difficulty, createdAt, updatedAt);

  /// Create a copy of StudyItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudyItemImplCopyWith<_$StudyItemImpl> get copyWith =>
      __$$StudyItemImplCopyWithImpl<_$StudyItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudyItemImplToJson(
      this,
    );
  }
}

abstract class _StudyItem implements StudyItem {
  const factory _StudyItem(
          {required final String id,
          @JsonKey(name: 'user_id') required final String userId,
          required final String subject,
          required final String topic,
          @JsonKey(name: 'test_date') required final DateTime testDate,
          @JsonKey(name: 'study_plan') required final StudyPlan studyPlan,
          required final StudyStatus status,
          required final StudyDifficulty difficulty,
          @JsonKey(name: 'created_at') required final DateTime createdAt,
          @JsonKey(name: 'updated_at') required final DateTime updatedAt}) =
      _$StudyItemImpl;

  factory _StudyItem.fromJson(Map<String, dynamic> json) =
      _$StudyItemImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String get subject;
  @override
  String get topic;
  @override
  @JsonKey(name: 'test_date')
  DateTime get testDate;
  @override
  @JsonKey(name: 'study_plan')
  StudyPlan get studyPlan;
  @override
  StudyStatus get status;
  @override
  StudyDifficulty get difficulty;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of StudyItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudyItemImplCopyWith<_$StudyItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

StudySession _$StudySessionFromJson(Map<String, dynamic> json) {
  return _StudySession.fromJson(json);
}

/// @nodoc
mixin _$StudySession {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'study_item_id')
  String get studyItemId => throw _privateConstructorUsedError;
  @JsonKey(name: 'scheduled_at')
  DateTime get scheduledAt => throw _privateConstructorUsedError;
  int get duration => throw _privateConstructorUsedError;
  String get focus => throw _privateConstructorUsedError;
  List<String> get tasks => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'quiz_score')
  int? get quizScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'quiz_total')
  int? get quizTotal => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this StudySession to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudySession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudySessionCopyWith<StudySession> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudySessionCopyWith<$Res> {
  factory $StudySessionCopyWith(
          StudySession value, $Res Function(StudySession) then) =
      _$StudySessionCopyWithImpl<$Res, StudySession>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'study_item_id') String studyItemId,
      @JsonKey(name: 'scheduled_at') DateTime scheduledAt,
      int duration,
      String focus,
      List<String> tasks,
      bool completed,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      @JsonKey(name: 'quiz_score') int? quizScore,
      @JsonKey(name: 'quiz_total') int? quizTotal,
      String? notes,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt});
}

/// @nodoc
class _$StudySessionCopyWithImpl<$Res, $Val extends StudySession>
    implements $StudySessionCopyWith<$Res> {
  _$StudySessionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudySession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studyItemId = null,
    Object? scheduledAt = null,
    Object? duration = null,
    Object? focus = null,
    Object? tasks = null,
    Object? completed = null,
    Object? completedAt = freezed,
    Object? quizScore = freezed,
    Object? quizTotal = freezed,
    Object? notes = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      studyItemId: null == studyItemId
          ? _value.studyItemId
          : studyItemId // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledAt: null == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      focus: null == focus
          ? _value.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as String,
      tasks: null == tasks
          ? _value.tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<String>,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      quizScore: freezed == quizScore
          ? _value.quizScore
          : quizScore // ignore: cast_nullable_to_non_nullable
              as int?,
      quizTotal: freezed == quizTotal
          ? _value.quizTotal
          : quizTotal // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudySessionImplCopyWith<$Res>
    implements $StudySessionCopyWith<$Res> {
  factory _$$StudySessionImplCopyWith(
          _$StudySessionImpl value, $Res Function(_$StudySessionImpl) then) =
      __$$StudySessionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'study_item_id') String studyItemId,
      @JsonKey(name: 'scheduled_at') DateTime scheduledAt,
      int duration,
      String focus,
      List<String> tasks,
      bool completed,
      @JsonKey(name: 'completed_at') DateTime? completedAt,
      @JsonKey(name: 'quiz_score') int? quizScore,
      @JsonKey(name: 'quiz_total') int? quizTotal,
      String? notes,
      @JsonKey(name: 'created_at') DateTime createdAt,
      @JsonKey(name: 'updated_at') DateTime updatedAt});
}

/// @nodoc
class __$$StudySessionImplCopyWithImpl<$Res>
    extends _$StudySessionCopyWithImpl<$Res, _$StudySessionImpl>
    implements _$$StudySessionImplCopyWith<$Res> {
  __$$StudySessionImplCopyWithImpl(
      _$StudySessionImpl _value, $Res Function(_$StudySessionImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudySession
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studyItemId = null,
    Object? scheduledAt = null,
    Object? duration = null,
    Object? focus = null,
    Object? tasks = null,
    Object? completed = null,
    Object? completedAt = freezed,
    Object? quizScore = freezed,
    Object? quizTotal = freezed,
    Object? notes = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$StudySessionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      studyItemId: null == studyItemId
          ? _value.studyItemId
          : studyItemId // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledAt: null == scheduledAt
          ? _value.scheduledAt
          : scheduledAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      focus: null == focus
          ? _value.focus
          : focus // ignore: cast_nullable_to_non_nullable
              as String,
      tasks: null == tasks
          ? _value._tasks
          : tasks // ignore: cast_nullable_to_non_nullable
              as List<String>,
      completed: null == completed
          ? _value.completed
          : completed // ignore: cast_nullable_to_non_nullable
              as bool,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      quizScore: freezed == quizScore
          ? _value.quizScore
          : quizScore // ignore: cast_nullable_to_non_nullable
              as int?,
      quizTotal: freezed == quizTotal
          ? _value.quizTotal
          : quizTotal // ignore: cast_nullable_to_non_nullable
              as int?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudySessionImpl implements _StudySession {
  const _$StudySessionImpl(
      {required this.id,
      @JsonKey(name: 'study_item_id') required this.studyItemId,
      @JsonKey(name: 'scheduled_at') required this.scheduledAt,
      required this.duration,
      required this.focus,
      required final List<String> tasks,
      required this.completed,
      @JsonKey(name: 'completed_at') this.completedAt,
      @JsonKey(name: 'quiz_score') this.quizScore,
      @JsonKey(name: 'quiz_total') this.quizTotal,
      this.notes,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'updated_at') required this.updatedAt})
      : _tasks = tasks;

  factory _$StudySessionImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudySessionImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'study_item_id')
  final String studyItemId;
  @override
  @JsonKey(name: 'scheduled_at')
  final DateTime scheduledAt;
  @override
  final int duration;
  @override
  final String focus;
  final List<String> _tasks;
  @override
  List<String> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  @override
  final bool completed;
  @override
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @override
  @JsonKey(name: 'quiz_score')
  final int? quizScore;
  @override
  @JsonKey(name: 'quiz_total')
  final int? quizTotal;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'StudySession(id: $id, studyItemId: $studyItemId, scheduledAt: $scheduledAt, duration: $duration, focus: $focus, tasks: $tasks, completed: $completed, completedAt: $completedAt, quizScore: $quizScore, quizTotal: $quizTotal, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudySessionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.studyItemId, studyItemId) ||
                other.studyItemId == studyItemId) &&
            (identical(other.scheduledAt, scheduledAt) ||
                other.scheduledAt == scheduledAt) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.focus, focus) || other.focus == focus) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.quizScore, quizScore) ||
                other.quizScore == quizScore) &&
            (identical(other.quizTotal, quizTotal) ||
                other.quizTotal == quizTotal) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      studyItemId,
      scheduledAt,
      duration,
      focus,
      const DeepCollectionEquality().hash(_tasks),
      completed,
      completedAt,
      quizScore,
      quizTotal,
      notes,
      createdAt,
      updatedAt);

  /// Create a copy of StudySession
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudySessionImplCopyWith<_$StudySessionImpl> get copyWith =>
      __$$StudySessionImplCopyWithImpl<_$StudySessionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudySessionImplToJson(
      this,
    );
  }
}

abstract class _StudySession implements StudySession {
  const factory _StudySession(
          {required final String id,
          @JsonKey(name: 'study_item_id') required final String studyItemId,
          @JsonKey(name: 'scheduled_at') required final DateTime scheduledAt,
          required final int duration,
          required final String focus,
          required final List<String> tasks,
          required final bool completed,
          @JsonKey(name: 'completed_at') final DateTime? completedAt,
          @JsonKey(name: 'quiz_score') final int? quizScore,
          @JsonKey(name: 'quiz_total') final int? quizTotal,
          final String? notes,
          @JsonKey(name: 'created_at') required final DateTime createdAt,
          @JsonKey(name: 'updated_at') required final DateTime updatedAt}) =
      _$StudySessionImpl;

  factory _StudySession.fromJson(Map<String, dynamic> json) =
      _$StudySessionImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'study_item_id')
  String get studyItemId;
  @override
  @JsonKey(name: 'scheduled_at')
  DateTime get scheduledAt;
  @override
  int get duration;
  @override
  String get focus;
  @override
  List<String> get tasks;
  @override
  bool get completed;
  @override
  @JsonKey(name: 'completed_at')
  DateTime? get completedAt;
  @override
  @JsonKey(name: 'quiz_score')
  int? get quizScore;
  @override
  @JsonKey(name: 'quiz_total')
  int? get quizTotal;
  @override
  String? get notes;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of StudySession
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudySessionImplCopyWith<_$StudySessionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CreateStudyPlanRequest _$CreateStudyPlanRequestFromJson(
    Map<String, dynamic> json) {
  return _CreateStudyPlanRequest.fromJson(json);
}

/// @nodoc
mixin _$CreateStudyPlanRequest {
  String get userId => throw _privateConstructorUsedError;
  String get subject => throw _privateConstructorUsedError;
  String get topic => throw _privateConstructorUsedError;
  String get examDate => throw _privateConstructorUsedError;
  StudyDifficulty get difficulty => throw _privateConstructorUsedError;
  int get availableTime => throw _privateConstructorUsedError;

  /// Serializes this CreateStudyPlanRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CreateStudyPlanRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CreateStudyPlanRequestCopyWith<CreateStudyPlanRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateStudyPlanRequestCopyWith<$Res> {
  factory $CreateStudyPlanRequestCopyWith(CreateStudyPlanRequest value,
          $Res Function(CreateStudyPlanRequest) then) =
      _$CreateStudyPlanRequestCopyWithImpl<$Res, CreateStudyPlanRequest>;
  @useResult
  $Res call(
      {String userId,
      String subject,
      String topic,
      String examDate,
      StudyDifficulty difficulty,
      int availableTime});
}

/// @nodoc
class _$CreateStudyPlanRequestCopyWithImpl<$Res,
        $Val extends CreateStudyPlanRequest>
    implements $CreateStudyPlanRequestCopyWith<$Res> {
  _$CreateStudyPlanRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CreateStudyPlanRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? subject = null,
    Object? topic = null,
    Object? examDate = null,
    Object? difficulty = null,
    Object? availableTime = null,
  }) {
    return _then(_value.copyWith(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      examDate: null == examDate
          ? _value.examDate
          : examDate // ignore: cast_nullable_to_non_nullable
              as String,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as StudyDifficulty,
      availableTime: null == availableTime
          ? _value.availableTime
          : availableTime // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateStudyPlanRequestImplCopyWith<$Res>
    implements $CreateStudyPlanRequestCopyWith<$Res> {
  factory _$$CreateStudyPlanRequestImplCopyWith(
          _$CreateStudyPlanRequestImpl value,
          $Res Function(_$CreateStudyPlanRequestImpl) then) =
      __$$CreateStudyPlanRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String userId,
      String subject,
      String topic,
      String examDate,
      StudyDifficulty difficulty,
      int availableTime});
}

/// @nodoc
class __$$CreateStudyPlanRequestImplCopyWithImpl<$Res>
    extends _$CreateStudyPlanRequestCopyWithImpl<$Res,
        _$CreateStudyPlanRequestImpl>
    implements _$$CreateStudyPlanRequestImplCopyWith<$Res> {
  __$$CreateStudyPlanRequestImplCopyWithImpl(
      _$CreateStudyPlanRequestImpl _value,
      $Res Function(_$CreateStudyPlanRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of CreateStudyPlanRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? subject = null,
    Object? topic = null,
    Object? examDate = null,
    Object? difficulty = null,
    Object? availableTime = null,
  }) {
    return _then(_$CreateStudyPlanRequestImpl(
      userId: null == userId
          ? _value.userId
          : userId // ignore: cast_nullable_to_non_nullable
              as String,
      subject: null == subject
          ? _value.subject
          : subject // ignore: cast_nullable_to_non_nullable
              as String,
      topic: null == topic
          ? _value.topic
          : topic // ignore: cast_nullable_to_non_nullable
              as String,
      examDate: null == examDate
          ? _value.examDate
          : examDate // ignore: cast_nullable_to_non_nullable
              as String,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as StudyDifficulty,
      availableTime: null == availableTime
          ? _value.availableTime
          : availableTime // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CreateStudyPlanRequestImpl implements _CreateStudyPlanRequest {
  const _$CreateStudyPlanRequestImpl(
      {required this.userId,
      required this.subject,
      required this.topic,
      required this.examDate,
      required this.difficulty,
      required this.availableTime});

  factory _$CreateStudyPlanRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$CreateStudyPlanRequestImplFromJson(json);

  @override
  final String userId;
  @override
  final String subject;
  @override
  final String topic;
  @override
  final String examDate;
  @override
  final StudyDifficulty difficulty;
  @override
  final int availableTime;

  @override
  String toString() {
    return 'CreateStudyPlanRequest(userId: $userId, subject: $subject, topic: $topic, examDate: $examDate, difficulty: $difficulty, availableTime: $availableTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateStudyPlanRequestImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.subject, subject) || other.subject == subject) &&
            (identical(other.topic, topic) || other.topic == topic) &&
            (identical(other.examDate, examDate) ||
                other.examDate == examDate) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.availableTime, availableTime) ||
                other.availableTime == availableTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, userId, subject, topic, examDate, difficulty, availableTime);

  /// Create a copy of CreateStudyPlanRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateStudyPlanRequestImplCopyWith<_$CreateStudyPlanRequestImpl>
      get copyWith => __$$CreateStudyPlanRequestImplCopyWithImpl<
          _$CreateStudyPlanRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CreateStudyPlanRequestImplToJson(
      this,
    );
  }
}

abstract class _CreateStudyPlanRequest implements CreateStudyPlanRequest {
  const factory _CreateStudyPlanRequest(
      {required final String userId,
      required final String subject,
      required final String topic,
      required final String examDate,
      required final StudyDifficulty difficulty,
      required final int availableTime}) = _$CreateStudyPlanRequestImpl;

  factory _CreateStudyPlanRequest.fromJson(Map<String, dynamic> json) =
      _$CreateStudyPlanRequestImpl.fromJson;

  @override
  String get userId;
  @override
  String get subject;
  @override
  String get topic;
  @override
  String get examDate;
  @override
  StudyDifficulty get difficulty;
  @override
  int get availableTime;

  /// Create a copy of CreateStudyPlanRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CreateStudyPlanRequestImplCopyWith<_$CreateStudyPlanRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}

StudyPlanResponse _$StudyPlanResponseFromJson(Map<String, dynamic> json) {
  return _StudyPlanResponse.fromJson(json);
}

/// @nodoc
mixin _$StudyPlanResponse {
  bool get success => throw _privateConstructorUsedError;
  StudyItem get studyItem => throw _privateConstructorUsedError;
  StudyPlan get plan => throw _privateConstructorUsedError;

  /// Serializes this StudyPlanResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StudyPlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudyPlanResponseCopyWith<StudyPlanResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudyPlanResponseCopyWith<$Res> {
  factory $StudyPlanResponseCopyWith(
          StudyPlanResponse value, $Res Function(StudyPlanResponse) then) =
      _$StudyPlanResponseCopyWithImpl<$Res, StudyPlanResponse>;
  @useResult
  $Res call({bool success, StudyItem studyItem, StudyPlan plan});

  $StudyItemCopyWith<$Res> get studyItem;
  $StudyPlanCopyWith<$Res> get plan;
}

/// @nodoc
class _$StudyPlanResponseCopyWithImpl<$Res, $Val extends StudyPlanResponse>
    implements $StudyPlanResponseCopyWith<$Res> {
  _$StudyPlanResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StudyPlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? studyItem = null,
    Object? plan = null,
  }) {
    return _then(_value.copyWith(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      studyItem: null == studyItem
          ? _value.studyItem
          : studyItem // ignore: cast_nullable_to_non_nullable
              as StudyItem,
      plan: null == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as StudyPlan,
    ) as $Val);
  }

  /// Create a copy of StudyPlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StudyItemCopyWith<$Res> get studyItem {
    return $StudyItemCopyWith<$Res>(_value.studyItem, (value) {
      return _then(_value.copyWith(studyItem: value) as $Val);
    });
  }

  /// Create a copy of StudyPlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StudyPlanCopyWith<$Res> get plan {
    return $StudyPlanCopyWith<$Res>(_value.plan, (value) {
      return _then(_value.copyWith(plan: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$StudyPlanResponseImplCopyWith<$Res>
    implements $StudyPlanResponseCopyWith<$Res> {
  factory _$$StudyPlanResponseImplCopyWith(_$StudyPlanResponseImpl value,
          $Res Function(_$StudyPlanResponseImpl) then) =
      __$$StudyPlanResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool success, StudyItem studyItem, StudyPlan plan});

  @override
  $StudyItemCopyWith<$Res> get studyItem;
  @override
  $StudyPlanCopyWith<$Res> get plan;
}

/// @nodoc
class __$$StudyPlanResponseImplCopyWithImpl<$Res>
    extends _$StudyPlanResponseCopyWithImpl<$Res, _$StudyPlanResponseImpl>
    implements _$$StudyPlanResponseImplCopyWith<$Res> {
  __$$StudyPlanResponseImplCopyWithImpl(_$StudyPlanResponseImpl _value,
      $Res Function(_$StudyPlanResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of StudyPlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? studyItem = null,
    Object? plan = null,
  }) {
    return _then(_$StudyPlanResponseImpl(
      success: null == success
          ? _value.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      studyItem: null == studyItem
          ? _value.studyItem
          : studyItem // ignore: cast_nullable_to_non_nullable
              as StudyItem,
      plan: null == plan
          ? _value.plan
          : plan // ignore: cast_nullable_to_non_nullable
              as StudyPlan,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudyPlanResponseImpl implements _StudyPlanResponse {
  const _$StudyPlanResponseImpl(
      {required this.success, required this.studyItem, required this.plan});

  factory _$StudyPlanResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudyPlanResponseImplFromJson(json);

  @override
  final bool success;
  @override
  final StudyItem studyItem;
  @override
  final StudyPlan plan;

  @override
  String toString() {
    return 'StudyPlanResponse(success: $success, studyItem: $studyItem, plan: $plan)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudyPlanResponseImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.studyItem, studyItem) ||
                other.studyItem == studyItem) &&
            (identical(other.plan, plan) || other.plan == plan));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, success, studyItem, plan);

  /// Create a copy of StudyPlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudyPlanResponseImplCopyWith<_$StudyPlanResponseImpl> get copyWith =>
      __$$StudyPlanResponseImplCopyWithImpl<_$StudyPlanResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudyPlanResponseImplToJson(
      this,
    );
  }
}

abstract class _StudyPlanResponse implements StudyPlanResponse {
  const factory _StudyPlanResponse(
      {required final bool success,
      required final StudyItem studyItem,
      required final StudyPlan plan}) = _$StudyPlanResponseImpl;

  factory _StudyPlanResponse.fromJson(Map<String, dynamic> json) =
      _$StudyPlanResponseImpl.fromJson;

  @override
  bool get success;
  @override
  StudyItem get studyItem;
  @override
  StudyPlan get plan;

  /// Create a copy of StudyPlanResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudyPlanResponseImplCopyWith<_$StudyPlanResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
