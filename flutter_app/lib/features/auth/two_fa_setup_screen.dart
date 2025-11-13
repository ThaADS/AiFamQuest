import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api/client.dart';
import '../../widgets/qr_code_widget.dart';
import '../../widgets/pin_input_widget.dart';

/// Screen for setting up Two-Factor Authentication
///
/// Multi-step wizard that guides users through:
/// 1. Introduction explaining benefits
/// 2. QR code display for authenticator app
/// 3. Code verification to confirm setup
/// 4. Backup codes display and download
class TwoFASetupScreen extends StatefulWidget {
  const TwoFASetupScreen({super.key});

  @override
  State<TwoFASetupScreen> createState() => _TwoFASetupScreenState();
}

class _TwoFASetupScreenState extends State<TwoFASetupScreen> {
  int _currentStep = 0;
  bool _busy = false;
  String? _error;

  // Step 2 data
  String? _secret;
  String? _otpauthUrl;
  String? _qrCodeUrl;

  // Step 3 data
  final _verificationCodeController = TextEditingController();

  // Step 4 data
  List<String>? _backupCodes;
  bool _hasAcceptedBackupCodes = false;

  @override
  void initState() {
    super.initState();
    // Automatically load QR code for step 2
    _initiate2FASetup();
  }

  @override
  void dispose() {
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _initiate2FASetup() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.setup2FA();
      setState(() {
        _secret = response['secret'];
        _otpauthUrl = response['otpauth_url'];
        _qrCodeUrl = response['qr_code_url'];
      });
    } catch (e) {
      setState(() => _error = 'Failed to initiate 2FA setup: ${e.toString()}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _verifySetup() async {
    if (_verificationCodeController.text.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.verify2FASetup(
        secret: _secret!,
        code: _verificationCodeController.text,
      );

      if (response['success'] == true) {
        setState(() {
          _backupCodes = List<String>.from(response['backup_codes']);
          _currentStep = 3; // Move to backup codes step
        });
      }
    } catch (e) {
      setState(() => _error = 'Invalid code. Please try again.');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _completeSetup() async {
    if (!_hasAcceptedBackupCodes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm you have saved your backup codes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    context.go('/home');
  }

  void _copyBackupCodes() {
    if (_backupCodes == null) return;

    final codesText = _backupCodes!.join('\n');
    Clipboard.setData(ClipboardData(text: codesText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup codes copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up 2FA'),
        centerTitle: true,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _currentStep > 0 ? () {
          setState(() => _currentStep--);
        } : null,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : details.onStepContinue,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_currentStep == 3 ? 'Complete Setup' : 'Continue'),
                ),
                if (details.onStepCancel != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // Step 1: Introduction
          Step(
            title: const Text('Introduction'),
            content: _buildIntroStep(theme),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),

          // Step 2: QR Code
          Step(
            title: const Text('Scan QR Code'),
            content: _buildQRCodeStep(theme),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),

          // Step 3: Verify Code
          Step(
            title: const Text('Verify Code'),
            content: _buildVerifyStep(theme),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),

          // Step 4: Backup Codes
          Step(
            title: const Text('Backup Codes'),
            content: _buildBackupCodesStep(theme),
            isActive: _currentStep >= 3,
            state: StepState.indexed,
          ),
        ],
      ),
    );
  }

  Widget _buildIntroStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Two-Factor Authentication',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Protect your account with an extra layer of security. When enabled, you\'ll need both your password and a code from your phone to log in.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _buildFeatureItem(
          icon: Icons.security,
          title: 'More Secure',
          description: 'Adds an extra layer of protection',
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.signal_wifi_off,
          title: 'Works Offline',
          description: 'Codes are generated on your device',
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          icon: Icons.backup,
          title: 'Backup Codes Included',
          description: 'Emergency access if you lose your phone',
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQRCodeStep(ThemeData theme) {
    if (_busy || _qrCodeUrl == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Scan this code with your authenticator app',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // QR Code
        Center(
          child: QRCodeWidget(
            data: _otpauthUrl!,
            size: 250,
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Supported apps:',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: const Text('Google Authenticator')),
            Chip(label: const Text('Authy')),
            Chip(label: const Text('1Password')),
          ],
        ),

        const SizedBox(height: 24),
        ExpansionTile(
          title: const Text('Can\'t scan? Enter manually'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Secret Key:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _secret ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _secret ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Secret copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Secret'),
                  ),
                ],
              ),
            ),
          ],
        ),

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
    );
  }

  Widget _buildVerifyStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Enter the 6-digit code from your authenticator app',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        PinInputWidget(
          controller: _verificationCodeController,
          onCompleted: (_) => _verifySetup(),
          hasError: _error != null,
        ),

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
    );
  }

  Widget _buildBackupCodesStep(ThemeData theme) {
    if (_backupCodes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade900),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Save these backup codes in a secure location. You\'ll need them to access your account if you lose your phone.',
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Backup codes grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _backupCodes!.length,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: SelectableText(
                  _backupCodes![index],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _copyBackupCodes,
                icon: const Icon(Icons.copy),
                label: const Text('Copy All'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement download as TXT file
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Confirmation checkbox
        CheckboxListTile(
          value: _hasAcceptedBackupCodes,
          onChanged: (value) {
            setState(() => _hasAcceptedBackupCodes = value ?? false);
          },
          title: const Text('I have saved my backup codes'),
          subtitle: const Text('Required to complete setup'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  void _onStepContinue() {
    switch (_currentStep) {
      case 0:
        // Move to QR code step
        setState(() => _currentStep = 1);
        break;
      case 1:
        // Move to verification step
        setState(() => _currentStep = 2);
        break;
      case 2:
        // Verify the code
        _verifySetup();
        break;
      case 3:
        // Complete setup
        _completeSetup();
        break;
    }
  }
}
