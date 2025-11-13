import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/client.dart';
import '../../widgets/pin_input_widget.dart';

/// Screen for verifying 2FA code during login
///
/// Shown when a user with 2FA enabled attempts to log in.
/// Allows verification via TOTP code or backup code.
class TwoFAVerifyScreen extends StatefulWidget {
  final Map<String, dynamic> loginData;

  const TwoFAVerifyScreen({
    super.key,
    required this.loginData,
  });

  @override
  State<TwoFAVerifyScreen> createState() => _TwoFAVerifyScreenState();
}

class _TwoFAVerifyScreenState extends State<TwoFAVerifyScreen> {
  final _codeController = TextEditingController();
  final _backupCodeController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _showBackupCodeInput = false;
  int _attemptsRemaining = 5;

  @override
  void dispose() {
    _codeController.dispose();
    _backupCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _showBackupCodeInput
        ? _backupCodeController.text
        : _codeController.text;

    if (code.isEmpty) {
      setState(() => _error = 'Please enter a code');
      return;
    }

    if (!_showBackupCodeInput && code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.verify2FA(
        email: widget.loginData['email'],
        password: widget.loginData['password'],
        code: code,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _attemptsRemaining--;
        if (_attemptsRemaining <= 0) {
          _error = 'Too many attempts. Please try again in 15 minutes.';
        } else {
          _error = 'Invalid code. $_attemptsRemaining attempts remaining.';
        }
      });

      // Clear the input
      if (_showBackupCodeInput) {
        _backupCodeController.clear();
      } else {
        _codeController.clear();
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lock icon
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Two-Factor Authentication',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                _showBackupCodeInput
                    ? 'Enter one of your backup codes'
                    : 'Enter the 6-digit code from your authenticator app',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),

              // Code input
              if (!_showBackupCodeInput)
                PinInputWidget(
                  controller: _codeController,
                  onCompleted: (_) => _verifyCode(),
                  hasError: _error != null,
                )
              else
                TextField(
                  controller: _backupCodeController,
                  decoration: InputDecoration(
                    labelText: 'Backup Code',
                    hintText: 'ABCD1234',
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verifyCode(),
                  textCapitalization: TextCapitalization.characters,
                ),

              const SizedBox(height: 24),

              // Verify button
              FilledButton(
                onPressed: _busy || _attemptsRemaining <= 0
                    ? null
                    : _verifyCode,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify', style: TextStyle(fontSize: 16)),
              ),

              // Error message
              if (_error != null && !_showBackupCodeInput) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Toggle backup code input
              TextButton(
                onPressed: _attemptsRemaining <= 0
                    ? null
                    : () {
                        setState(() {
                          _showBackupCodeInput = !_showBackupCodeInput;
                          _error = null;
                        });
                      },
                child: Text(
                  _showBackupCodeInput
                      ? 'Use authenticator app'
                      : 'Use backup code',
                ),
              ),

              // Help text
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Having trouble?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If you\'ve lost access to your authenticator app, use one of your backup codes. Each backup code can only be used once.',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
