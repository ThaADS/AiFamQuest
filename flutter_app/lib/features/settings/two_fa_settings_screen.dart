import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/client.dart';

/// Screen for managing 2FA settings
///
/// Allows users to:
/// - Enable 2FA (navigate to setup flow)
/// - View 2FA status
/// - View backup codes
/// - Regenerate backup codes
/// - Disable 2FA (requires password + TOTP verification)
class TwoFASettingsScreen extends StatefulWidget {
  const TwoFASettingsScreen({super.key});

  @override
  State<TwoFASettingsScreen> createState() => _TwoFASettingsScreenState();
}

class _TwoFASettingsScreenState extends State<TwoFASettingsScreen> {
  bool? _is2FAEnabled;
  DateTime? _enabledDate;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load2FAStatus();
  }

  Future<void> _load2FAStatus() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.get2FAStatus();
      setState(() {
        _is2FAEnabled = response['enabled'] ?? false;
        if (response['enabledAt'] != null) {
          _enabledDate = DateTime.parse(response['enabledAt']);
        }
      });
    } catch (e) {
      setState(() => _error = 'Failed to load 2FA status: ${e.toString()}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _enable2FA() async {
    context.push('/2fa/setup').then((_) {
      // Reload status after returning from setup
      _load2FAStatus();
    });
  }

  Future<void> _disable2FA() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _Disable2FADialog(),
    );

    if (result == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ApiClient.instance.disable2FA(
        password: result['password']!,
        code: result['code']!,
      );

      setState(() {
        _is2FAEnabled = false;
        _enabledDate = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Two-Factor Authentication has been disabled'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _error = 'Failed to disable 2FA: ${e.toString()}');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _viewBackupCodes() {
    context.push('/2fa/backup-codes');
  }

  void _regenerateBackupCodes() {
    context.push('/2fa/backup-codes');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
        centerTitle: true,
      ),
      body: _busy && _is2FAEnabled == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _is2FAEnabled == true
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              color: _is2FAEnabled == true
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _is2FAEnabled == true
                                        ? 'Enabled'
                                        : 'Disabled',
                                    style: TextStyle(
                                      color: _is2FAEnabled == true
                                          ? Colors.green
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_is2FAEnabled == true && _enabledDate != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 44),
                            child: Text(
                              'Enabled on ${_formatDate(_enabledDate!)}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Actions based on status
                if (_is2FAEnabled != true) ...[
                  // Enable 2FA
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.add_moderator),
                      title: const Text('Enable Two-Factor Authentication'),
                      subtitle: const Text(
                        'Add an extra layer of security to your account',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _busy ? null : _enable2FA,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info about 2FA
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why enable 2FA?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBenefit(
                            icon: Icons.security,
                            title: 'Enhanced Security',
                            description:
                                'Protects your account even if your password is compromised',
                            theme: theme,
                          ),
                          const SizedBox(height: 8),
                          _buildBenefit(
                            icon: Icons.signal_wifi_off,
                            title: 'Works Offline',
                            description:
                                'TOTP codes are generated on your device',
                            theme: theme,
                          ),
                          const SizedBox(height: 8),
                          _buildBenefit(
                            icon: Icons.backup,
                            title: 'Backup Codes',
                            description:
                                'Emergency access if you lose your phone',
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // 2FA is enabled - show management options
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.vpn_key),
                          title: const Text('View Backup Codes'),
                          subtitle:
                              const Text('Emergency codes for account access'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _busy ? null : _viewBackupCodes,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.refresh),
                          title: const Text('Regenerate Backup Codes'),
                          subtitle: const Text(
                            'Generate new codes (invalidates old ones)',
                          ),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _busy ? null : _regenerateBackupCodes,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.remove_moderator,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            'Disable 2FA',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          subtitle: const Text('Remove 2FA from your account'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: _busy ? null : _disable2FA,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Warning card
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade900),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keep your backup codes safe',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Store your backup codes in a secure location. You\'ll need them to access your account if you lose your authenticator device.',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildBenefit({
    required IconData icon,
    required String title,
    required String description,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onPrimaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Dialog for disabling 2FA
///
/// Requires user to enter password and current TOTP code for verification
class _Disable2FADialog extends StatefulWidget {
  @override
  State<_Disable2FADialog> createState() => _Disable2FADialogState();
}

class _Disable2FADialogState extends State<_Disable2FADialog> {
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_passwordController.text.isEmpty || _codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'password': _passwordController.text,
      'code': _codeController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Disable Two-Factor Authentication?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your account will be less secure without 2FA',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'To disable 2FA, please confirm your identity:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: '2FA Code',
                hintText: '6-digit code',
                prefixIcon: Icon(Icons.pin),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Disable 2FA'),
        ),
      ],
    );
  }
}
