import 'package:flutter/material.dart';

/// Voice Command Help Screen
///
/// Shows all available voice commands with examples in multiple languages
class VoiceCommandHelpScreen extends StatelessWidget {
  const VoiceCommandHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final commands = _getCommandsByLocale(locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(locale)),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: commands.length,
        itemBuilder: (context, index) {
          final category = commands[index];
          return _CommandCategoryCard(
            category: category['category']!,
            commands: category['commands'] as List<Map<String, String>>,
          );
        },
      ),
    );
  }

  String _getTitle(String locale) {
    switch (locale) {
      case 'nl':
        return 'Spraakcommando\'s';
      case 'de':
        return 'Sprachbefehle';
      case 'fr':
        return 'Commandes vocales';
      default:
        return 'Voice Commands';
    }
  }

  List<Map<String, dynamic>> _getCommandsByLocale(String locale) {
    switch (locale) {
      case 'nl':
        return [
          {
            'category': 'Taken',
            'commands': [
              {
                'command': 'Maak taak [naam] voor [persoon]',
                'example': 'Maak taak vaatwasser voor Noah'
              },
              {
                'command': 'Markeer [taak] als klaar',
                'example': 'Markeer kamer opruimen als klaar'
              },
              {'command': 'Wat moet ik doen', 'example': 'Wat moet ik vandaag doen'},
              {
                'command': 'Wijs [taak] toe aan [persoon]',
                'example': 'Wijs wasbeurt toe aan Luna'
              },
              {
                'command': 'Verplaats taak naar [datum]',
                'example': 'Verplaats taak naar morgen'
              },
            ],
          },
          {
            'category': 'Kalender',
            'commands': [
              {'command': 'Toon kalender', 'example': 'Laat mijn kalender zien'},
              {
                'command': 'Plan [evenement] op [datum]',
                'example': 'Plan familie-etentje vrijdag om 18:00'
              },
            ],
          },
          {
            'category': 'Gamification',
            'commands': [
              {'command': 'Hoeveel punten heb ik', 'example': 'Laat mijn punten zien'},
              {'command': 'Laat mijn badges zien', 'example': 'Toon badges'},
              {'command': 'Wat is mijn streak', 'example': 'Hoeveel dagen streak heb ik'},
            ],
          },
          {
            'category': 'Studie',
            'commands': [
              {'command': 'Wat moet ik studeren', 'example': 'Laat studiesessies zien'},
              {'command': 'Studiesessie is klaar', 'example': 'Markeer sessie als voltooid'},
            ],
          },
          {
            'category': 'Help',
            'commands': [
              {'command': 'Help', 'example': 'Wat kan ik zeggen'},
            ],
          },
        ];

      case 'de':
        return [
          {
            'category': 'Aufgaben',
            'commands': [
              {
                'command': 'Erstelle Aufgabe [Name] für [Person]',
                'example': 'Erstelle Aufgabe Geschirr spülen für Noah'
              },
              {
                'command': 'Markiere [Aufgabe] als erledigt',
                'example': 'Markiere Zimmer aufräumen als erledigt'
              },
              {'command': 'Was muss ich machen', 'example': 'Was muss ich heute machen'},
            ],
          },
          {
            'category': 'Kalender',
            'commands': [
              {'command': 'Zeige Kalender', 'example': 'Zeige meinen Kalender'},
              {
                'command': 'Plane [Ereignis] am [Datum]',
                'example': 'Plane Familienessen Freitag um 18 Uhr'
              },
            ],
          },
          {
            'category': 'Gamification',
            'commands': [
              {'command': 'Wie viele Punkte habe ich', 'example': 'Zeige meine Punkte'},
              {'command': 'Zeige meine Abzeichen', 'example': 'Zeige Abzeichen'},
              {'command': 'Was ist meine Streak', 'example': 'Wie viele Tage Streak'},
            ],
          },
        ];

      case 'fr':
        return [
          {
            'category': 'Tâches',
            'commands': [
              {
                'command': 'Créer tâche [nom] pour [personne]',
                'example': 'Créer tâche faire la vaisselle pour Noah'
              },
              {
                'command': 'Marquer [tâche] comme fait',
                'example': 'Marquer ranger chambre comme fait'
              },
              {'command': 'Que dois-je faire', 'example': 'Que dois-je faire aujourd\'hui'},
            ],
          },
          {
            'category': 'Calendrier',
            'commands': [
              {'command': 'Montrer calendrier', 'example': 'Montrer mon calendrier'},
              {
                'command': 'Planifier [événement] le [date]',
                'example': 'Planifier dîner en famille vendredi à 18h'
              },
            ],
          },
          {
            'category': 'Gamification',
            'commands': [
              {'command': 'Combien de points ai-je', 'example': 'Montrer mes points'},
              {'command': 'Montrer mes badges', 'example': 'Montrer badges'},
              {'command': 'Quelle est ma série', 'example': 'Combien de jours de série'},
            ],
          },
        ];

      default: // English
        return [
          {
            'category': 'Tasks',
            'commands': [
              {
                'command': 'Create task [name] for [person]',
                'example': 'Create task clean dishes for Noah'
              },
              {
                'command': 'Mark [task] as done',
                'example': 'Mark clean room as done'
              },
              {'command': 'What do I need to do', 'example': 'What do I need to do today'},
              {
                'command': 'Assign [task] to [person]',
                'example': 'Assign laundry to Luna'
              },
              {
                'command': 'Move task to [date]',
                'example': 'Move task to tomorrow'
              },
            ],
          },
          {
            'category': 'Calendar',
            'commands': [
              {'command': 'Show calendar', 'example': 'Show my calendar'},
              {
                'command': 'Schedule [event] on [date]',
                'example': 'Schedule family dinner Friday at 6pm'
              },
            ],
          },
          {
            'category': 'Gamification',
            'commands': [
              {'command': 'How many points do I have', 'example': 'Show my points'},
              {'command': 'Show my badges', 'example': 'Show badges'},
              {'command': 'What\'s my streak', 'example': 'How many days streak'},
            ],
          },
          {
            'category': 'Study',
            'commands': [
              {'command': 'What do I need to study', 'example': 'Show study sessions'},
              {'command': 'Study session is done', 'example': 'Mark session as complete'},
            ],
          },
          {
            'category': 'Help',
            'commands': [
              {'command': 'Help', 'example': 'What can I say'},
            ],
          },
        ];
    }
  }
}

class _CommandCategoryCard extends StatelessWidget {
  final String category;
  final List<Map<String, String>> commands;

  const _CommandCategoryCard({
    required this.category,
    required this.commands,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...commands.map((cmd) => _CommandTile(
                  command: cmd['command']!,
                  example: cmd['example']!,
                )),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (category.toLowerCase()) {
      case 'tasks':
      case 'taken':
      case 'aufgaben':
      case 'tâches':
        return Icons.check_circle_outline;
      case 'calendar':
      case 'kalender':
      case 'calendrier':
        return Icons.calendar_today;
      case 'gamification':
        return Icons.emoji_events;
      case 'study':
      case 'studie':
        return Icons.school;
      case 'help':
        return Icons.help_outline;
      default:
        return Icons.mic;
    }
  }
}

class _CommandTile extends StatelessWidget {
  final String command;
  final String example;

  const _CommandTile({
    required this.command,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            command,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.mic,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  example,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
