import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase.dart';
import '../../core/app_logger.dart';

/// Data Export Screen
///
/// Features:
/// - Export user data to JSON (GDPR compliance)
/// - Export family data (if parent role)
/// - Download options: copy to clipboard or save as file
/// - Includes: tasks, events, points, badges, study items, settings
/// - "Right to Data Portability" compliance (GDPR Article 20)
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  bool _isExporting = false;
  bool _includeFamily = false;
  String? _exportedData;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = currentUser;
      if (user == null) return;

      final data = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _userRole = data['role'] as String?;
        });
      }
    } catch (e) {
      AppLogger.debug('[DATA_EXPORT] Error loading user role: $e');
    }
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Geen gebruiker gevonden');
      }

      // Fetch all user data from Supabase
      final userData = await supabase
          .from('users')
          .select('*')
          .eq('id', user.id)
          .single();

      // Fetch tasks
      final tasks = await supabase
          .from('tasks')
          .select('*')
          .or('assignees.cs.{${user.id}},created_by.eq.${user.id}');

      // Fetch events
      final events = await supabase
          .from('events')
          .select('*')
          .or('attendees.cs.{${user.id}},created_by.eq.${user.id}');

      // Fetch points ledger
      final points = await supabase
          .from('points_ledger')
          .select('*')
          .eq('user_id', user.id);

      // Fetch badges
      final badges = await supabase
          .from('badges')
          .select('*')
          .eq('user_id', user.id);

      // Fetch study items
      final studyItems = await supabase
          .from('study_items')
          .select('*')
          .eq('user_id', user.id);

      // Fetch study sessions
      final studyItemIds = studyItems.map((s) => s['id']).toList();
      final studySessions = studyItemIds.isEmpty
          ? []
          : await supabase
              .from('study_sessions')
              .select('*')
              .inFilter('study_item_id', studyItemIds);

      // Build export object
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'export_version': '1.0',
        'user': {
          'id': userData['id'],
          'email': userData['email'],
          'display_name': userData['display_name'],
          'role': userData['role'],
          'locale': userData['locale'],
          'theme': userData['theme'],
          'avatar': userData['avatar'],
          'created_at': userData['created_at'],
        },
        'tasks': tasks,
        'events': events,
        'points_ledger': points,
        'badges': badges,
        'study_items': studyItems,
        'study_sessions': studySessions,
      };

      // If parent and include family data selected
      if (_includeFamily && _userRole == 'parent') {
        final familyId = userData['family_id'];

        if (familyId != null) {
          // Fetch family data
          final family = await supabase
              .from('families')
              .select('*')
              .eq('id', familyId)
              .single();

          final familyMembers = await supabase
              .from('users')
              .select('id, display_name, role, email')
              .eq('family_id', familyId);

          final familyTasks = await supabase
              .from('tasks')
              .select('*')
              .eq('family_id', familyId);

          final familyEvents = await supabase
              .from('events')
              .select('*')
              .eq('family_id', familyId);

          final familyRewards = await supabase
              .from('rewards')
              .select('*')
              .eq('family_id', familyId);

          exportData['family'] = {
            'info': family,
            'members': familyMembers,
            'all_tasks': familyTasks,
            'all_events': familyEvents,
            'rewards': familyRewards,
          };
        }
      }

      // Convert to pretty JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      if (mounted) {
        setState(() {
          _exportedData = jsonString;
          _isExporting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gegevens succesvol geëxporteerd!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij exporteren: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_exportedData == null) return;

    await Clipboard.setData(ClipboardData(text: _exportedData!));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gekopieerd naar klembord!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gegevens Exporteren'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Recht op gegevensoverdracht',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Op basis van de AVG (GDPR) heb je het recht om je gegevens te exporteren in een '
                      'gestructureerd en machineleesbaar formaat (JSON).',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Export options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wat wordt geëxporteerd?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildExportItem(Icons.person, 'Profielgegevens'),
                    _buildExportItem(Icons.task_alt, 'Taken'),
                    _buildExportItem(Icons.calendar_month, 'Evenementen'),
                    _buildExportItem(Icons.stars, 'Punten & Badges'),
                    _buildExportItem(Icons.school, 'Studieplanning'),
                    _buildExportItem(Icons.settings, 'Instellingen'),

                    // Family data option (only for parents)
                    if (_userRole == 'parent') ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _includeFamily,
                        onChanged: _isExporting
                            ? null
                            : (value) => setState(() => _includeFamily = value),
                        title: const Text('Familie gegevens meenemen'),
                        subtitle: const Text(
                          'Exporteer ook gegevens van alle familieleden (alleen ouders)',
                          style: TextStyle(fontSize: 13),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Export button
            FilledButton.icon(
              onPressed: _isExporting ? null : _exportData,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                _isExporting ? 'Exporteren...' : 'Gegevens Exporteren',
                style: const TextStyle(fontSize: 16),
              ),
            ),

            // Show export result
            if (_exportedData != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Export gereed!',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Grootte: ${(_exportedData!.length / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy),
                        label: const Text('Kopieer naar klembord'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Je kunt de gekopieerde JSON-data opslaan in een tekstbestand '
                        'of gebruiken voor import in andere systemen.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // GDPR info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        size: 20,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Privacy & Beveiliging',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Geëxporteerde data bevat geen wachtwoorden\n'
                    '• Alleen jouw eigen gegevens (tenzij familie export)\n'
                    '• Data blijft niet op de server opgeslagen\n'
                    '• Export wordt lokaal in je browser gegenereerd',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          const Icon(Icons.check, size: 20, color: Colors.green),
        ],
      ),
    );
  }
}
