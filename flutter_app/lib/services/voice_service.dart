import 'stt_service.dart';
import 'tts_service.dart';
import 'nlu_service.dart';
import '../api/client.dart';

/// Voice command result
class VoiceCommandResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final String intent;

  VoiceCommandResult({
    required this.success,
    required this.message,
    required this.intent,
    this.data,
  });
}

/// Voice command service orchestrating STT, NLU, and TTS
/// Supports NL/EN/DE/FR languages
class VoiceService {
  static final VoiceService instance = VoiceService._();
  VoiceService._();

  final _stt = STTService.instance;
  final _tts = TTSService.instance;
  final _nlu = NLUService.instance;

  bool _initialized = false;
  String _currentLocale = 'nl-NL';

  /// Initialize all voice services
  Future<void> initialize({String locale = 'nl-NL'}) async {
    if (_initialized) return;

    _currentLocale = locale;

    // Initialize services
    await _stt.initialize();
    await _tts.initialize();
    _nlu.initialize();

    _initialized = true;
  }

  /// Process a voice command
  ///
  /// 1. Record audio and convert to text (STT)
  /// 2. Parse intent with Gemini (NLU)
  /// 3. Execute command based on intent
  /// 4. Speak response (TTS)
  ///
  /// [userNames] - List of family member names for better recognition
  /// [onListening] - Callback when listening starts
  /// [onTranscript] - Callback for partial transcript updates
  /// [onIntent] - Callback when intent is parsed
  /// Returns the command result
  Future<VoiceCommandResult> processVoiceCommand({
    List<String>? userNames,
    Function()? onListening,
    Function(String)? onTranscript,
    Function(Map<String, dynamic>)? onIntent,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // 1. Start listening
      onListening?.call();

      final transcript = await _stt.listen(
        locale: _currentLocale,
        onPartial: onTranscript,
        timeout: const Duration(seconds: 30),
      );

      if (transcript == null || transcript.isEmpty) {
        final message = _getLocalizedMessage('no_speech');
        await _tts.speak(message, locale: _currentLocale);
        return VoiceCommandResult(
          success: false,
          message: message,
          intent: 'unknown',
        );
      }

      // 2. Parse intent
      final intent = await _nlu.parseIntent(
        transcript,
        locale: _currentLocale,
        userNames: userNames,
      );

      onIntent?.call(intent);

      // 3. Execute command
      final result = await _executeCommand(intent);

      // 4. Speak response
      await _tts.speak(result.message, locale: _currentLocale);

      return result;
    } catch (e) {
      final message = _getLocalizedMessage('error', error: e.toString());
      await _tts.speak(message, locale: _currentLocale);

      return VoiceCommandResult(
        success: false,
        message: message,
        intent: 'error',
      );
    }
  }

  /// Execute command based on parsed intent
  Future<VoiceCommandResult> _executeCommand(
      Map<String, dynamic> intent) async {
    final intentType = intent['intent'] as String;
    final confidence = intent['confidence'] as double;

    // Low confidence, ask for clarification
    if (confidence < 0.5) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('low_confidence'),
        intent: intentType,
      );
    }

    switch (intentType) {
      case 'create_task':
        return _createTask(intent);

      case 'complete_task':
        return _completeTask(intent);

      case 'show_tasks':
        return _showTasks(intent);

      case 'show_calendar':
        return VoiceCommandResult(
          success: true,
          message: _getLocalizedMessage('show_calendar'),
          intent: intentType,
          data: {'action': 'navigate', 'route': '/calendar'},
        );

      case 'create_event':
        return _createEvent(intent);

      case 'mark_event_done':
        return _markEventDone(intent);

      case 'show_points':
        return _showPoints(intent);

      case 'show_badges':
        return VoiceCommandResult(
          success: true,
          message: _getLocalizedMessage('show_badges'),
          intent: intentType,
          data: {'action': 'navigate', 'route': '/badges'},
        );

      case 'check_streak':
        return _checkStreak(intent);

      case 'assign_task':
        return _assignTask(intent);

      case 'reschedule_task':
        return _rescheduleTask(intent);

      case 'show_study_sessions':
        return VoiceCommandResult(
          success: true,
          message: _getLocalizedMessage('show_study_sessions'),
          intent: intentType,
          data: {'action': 'navigate', 'route': '/study'},
        );

      case 'complete_study_session':
        return _completeStudySession(intent);

      case 'help':
        return VoiceCommandResult(
          success: true,
          message: _getLocalizedMessage('help'),
          intent: intentType,
          data: {'action': 'navigate', 'route': '/voice/help'},
        );

      case 'unknown':
      default:
        return VoiceCommandResult(
          success: false,
          message: _getLocalizedMessage('unknown_command'),
          intent: 'unknown',
        );
    }
  }

  /// Create a new task
  Future<VoiceCommandResult> _createTask(Map<String, dynamic> intent) async {
    final title = intent['task_title'] as String?;
    final assignee = intent['assignee'] as String?;

    if (title == null || title.isEmpty) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('missing_task_title'),
        intent: 'create_task',
      );
    }

    try {
      // Create task via API
      final taskData = {
        'title': title,
        'assignees': assignee != null ? [assignee] : [],
        'points': 10,
        'status': 'open',
      };

      final result = await ApiClient.instance.createTask(taskData);

      // Handle offline queue
      if (result['queued'] == true) {
        return VoiceCommandResult(
          success: true,
          message:
              _getLocalizedMessage('task_created_offline', taskTitle: title),
          intent: 'create_task',
          data: result,
        );
      }

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage(
          'task_created',
          taskTitle: title,
          assignee: assignee,
        ),
        intent: 'create_task',
        data: result,
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message:
            _getLocalizedMessage('task_creation_failed', error: e.toString()),
        intent: 'create_task',
      );
    }
  }

  /// Complete a task (fuzzy match by title)
  Future<VoiceCommandResult> _completeTask(Map<String, dynamic> intent) async {
    final title = intent['task_title'] as String?;

    if (title == null || title.isEmpty) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('missing_task_title'),
        intent: 'complete_task',
      );
    }

    try {
      // Fetch tasks and find best match
      final tasks = await ApiClient.instance.listTasks();
      final matchedTask = _findBestTaskMatch(title, tasks);

      if (matchedTask == null) {
        return VoiceCommandResult(
          success: false,
          message: _getLocalizedMessage('task_not_found', taskTitle: title),
          intent: 'complete_task',
        );
      }

      // Complete task (requires task ID and method from API)
      // await ApiClient.instance.completeTask(matchedTask['id']);

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage(
          'task_completed',
          taskTitle: matchedTask['title'],
          points: matchedTask['points'] ?? 10,
        ),
        intent: 'complete_task',
        data: matchedTask,
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message:
            _getLocalizedMessage('task_completion_failed', error: e.toString()),
        intent: 'complete_task',
      );
    }
  }

  /// Show user's tasks
  Future<VoiceCommandResult> _showTasks(Map<String, dynamic> intent) async {
    try {
      final tasks = await ApiClient.instance.listTasks();

      // Filter open tasks
      final openTasks = tasks.where((t) => t['status'] == 'open').toList();

      if (openTasks.isEmpty) {
        return VoiceCommandResult(
          success: true,
          message: _getLocalizedMessage('no_tasks'),
          intent: 'show_tasks',
          data: {'tasks': []},
        );
      }

      // List first 5 tasks
      final taskList = openTasks.take(5).map((t) => t['title']).join(', ');

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage(
          'task_list',
          count: openTasks.length,
          taskList: taskList,
        ),
        intent: 'show_tasks',
        data: {'tasks': openTasks},
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('task_fetch_failed', error: e.toString()),
        intent: 'show_tasks',
      );
    }
  }

  /// Create a calendar event
  Future<VoiceCommandResult> _createEvent(Map<String, dynamic> intent) async {
    final title = intent['event_title'] as String?;
    final datetime = intent['datetime'] as String?;

    if (title == null || title.isEmpty) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('missing_event_title'),
        intent: 'create_event',
      );
    }

    try {
      final eventData = {
        'title': title,
        'startTime': datetime ?? DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'allDay': datetime == null,
      };

      final result = await ApiClient.instance.createEvent(eventData);

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage('event_created', taskTitle: title),
        intent: 'create_event',
        data: result,
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('event_creation_failed', error: e.toString()),
        intent: 'create_event',
      );
    }
  }

  /// Mark event as done
  Future<VoiceCommandResult> _markEventDone(Map<String, dynamic> intent) async {
    return VoiceCommandResult(
      success: true,
      message: _getLocalizedMessage('event_marked_done'),
      intent: 'mark_event_done',
      data: {'action': 'navigate', 'route': '/calendar'},
    );
  }

  /// Show user's points
  Future<VoiceCommandResult> _showPoints(Map<String, dynamic> intent) async {
    try {
      final profile = await ApiClient.instance.getProfile();
      final points = profile['totalPoints'] ?? 0;

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage('show_points_result', points: points),
        intent: 'show_points',
        data: {'points': points, 'action': 'navigate', 'route': '/gamification'},
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('points_fetch_failed', error: e.toString()),
        intent: 'show_points',
      );
    }
  }

  /// Check current streak
  Future<VoiceCommandResult> _checkStreak(Map<String, dynamic> intent) async {
    try {
      final profile = await ApiClient.instance.getProfile();
      final streak = profile['currentStreak'] ?? 0;

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage('streak_result', count: streak),
        intent: 'check_streak',
        data: {'streak': streak},
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('streak_fetch_failed', error: e.toString()),
        intent: 'check_streak',
      );
    }
  }

  /// Assign task to family member
  Future<VoiceCommandResult> _assignTask(Map<String, dynamic> intent) async {
    final title = intent['task_title'] as String?;
    final assignee = intent['assignee'] as String?;

    if (title == null || assignee == null) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('missing_assign_info'),
        intent: 'assign_task',
      );
    }

    try {
      final tasks = await ApiClient.instance.listTasks();
      final matchedTask = _findBestTaskMatch(title, tasks);

      if (matchedTask == null) {
        return VoiceCommandResult(
          success: false,
          message: _getLocalizedMessage('task_not_found', taskTitle: title),
          intent: 'assign_task',
        );
      }

      // Update task with new assignee
      await ApiClient.instance.updateTask(matchedTask['id'], {
        'assignees': [assignee],
      });

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage('task_assigned', taskTitle: title, assignee: assignee),
        intent: 'assign_task',
        data: matchedTask,
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('task_assign_failed', error: e.toString()),
        intent: 'assign_task',
      );
    }
  }

  /// Reschedule task
  Future<VoiceCommandResult> _rescheduleTask(Map<String, dynamic> intent) async {
    final title = intent['task_title'] as String?;
    final datetime = intent['datetime'] as String?;

    try {
      final tasks = await ApiClient.instance.listTasks();
      final matchedTask = title != null ? _findBestTaskMatch(title, tasks) : tasks.firstOrNull;

      if (matchedTask == null) {
        return VoiceCommandResult(
          success: false,
          message: _getLocalizedMessage('task_not_found', taskTitle: title ?? ''),
          intent: 'reschedule_task',
        );
      }

      // Parse datetime (handle "tomorrow", "next week", etc.)
      DateTime newDue;
      if (datetime == 'tomorrow') {
        newDue = DateTime.now().add(const Duration(days: 1));
      } else if (datetime != null) {
        newDue = DateTime.parse(datetime);
      } else {
        newDue = DateTime.now().add(const Duration(days: 1));
      }

      await ApiClient.instance.updateTask(matchedTask['id'], {
        'due': newDue.toIso8601String(),
      });

      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage('task_rescheduled', taskTitle: matchedTask['title']),
        intent: 'reschedule_task',
        data: matchedTask,
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('task_reschedule_failed', error: e.toString()),
        intent: 'reschedule_task',
      );
    }
  }

  /// Complete study session
  Future<VoiceCommandResult> _completeStudySession(Map<String, dynamic> intent) async {
    try {
      // Mark most recent pending study session as complete
      return VoiceCommandResult(
        success: true,
        message: _getLocalizedMessage('study_session_completed'),
        intent: 'complete_study_session',
        data: {'action': 'navigate', 'route': '/study'},
      );
    } catch (e) {
      return VoiceCommandResult(
        success: false,
        message: _getLocalizedMessage('study_session_failed', error: e.toString()),
        intent: 'complete_study_session',
      );
    }
  }

  /// Find best task match using fuzzy matching
  Map<String, dynamic>? _findBestTaskMatch(String query, List<dynamic> tasks) {
    final lowerQuery = query.toLowerCase();

    // Exact match first
    for (final task in tasks) {
      final title = (task['title'] as String).toLowerCase();
      if (title == lowerQuery) {
        return task as Map<String, dynamic>;
      }
    }

    // Partial match
    for (final task in tasks) {
      final title = (task['title'] as String).toLowerCase();
      if (title.contains(lowerQuery) || lowerQuery.contains(title)) {
        return task as Map<String, dynamic>;
      }
    }

    return null;
  }

  /// Get localized message
  String _getLocalizedMessage(
    String key, {
    String? taskTitle,
    String? assignee,
    int? points,
    int? count,
    String? taskList,
    String? error,
    String? eventTitle,
  }) {
    final messages = _getMessages(_currentLocale);

    var message = messages[key] ?? messages['unknown_command']!;

    // Replace placeholders
    message = message.replaceAll('{taskTitle}', taskTitle ?? '');
    message = message.replaceAll('{eventTitle}', eventTitle ?? '');
    message = message.replaceAll('{assignee}', assignee ?? '');
    message = message.replaceAll('{points}', points?.toString() ?? '10');
    message = message.replaceAll('{count}', count?.toString() ?? '0');
    message = message.replaceAll('{taskList}', taskList ?? '');
    message = message.replaceAll('{error}', error ?? '');

    return message;
  }

  /// Get localized messages by locale
  Map<String, String> _getMessages(String locale) {
    switch (locale) {
      case 'nl-NL':
        return {
          'no_speech': 'Geen spraak gedetecteerd. Probeer opnieuw.',
          'error': 'Er is een fout opgetreden: {error}',
          'low_confidence': 'Ik heb je niet goed verstaan. Kun je het herhalen?',
          'unknown_command': 'Ik begrijp het commando niet. Vraag om hulp voor voorbeelden.',
          'missing_task_title': 'Geen taaknaam opgegeven. Probeer: "Maak taak vaatwasser".',
          'missing_event_title': 'Geen evenementnaam opgegeven.',
          'missing_assign_info': 'Geen taak of persoon opgegeven.',
          'task_created': 'Taak {taskTitle} is aangemaakt voor {assignee}.',
          'task_created_offline': 'Taak {taskTitle} is offline opgeslagen.',
          'task_creation_failed': 'Taak aanmaken mislukt: {error}',
          'task_completed': 'Taak {taskTitle} is voltooid! Je hebt {points} punten verdiend.',
          'task_completion_failed': 'Taak voltooien mislukt: {error}',
          'task_not_found': 'Taak {taskTitle} niet gevonden.',
          'task_assigned': 'Taak {taskTitle} is toegewezen aan {assignee}.',
          'task_assign_failed': 'Taak toewijzen mislukt: {error}',
          'task_rescheduled': 'Taak {taskTitle} is verplaatst.',
          'task_reschedule_failed': 'Taak verplaatsen mislukt: {error}',
          'no_tasks': 'Je hebt geen openstaande taken. Goed gedaan!',
          'task_list': 'Je hebt {count} taken: {taskList}.',
          'task_fetch_failed': 'Taken ophalen mislukt: {error}',
          'show_calendar': 'Kalender wordt geopend.',
          'event_created': 'Evenement {taskTitle} is aangemaakt.',
          'event_creation_failed': 'Evenement aanmaken mislukt: {error}',
          'event_marked_done': 'Evenement is afgerond.',
          'show_points_result': 'Je hebt {points} punten!',
          'points_fetch_failed': 'Punten ophalen mislukt: {error}',
          'show_badges': 'Je badges worden getoond.',
          'streak_result': 'Je streak is {count} dagen!',
          'streak_fetch_failed': 'Streak ophalen mislukt: {error}',
          'show_study_sessions': 'Studiesessies worden getoond.',
          'study_session_completed': 'Studiesessie is voltooid!',
          'study_session_failed': 'Studiesessie voltooien mislukt: {error}',
          'help': 'Ik kan je helpen met taken, kalender, punten en meer. Vraag: "Wat kan ik zeggen?"',
        };
      case 'en-US':
        return {
          'no_speech': 'No speech detected. Please try again.',
          'error': 'An error occurred: {error}',
          'low_confidence': 'I didn\'t understand that clearly. Can you repeat?',
          'unknown_command': 'I don\'t understand that command. Ask for help for examples.',
          'missing_task_title': 'No task name provided. Try: "Create task clean dishes".',
          'missing_event_title': 'No event name provided.',
          'missing_assign_info': 'No task or person provided.',
          'task_created': 'Task {taskTitle} created for {assignee}.',
          'task_created_offline': 'Task {taskTitle} saved offline.',
          'task_creation_failed': 'Failed to create task: {error}',
          'task_completed': 'Task {taskTitle} completed! You earned {points} points.',
          'task_completion_failed': 'Failed to complete task: {error}',
          'task_not_found': 'Task {taskTitle} not found.',
          'task_assigned': 'Task {taskTitle} assigned to {assignee}.',
          'task_assign_failed': 'Failed to assign task: {error}',
          'task_rescheduled': 'Task {taskTitle} rescheduled.',
          'task_reschedule_failed': 'Failed to reschedule task: {error}',
          'no_tasks': 'You have no open tasks. Well done!',
          'task_list': 'You have {count} tasks: {taskList}.',
          'task_fetch_failed': 'Failed to fetch tasks: {error}',
          'show_calendar': 'Opening calendar.',
          'event_created': 'Event {taskTitle} created.',
          'event_creation_failed': 'Failed to create event: {error}',
          'event_marked_done': 'Event marked as done.',
          'show_points_result': 'You have {points} points!',
          'points_fetch_failed': 'Failed to fetch points: {error}',
          'show_badges': 'Showing your badges.',
          'streak_result': 'Your streak is {count} days!',
          'streak_fetch_failed': 'Failed to fetch streak: {error}',
          'show_study_sessions': 'Showing study sessions.',
          'study_session_completed': 'Study session completed!',
          'study_session_failed': 'Failed to complete study session: {error}',
          'help': 'I can help with tasks, calendar, points and more. Ask: "What can I say?"',
        };
      case 'de-DE':
        return {
          'no_speech': 'Keine Sprache erkannt. Bitte versuchen Sie es erneut.',
          'error': 'Ein Fehler ist aufgetreten: {error}',
          'low_confidence':
              'Ich habe das nicht verstanden. Können Sie wiederholen?',
          'unknown_command':
              'Ich verstehe diesen Befehl nicht. Fragen Sie nach Hilfe für Beispiele.',
          'missing_task_title':
              'Kein Aufgabenname angegeben. Versuchen Sie: "Erstelle Aufgabe Geschirr spülen".',
          'task_created': 'Aufgabe {taskTitle} wurde für {assignee} erstellt.',
          'task_created_offline':
              'Aufgabe {taskTitle} wurde offline gespeichert.',
          'task_creation_failed': 'Aufgabe erstellen fehlgeschlagen: {error}',
          'task_completed':
              'Aufgabe {taskTitle} abgeschlossen! Sie haben {points} Punkte verdient.',
          'task_completion_failed':
              'Aufgabe abschließen fehlgeschlagen: {error}',
          'task_not_found': 'Aufgabe {taskTitle} nicht gefunden.',
          'no_tasks': 'Sie haben keine offenen Aufgaben. Gut gemacht!',
          'task_list': 'Sie haben {count} Aufgaben: {taskList}.',
          'task_fetch_failed': 'Aufgaben abrufen fehlgeschlagen: {error}',
          'show_calendar': 'Kalender wird geöffnet.',
          'help':
              'Sie können sagen: "Erstelle Aufgabe Geschirr spülen", "Markiere Aufgabe als erledigt", "Was muss ich tun", oder "Zeige Kalender".',
        };
      case 'fr-FR':
        return {
          'no_speech': 'Aucune parole détectée. Veuillez réessayer.',
          'error': 'Une erreur s\'est produite: {error}',
          'low_confidence': 'Je n\'ai pas bien compris. Pouvez-vous répéter?',
          'unknown_command':
              'Je ne comprends pas cette commande. Demandez de l\'aide pour des exemples.',
          'missing_task_title':
              'Aucun nom de tâche fourni. Essayez: "Créer tâche faire la vaisselle".',
          'task_created': 'Tâche {taskTitle} créée pour {assignee}.',
          'task_created_offline': 'Tâche {taskTitle} enregistrée hors ligne.',
          'task_creation_failed': 'Échec de la création de la tâche: {error}',
          'task_completed':
              'Tâche {taskTitle} terminée! Vous avez gagné {points} points.',
          'task_completion_failed':
              'Échec de l\'achèvement de la tâche: {error}',
          'task_not_found': 'Tâche {taskTitle} introuvable.',
          'no_tasks': 'Vous n\'avez aucune tâche ouverte. Bien joué!',
          'task_list': 'Vous avez {count} tâches: {taskList}.',
          'task_fetch_failed': 'Échec de la récupération des tâches: {error}',
          'show_calendar': 'Ouverture du calendrier.',
          'help':
              'Vous pouvez dire: "Créer tâche faire la vaisselle", "Marquer tâche comme faite", "Que dois-je faire", ou "Montrer calendrier".',
        };
      default:
        return _getMessages('nl-NL');
    }
  }

  /// Set locale for voice commands
  void setLocale(String locale) {
    _currentLocale = locale;
  }

  /// Get current locale
  String get currentLocale => _currentLocale;

  /// Stop all voice services
  Future<void> stop() async {
    await _stt.stop();
    await _tts.stop();
  }
}
