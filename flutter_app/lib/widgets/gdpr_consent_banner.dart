import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/client.dart';
import '../core/app_logger.dart';

/// GDPR Consent Banner
///
/// Shows on first app launch to collect user consent for:
/// - Analytics tracking
/// - Marketing communications
///
/// Complies with GDPR Article 6 (lawful basis for processing)
/// and Article 7 (conditions for consent).
class GdprConsentBanner extends StatefulWidget {
  final VoidCallback onConsent;

  const GdprConsentBanner({
    super.key,
    required this.onConsent,
  });

  @override
  State<GdprConsentBanner> createState() => _GdprConsentBannerState();

  /// Check if consent has already been given
  static Future<bool> hasConsent() async {
    const storage = FlutterSecureStorage();
    final consent = await storage.read(key: 'gdpr_consent_given');
    return consent == 'true';
  }

  /// Mark consent as given
  static Future<void> markConsentGiven() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'gdpr_consent_given', value: 'true');
  }
}

class _GdprConsentBannerState extends State<GdprConsentBanner> {
  bool _analyticsConsent = true; // Default to true (opt-out available)
  bool _marketingConsent = false; // Default to false (opt-in)
  bool _isSaving = false;

  Future<void> _acceptAll() async {
    setState(() {
      _analyticsConsent = true;
      _marketingConsent = true;
    });
    await _saveConsent();
  }

  Future<void> _acceptNecessary() async {
    setState(() {
      _analyticsConsent = false;
      _marketingConsent = false;
    });
    await _saveConsent();
  }

  Future<void> _saveConsent() async {
    setState(() => _isSaving = true);

    try {
      // Save to backend
      await ApiClient.instance.setGdprConsent(
        analyticsConsent: _analyticsConsent,
        marketingConsent: _marketingConsent,
      );

      // Save locally
      const storage = FlutterSecureStorage();
      await storage.write(
        key: 'gdpr_analytics_consent',
        value: _analyticsConsent.toString(),
      );
      await storage.write(
        key: 'gdpr_marketing_consent',
        value: _marketingConsent.toString(),
      );
      await GdprConsentBanner.markConsentGiven();

      if (mounted) {
        widget.onConsent();
      }
    } catch (e) {
      AppLogger.debug('[GDPR] Error saving consent: $e');
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.cookie,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cookies & Privacy',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              const Text(
                'Wij gebruiken cookies om je ervaring te verbeteren en de app te '
                'optimaliseren. Je kunt je keuzes op elk moment wijzigen in de '
                'privacy-instellingen.',
                style: TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 16),

              // Consent options (expandable)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Instellingen aanpassen',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                children: [
                  CheckboxListTile(
                    value: _analyticsConsent,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _analyticsConsent = value ?? false),
                    title: const Text(
                      'Analytics & Prestaties',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Help ons de app te verbeteren met anonieme gebruiksgegevens',
                      style: TextStyle(fontSize: 12),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  CheckboxListTile(
                    value: _marketingConsent,
                    onChanged: _isSaving
                        ? null
                        : (value) => setState(() => _marketingConsent = value ?? false),
                    title: const Text(
                      'Marketing',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Ontvang updates over nieuwe functies en aanbiedingen',
                      style: TextStyle(fontSize: 12),
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Buttons
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _acceptNecessary,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Alleen noodzakelijk'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _acceptAll,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Alles accepteren'),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              // Privacy policy link
              TextButton(
                onPressed: () {
                  // TODO: Navigate to privacy settings or policy
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Privacy policy coming soon'),
                    ),
                  );
                },
                child: const Text(
                  'Lees meer in ons privacybeleid',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
