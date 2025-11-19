import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../api/client.dart';
import '../../core/app_logger.dart';

/// Privacy Settings Screen
///
/// Features:
/// - GDPR consent management
/// - Analytics tracking toggle
/// - Marketing communications toggle
/// - Cookie policy information
/// - Links to privacy policy and terms of service
/// - Clear explanation of what data is collected
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _analyticsConsent = false;
  bool _marketingConsent = false;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    setState(() => _isLoading = true);

    try {
      // First check local storage (for offline access)
      final localAnalytics = await _storage.read(key: 'gdpr_analytics_consent');
      final localMarketing = await _storage.read(key: 'gdpr_marketing_consent');

      if (localAnalytics != null) {
        setState(() {
          _analyticsConsent = localAnalytics == 'true';
          _marketingConsent = localMarketing == 'true';
        });
      }

      // Then fetch from backend (authoritative source)
      final response = await ApiClient.instance.getGdprConsent();

      if (mounted) {
        setState(() {
          _analyticsConsent = response['analytics_consent'] ?? false;
          _marketingConsent = response['marketing_consent'] ?? false;
          _isLoading = false;
        });

        // Update local storage
        await _storage.write(
          key: 'gdpr_analytics_consent',
          value: _analyticsConsent.toString(),
        );
        await _storage.write(
          key: 'gdpr_marketing_consent',
          value: _marketingConsent.toString(),
        );
      }
    } catch (e) {
      AppLogger.debug('[PRIVACY] Error loading consent: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveConsent() async {
    setState(() => _isSaving = true);

    try {
      await ApiClient.instance.setGdprConsent(
        analyticsConsent: _analyticsConsent,
        marketingConsent: _marketingConsent,
      );

      // Update local storage
      await _storage.write(
        key: 'gdpr_analytics_consent',
        value: _analyticsConsent.toString(),
      );
      await _storage.write(
        key: 'gdpr_marketing_consent',
        value: _marketingConsent.toString(),
      );

      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy instellingen opgeslagen'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Instellingen'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                                Icons.privacy_tip_outlined,
                                color: theme.colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Jouw privacy is belangrijk',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Wij respecteren je privacy en geven je volledige controle over '
                            'hoe je gegevens gebruikt worden. Je kunt je toestemming op '
                            'elk moment wijzigen.',
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Consent options
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toestemming beheren',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Analytics consent
                          SwitchListTile(
                            value: _analyticsConsent,
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() => _analyticsConsent = value),
                            title: const Text(
                              'Analytics & Prestaties',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Text(
                              'Help ons FamQuest te verbeteren door anonieme '
                              'gebruiksgegevens te verzamelen zoals schermweergaven, '
                              'crashes en prestatiemetingen.',
                              style: TextStyle(fontSize: 13),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: theme.colorScheme.primary,
                          ),

                          const Divider(height: 32),

                          // Marketing consent
                          SwitchListTile(
                            value: _marketingConsent,
                            onChanged: _isSaving
                                ? null
                                : (value) => setState(() => _marketingConsent = value),
                            title: const Text(
                              'Marketing Communicatie',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Text(
                              'Ontvang updates over nieuwe functies, tips en aanbiedingen '
                              'die relevant voor je zijn.',
                              style: TextStyle(fontSize: 13),
                            ),
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Save button
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveConsent,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Opslaan...' : 'Opslaan'),
                  ),

                  const SizedBox(height: 32),

                  // What we collect
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wat verzamelen wij?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildDataItem(
                            Icons.account_circle,
                            'Account gegevens',
                            'E-mailadres, naam, rol in gezin',
                          ),
                          _buildDataItem(
                            Icons.task_alt,
                            'Activiteit',
                            'Taken, evenementen, punten, badges',
                          ),
                          _buildDataItem(
                            Icons.devices,
                            'Apparaat informatie',
                            'Platform, versie, apparaattype (alleen met analytics toestemming)',
                          ),
                          _buildDataItem(
                            Icons.location_off,
                            'Geen locatie',
                            'Wij verzamelen GEEN locatiegegevens',
                            isSecure: true,
                          ),
                          _buildDataItem(
                            Icons.security,
                            'Geen verkoop',
                            'Wij verkopen NOOIT je gegevens aan derden',
                            isSecure: true,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Links to policies
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meer informatie',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          ListTile(
                            leading: const Icon(Icons.description),
                            title: const Text('Privacybeleid'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () {
                              // TODO: Open privacy policy URL
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Privacy policy link coming soon'),
                                ),
                              );
                            },
                            contentPadding: EdgeInsets.zero,
                          ),

                          ListTile(
                            leading: const Icon(Icons.gavel),
                            title: const Text('Algemene Voorwaarden'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () {
                              // TODO: Open terms of service URL
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Terms of service link coming soon'),
                                ),
                              );
                            },
                            contentPadding: EdgeInsets.zero,
                          ),

                          ListTile(
                            leading: const Icon(Icons.cookie),
                            title: const Text('Cookie Beleid'),
                            trailing: const Icon(Icons.open_in_new),
                            onTap: () {
                              // TODO: Open cookie policy URL
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cookie policy link coming soon'),
                                ),
                              );
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // GDPR rights reminder
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
                              Icons.info_outline,
                              size: 20,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Je rechten volgens AVG/GDPR',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Recht op inzage (bekijk je gegevens)\n'
                          '• Recht op gegevensoverdracht (exporteer je gegevens)\n'
                          '• Recht op verwijdering (verwijder je account)\n'
                          '• Recht op correctie (wijzig onjuiste gegevens)\n'
                          '• Recht om bezwaar te maken (tegen verwerking)',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Zie instellingen voor gegevensexport en account verwijdering.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDataItem(IconData icon, String title, String description,
      {bool isSecure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: isSecure ? Colors.green : Colors.grey[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: isSecure ? Colors.green : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
