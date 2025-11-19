import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';

/// Account Deletion Screen
///
/// Features:
/// - Warning message about data loss
/// - Confirmation checklist (3 items required)
/// - Password verification for security
/// - Final delete button (red, disabled until all checks)
/// - Success screen with automatic logout
/// - GDPR "Right to be Forgotten" compliance
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isDeleting = false;

  // Confirmation checklist
  bool _understandDataLoss = false;
  bool _understandNoUndo = false;
  bool _exportedDataIfNeeded = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canProceed =>
      _understandDataLoss &&
      _understandNoUndo &&
      _exportedDataIfNeeded &&
      _passwordController.text.isNotEmpty;

  Future<void> _deleteAccount() async {
    if (!_canProceed) return;

    // Final confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Laatste waarschuwing'),
          ],
        ),
        content: const Text(
          'Je staat op het punt je account permanent te verwijderen.\n\n'
          'Dit betekent:\n'
          '• Alle je gegevens worden verwijderd\n'
          '• Je verliest toegang tot FamQuest\n'
          '• Deze actie kan NIET ongedaan gemaakt worden\n\n'
          'Weet je het zeker?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ja, verwijder mijn account'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw Exception('Geen gebruiker gevonden');
      }

      // Step 1: Verify password by re-authenticating
      try {
        await supabase.auth.signInWithPassword(
          email: user.email!,
          password: _passwordController.text,
        );
      } on AuthException catch (e) {
        throw Exception(
          e.message == 'Invalid login credentials'
              ? 'Wachtwoord is onjuist'
              : e.message,
        );
      }

      // Step 2: Call backend API to delete account
      // Backend will handle:
      // - Delete all user data (tasks, events, points, badges, study items)
      // - Remove from family (if applicable)
      // - Delete user record
      // - Delete auth account
      final response = await supabase.functions.invoke(
        'delete-account',
        body: {
          'password': _passwordController.text,
        },
      );

      if (response.status != 200) {
        throw Exception('Account verwijdering mislukt: ${response.data}');
      }

      // Step 3: Sign out
      await supabase.auth.signOut();

      if (mounted) {
        // Show success screen
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const _AccountDeletedSuccessScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij verwijderen account: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
        title: const Text('Account Verwijderen'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning icon and message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 64,
                    color: Colors.red[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dit is een permanente actie',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Alle gegevens die aan je account gekoppeld zijn worden permanent verwijderd. '
                    'Dit omvat taken, evenementen, punten, badges, studieplanning en alle persoonlijke instellingen.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Confirmation checklist
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bevestiging vereist',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vink alle vakjes aan om te bevestigen dat je begrijpt wat er gebeurt:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Checkbox 1
                    CheckboxListTile(
                      value: _understandDataLoss,
                      onChanged: (value) =>
                          setState(() => _understandDataLoss = value ?? false),
                      title: const Text(
                        'Ik begrijp dat al mijn gegevens verwijderd worden',
                        style: TextStyle(fontSize: 15),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.red,
                    ),

                    // Checkbox 2
                    CheckboxListTile(
                      value: _understandNoUndo,
                      onChanged: (value) =>
                          setState(() => _understandNoUndo = value ?? false),
                      title: const Text(
                        'Ik begrijp dat deze actie niet ongedaan gemaakt kan worden',
                        style: TextStyle(fontSize: 15),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.red,
                    ),

                    // Checkbox 3
                    CheckboxListTile(
                      value: _exportedDataIfNeeded,
                      onChanged: (value) => setState(
                          () => _exportedDataIfNeeded = value ?? false),
                      title: const Text(
                        'Ik heb mijn gegevens geëxporteerd indien nodig',
                        style: TextStyle(fontSize: 15),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Password verification
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wachtwoord verificatie',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Voer je wachtwoord in om je identiteit te bevestigen:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      enabled: !_isDeleting,
                      decoration: InputDecoration(
                        labelText: 'Wachtwoord',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Delete button
            FilledButton.icon(
              onPressed: (_canProceed && !_isDeleting) ? _deleteAccount : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(
                _isDeleting ? 'Account verwijderen...' : 'Account Verwijderen',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            // Cancel button
            OutlinedButton(
              onPressed: _isDeleting ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Annuleren'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Success screen shown after account deletion
class _AccountDeletedSuccessScreen extends StatelessWidget {
  const _AccountDeletedSuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Account verwijderd',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Je account en alle bijbehorende gegevens zijn succesvol verwijderd.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  // Navigate to login screen (root)
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                child: const Text('Terug naar login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
