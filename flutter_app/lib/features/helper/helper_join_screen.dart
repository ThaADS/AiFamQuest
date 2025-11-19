import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../api/client.dart';
import '../../models/helper_models.dart';

/// Helper Join Screen - For helpers to join using invite code
///
/// Features:
/// - 6-digit PIN code entry
/// - Family info preview after valid code
/// - Accept/decline invite actions
class HelperJoinScreen extends ConsumerStatefulWidget {
  const HelperJoinScreen({super.key});

  @override
  ConsumerState<HelperJoinScreen> createState() => _HelperJoinScreenState();
}

class _HelperJoinScreenState extends ConsumerState<HelperJoinScreen> {
  final _pinController = TextEditingController();
  HelperInvite? _invite;
  bool _isVerifying = false;
  bool _isAccepting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Family'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration or icon
            Icon(
              Icons.family_restroom,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 24),
            // Instructions
            Text(
              'Enter Invite Code',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Enter the 6-digit code provided by the family:',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // QR Scanner button
            OutlinedButton.icon(
              onPressed: _isVerifying || _invite != null ? null : _openQRScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: theme.colorScheme.outline)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.colorScheme.outline)),
              ],
            ),
            const SizedBox(height: 16),
            // PIN code field
            PinCodeTextField(
              length: 6,
              controller: _pinController,
              appContext: context,
              onCompleted: _verifyCode,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 56,
                fieldWidth: 48,
                activeFillColor: theme.colorScheme.surface,
                selectedFillColor: theme.colorScheme.primaryContainer,
                inactiveFillColor: theme.colorScheme.surface,
                activeColor: theme.colorScheme.primary,
                selectedColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.outline,
                errorBorderColor: theme.colorScheme.error,
              ),
              cursorColor: theme.colorScheme.primary,
              animationType: AnimationType.fade,
              animationDuration: const Duration(milliseconds: 200),
              enableActiveFill: true,
              keyboardType: TextInputType.number,
              enabled: !_isVerifying && _invite == null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
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
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isVerifying) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Text(
                'Verifying code...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // Invite preview (shown after successful verification)
            if (_invite != null && !_isVerifying) ...[
              const SizedBox(height: 32),
              _buildInvitePreview(theme, _invite!),
              const SizedBox(height: 24),
              // Accept/Decline buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isAccepting ? null : _declineInvite,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isAccepting ? null : _acceptInvite,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build invite preview card
  Widget _buildInvitePreview(ThemeData theme, HelperInvite invite) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valid Invite Code',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Code verified successfully',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow(
              theme,
              icon: Icons.home,
              label: 'Family',
              value: invite.familyName,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              icon: Icons.person,
              label: 'Invited by',
              value: invite.inviterName,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              theme,
              icon: Icons.calendar_today,
              label: 'Access duration',
              value:
                  '${DateFormat('MMM d').format(invite.startDate)} - ${DateFormat('MMM d, yyyy').format(invite.endDate)}',
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Permissions Granted',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              theme,
              invite.permissions.canViewAssignedTasks,
              'View assigned tasks',
            ),
            _buildPermissionItem(
              theme,
              invite.permissions.canCompleteTasks,
              'Complete tasks',
            ),
            _buildPermissionItem(
              theme,
              invite.permissions.canUploadPhotos,
              'Upload photos',
            ),
            _buildPermissionItem(
              theme,
              invite.permissions.canViewPoints,
              'View points',
            ),
          ],
        ),
      ),
    );
  }

  /// Build info row
  Widget _buildInfoRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build permission item
  Widget _buildPermissionItem(ThemeData theme, bool granted, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: granted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: granted
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
                decoration: granted ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Verify helper code
  Future<void> _verifyCode(String code) async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.instance.verifyHelperCode(code);
      final invite = HelperInvite.fromJson(response);

      if (!mounted) return;

      // Check if invite is expired
      if (invite.isExpired) {
        setState(() {
          _errorMessage = 'This invite code has expired';
          _isVerifying = false;
          _pinController.clear();
        });
        return;
      }

      setState(() {
        _invite = invite;
        _isVerifying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Invalid code. Please check and try again.';
        _isVerifying = false;
        _pinController.clear();
      });
    }
  }

  /// Accept helper invite
  Future<void> _acceptInvite() async {
    if (_invite == null) return;

    setState(() => _isAccepting = true);

    try {
      await ApiClient.instance.acceptHelperInvite(_invite!.code);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined family!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to helper home screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept invite: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  /// Decline helper invite
  void _declineInvite() {
    Navigator.pop(context);
  }

  /// Open QR code scanner
  Future<void> _openQRScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      _pinController.text = result;
      _verifyCode(result);
    }
  }
}

/// QR Code Scanner Screen
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && code.length == 6) {
                  _processCode(code);
                  break;
                }
              }
            },
          ),
          // Overlay with instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Point camera at QR code',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The code will be scanned automatically',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _processCode(String code) {
    setState(() => _isProcessing = true);

    // Return the scanned code
    Navigator.pop(context, code);
  }
}
