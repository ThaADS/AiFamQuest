import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_logger.dart';

/// Natural Language Understanding service using OpenRouter (Claude Haiku)
/// Parses voice commands and extracts intents, entities, and parameters
class NLUService {
  static final NLUService instance = NLUService._();
  NLUService._();

  // OpenRouter API configuration
  static const _apiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );
  static const _baseUrl = 'https://openrouter.ai/api/v1';
  static const _model = 'anthropic/claude-3-haiku'; // Fast, cheap for NLU

  bool _initialized = false;

  /// Initialize OpenRouter client
  void initialize() {
    if (_initialized) return;

    if (_apiKey.isEmpty) {
      AppLogger.debug('Warning: OPENROUTER_API_KEY not set, NLU may fail');
    }

    _initialized = true;
  }

  /// Parse voice command and extract intent
  ///
  /// Supported intents:
  /// - create_task: Create a new task
  /// - complete_task: Mark task as done
  /// - show_tasks: Display user's tasks
  /// - show_calendar: Display calendar
  /// - create_event: Create calendar event
  /// - mark_event_done: Mark event as complete
  /// - show_points: Display user's points
  /// - show_badges: Display earned badges
  /// - check_streak: Display current streak
  /// - assign_task: Assign task to family member
  /// - reschedule_task: Change task due date
  /// - show_study_sessions: Display study schedule
  /// - complete_study_session: Mark study session complete
  /// - help: Show help information
  /// - unknown: Unable to parse intent
  ///
  /// Returns a map with:
  /// - intent: String (intent type)
  /// - task_title/event_title: String? (title if applicable)
  /// - assignee: String? (user name if mentioned)
  /// - datetime: String? (ISO datetime if mentioned)
  /// - confidence: double (0.0 - 1.0)
  Future<Map<String, dynamic>> parseIntent(
    String text, {
    required String locale,
    List<String>? userNames,
  }) async {
    if (!_initialized) {
      initialize();
    }

    try {
      // Build prompt with context
      final prompt = _buildPrompt(text, locale, userNames);

      // Call OpenRouter API
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://famquest.app',
          'X-Title': 'FamQuest Voice Commands',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.2,
          'max_tokens': 200,
        }),
      );

      if (response.statusCode != 200) {
        AppLogger.debug('OpenRouter API failed: ${response.statusCode} ${response.body}');
        return _fallbackPatternMatch(text, locale, userNames);
      }

      final data = jsonDecode(response.body);
      final responseText = data['choices'][0]['message']['content'].trim();

      // Parse JSON response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final result = jsonDecode(jsonStr) as Map<String, dynamic>;

        // Add confidence score based on clarity of parsing
        result['confidence'] = _calculateConfidence(result);

        return result;
      }

      // Fallback to pattern matching if JSON parsing fails
      return _fallbackPatternMatch(text, locale, userNames);
    } catch (e) {
      AppLogger.debug('NLU parsing failed: $e');

      // Fallback to pattern matching
      return _fallbackPatternMatch(text, locale, userNames);
    }
  }

  /// Build prompt for OpenRouter (Claude Haiku)
  String _buildPrompt(String text, String locale, List<String>? userNames) {
    final examples = _getExamplesByLocale(locale);
    final userNamesStr = userNames?.join(', ') ?? 'Noah, Luna, Sam, Eva, Mark';

    return '''
Parse this voice command and extract structured information.

Command: "$text"
Language: $locale
Family members: $userNamesStr

Extract:
- intent: create_task | complete_task | show_tasks | show_calendar | create_event | mark_event_done | show_points | show_badges | check_streak | assign_task | reschedule_task | show_study_sessions | complete_study_session | help | unknown
- task_title/event_title: string (task/event name if applicable)
- assignee: string (family member name if mentioned)
- datetime: ISO 8601 string (if date/time mentioned)
- note: string (any additional context)

Examples:
$examples

Return ONLY valid JSON:
{"intent": "create_task", "task_title": "Vaatwasser", "assignee": "Noah", "datetime": null, "note": null}
''';
  }

  /// Get example commands by locale
  String _getExamplesByLocale(String locale) {
    switch (locale) {
      case 'nl-NL':
        return '''
"Maak taak vaatwasser voor Noah" → {"intent": "create_task", "task_title": "Vaatwasser", "assignee": "Noah"}
"Markeer kamer opruimen als klaar" → {"intent": "complete_task", "task_title": "Kamer opruimen"}
"Wat moet ik vandaag doen" → {"intent": "show_tasks"}
"Toon kalender" → {"intent": "show_calendar"}
"Plan familie-etentje vrijdag om 18:00" → {"intent": "create_event", "event_title": "Familie-etentje", "datetime": "2025-11-22T18:00:00"}
"Hoeveel punten heb ik" → {"intent": "show_points"}
"Laat mijn badges zien" → {"intent": "show_badges"}
"Wat is mijn streak" → {"intent": "check_streak"}
"Wijs wasbeurt toe aan Luna" → {"intent": "assign_task", "task_title": "Wasbeurt", "assignee": "Luna"}
"Verplaats taak naar morgen" → {"intent": "reschedule_task", "datetime": "tomorrow"}
"Wat moet ik studeren" → {"intent": "show_study_sessions"}
"Studiesessie is klaar" → {"intent": "complete_study_session"}
"Help" → {"intent": "help"}
''';
      case 'en-US':
        return '''
"Create task clean dishes for Noah" → {"intent": "create_task", "task_title": "Clean dishes", "assignee": "Noah"}
"Mark clean room as done" → {"intent": "complete_task", "task_title": "Clean room"}
"What do I need to do today" → {"intent": "show_tasks"}
"Show calendar" → {"intent": "show_calendar"}
"Schedule family dinner Friday at 6pm" → {"intent": "create_event", "event_title": "Family dinner", "datetime": "2025-11-22T18:00:00"}
"How many points do I have" → {"intent": "show_points"}
"Show my badges" → {"intent": "show_badges"}
"What's my streak" → {"intent": "check_streak"}
"Assign laundry to Luna" → {"intent": "assign_task", "task_title": "Laundry", "assignee": "Luna"}
"Move task to tomorrow" → {"intent": "reschedule_task", "datetime": "tomorrow"}
"What do I need to study" → {"intent": "show_study_sessions"}
"Study session is done" → {"intent": "complete_study_session"}
"Help" → {"intent": "help"}
''';
      case 'de-DE':
        return '''
"Erstelle Aufgabe Geschirr spülen für Noah" → {"intent": "create_task", "task_title": "Geschirr spülen", "assignee": "Noah"}
"Markiere Zimmer aufräumen als erledigt" → {"intent": "complete_task", "task_title": "Zimmer aufräumen"}
"Was muss ich heute machen" → {"intent": "show_tasks"}
"Zeige Kalender" → {"intent": "show_calendar"}
"Plane Familienessen Freitag um 18 Uhr" → {"intent": "create_event", "event_title": "Familienessen", "datetime": "2025-11-22T18:00:00"}
"Wie viele Punkte habe ich" → {"intent": "show_points"}
"Zeige meine Abzeichen" → {"intent": "show_badges"}
"Was ist meine Streak" → {"intent": "check_streak"}
"Hilfe" → {"intent": "help"}
''';
      case 'fr-FR':
        return '''
"Créer tâche faire la vaisselle pour Noah" → {"intent": "create_task", "task_title": "Faire la vaisselle", "assignee": "Noah"}
"Marquer ranger chambre comme fait" → {"intent": "complete_task", "task_title": "Ranger chambre"}
"Qu'est-ce que je dois faire aujourd'hui" → {"intent": "show_tasks"}
"Montrer calendrier" → {"intent": "show_calendar"}
"Planifier dîner en famille vendredi à 18h" → {"intent": "create_event", "event_title": "Dîner en famille", "datetime": "2025-11-22T18:00:00"}
"Combien de points ai-je" → {"intent": "show_points"}
"Montrer mes badges" → {"intent": "show_badges"}
"Quelle est ma série" → {"intent": "check_streak"}
"Aide" → {"intent": "help"}
''';
      default:
        return _getExamplesByLocale('nl-NL');
    }
  }

  /// Calculate confidence score
  double _calculateConfidence(Map<String, dynamic> result) {
    double confidence = 0.8; // Base confidence

    // Increase confidence if task_title is present
    if (result['task_title'] != null && result['task_title'].toString().isNotEmpty) {
      confidence += 0.1;
    }

    // Increase confidence if assignee is present
    if (result['assignee'] != null && result['assignee'].toString().isNotEmpty) {
      confidence += 0.05;
    }

    // Decrease confidence for unknown intent
    if (result['intent'] == 'unknown') {
      confidence = 0.3;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Fallback pattern matching for common commands
  Map<String, dynamic> _fallbackPatternMatch(
    String text,
    String locale,
    List<String>? userNames,
  ) {
    final lowerText = text.toLowerCase();

    // Create task patterns
    final createPatterns = _getCreateTaskPatterns(locale);
    for (final pattern in createPatterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        return {
          'intent': 'create_task',
          'task_title': match.group(1)?.trim() ?? '',
          'assignee': _findUserName(text, userNames),
          'datetime': null,
          'note': null,
          'confidence': 0.6,
        };
      }
    }

    // Complete task patterns
    final completePatterns = _getCompleteTaskPatterns(locale);
    for (final pattern in completePatterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        return {
          'intent': 'complete_task',
          'task_title': match.group(1)?.trim() ?? '',
          'assignee': null,
          'datetime': null,
          'note': null,
          'confidence': 0.6,
        };
      }
    }

    // Show tasks patterns
    final showTasksPatterns = _getShowTasksPatterns(locale);
    for (final pattern in showTasksPatterns) {
      if (pattern.hasMatch(lowerText)) {
        return {
          'intent': 'show_tasks',
          'task_title': null,
          'assignee': null,
          'datetime': null,
          'note': null,
          'confidence': 0.7,
        };
      }
    }

    // Unknown intent
    return {
      'intent': 'unknown',
      'task_title': null,
      'assignee': null,
      'datetime': null,
      'note': text,
      'confidence': 0.2,
    };
  }

  /// Get create task patterns by locale
  List<RegExp> _getCreateTaskPatterns(String locale) {
    switch (locale) {
      case 'nl-NL':
        return [
          RegExp(r'maak taak (.+?)(?:\s+voor|$)'),
          RegExp(r'voeg toe (.+?)(?:\s+aan de lijst|$)'),
          RegExp(r'nieuwe taak (.+)'),
          RegExp(r'creëer (.+)'),
        ];
      case 'en-US':
        return [
          RegExp(r'create task (.+?)(?:\s+for|$)'),
          RegExp(r'add (.+?)(?:\s+to the list|$)'),
          RegExp(r'new task (.+)'),
        ];
      case 'de-DE':
        return [
          RegExp(r'erstelle aufgabe (.+?)(?:\s+für|$)'),
          RegExp(r'füge (.+?)(?:\s+hinzu|$)'),
          RegExp(r'neue aufgabe (.+)'),
        ];
      case 'fr-FR':
        return [
          RegExp(r'créer tâche (.+?)(?:\s+pour|$)'),
          RegExp(r'ajouter (.+?)(?:\s+à la liste|$)'),
          RegExp(r'nouvelle tâche (.+)'),
        ];
      default:
        return _getCreateTaskPatterns('nl-NL');
    }
  }

  /// Get complete task patterns by locale
  List<RegExp> _getCompleteTaskPatterns(String locale) {
    switch (locale) {
      case 'nl-NL':
        return [
          RegExp(r'markeer (.+?)(?:\s+als klaar|\s+als gedaan|$)'),
          RegExp(r'(.+?)(?:\s+is klaar|\s+is gedaan)'),
          RegExp(r'voltooi (.+)'),
        ];
      case 'en-US':
        return [
          RegExp(r'mark (.+?)(?:\s+as done|\s+as complete|$)'),
          RegExp(r'(.+?)(?:\s+is done|\s+is complete)'),
          RegExp(r'complete (.+)'),
        ];
      case 'de-DE':
        return [
          RegExp(r'markiere (.+?)(?:\s+als erledigt|$)'),
          RegExp(r'(.+?)(?:\s+ist erledigt)'),
        ];
      case 'fr-FR':
        return [
          RegExp(r'marquer (.+?)(?:\s+comme fait|$)'),
          RegExp(r'(.+?)(?:\s+est fait)'),
        ];
      default:
        return _getCompleteTaskPatterns('nl-NL');
    }
  }

  /// Get show tasks patterns by locale
  List<RegExp> _getShowTasksPatterns(String locale) {
    switch (locale) {
      case 'nl-NL':
        return [
          RegExp(r'wat moet ik (vandaag|nu)? doen'),
          RegExp(r'laat mijn taken zien'),
          RegExp(r'toon taken'),
          RegExp(r'laat taken zien'),
        ];
      case 'en-US':
        return [
          RegExp(r'what (do|should) i (do|need to do) (today|now)?'),
          RegExp(r'show (my )?tasks'),
          RegExp(r'list (my )?tasks'),
        ];
      case 'de-DE':
        return [
          RegExp(r'was muss ich (heute|jetzt)? (tun|machen)'),
          RegExp(r'zeige meine aufgaben'),
        ];
      case 'fr-FR':
        return [
          RegExp(r"qu'est-ce que je dois faire (aujourd'hui|maintenant)?"),
          RegExp(r'montrer mes tâches'),
        ];
      default:
        return _getShowTasksPatterns('nl-NL');
    }
  }

  /// Find user name in text
  String? _findUserName(String text, List<String>? userNames) {
    if (userNames == null) return null;

    final lowerText = text.toLowerCase();
    for (final name in userNames) {
      if (lowerText.contains(name.toLowerCase())) {
        return name;
      }
    }

    return null;
  }
}
