/// PIN exit dialog for kiosk mode
///
/// Requires 4-digit PIN to exit kiosk mode and return to normal app.
/// Prevents accidental exits from shared family displays.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:go_router/go_router.dart';
import '../features/kiosk/kiosk_provider.dart';

class PinExitDialog extends ConsumerStatefulWidget {
  const PinExitDialog({super.key});

  @override
  ConsumerState<PinExitDialog> createState() => _PinExitDialogState();
}

class _PinExitDialogState extends ConsumerState<PinExitDialog> {
  final _pinController = TextEditingController();
  bool _isIncorrect = false;
  bool _isVerifying = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Verify PIN with backend
  Future<void> _verifyPin(String pin) async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _isIncorrect = false;
    });

    try {
      final notifier = ref.read(kioskPinProvider.notifier);
      final isValid = await notifier.verifyPin(pin);

      if (!mounted) return;

      if (isValid) {
        // PIN correct - exit kiosk mode
        Navigator.pop(context);
        context.go('/home');
      } else {
        // PIN incorrect - clear and show error
        setState(() {
          _isIncorrect = true;
          _isVerifying = false;
        });
        _pinController.clear();

        // Auto-clear error after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isIncorrect = false;
            });
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isIncorrect = true;
        _isVerifying = false;
      });
      _pinController.clear();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying PIN: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.lock_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text('Exit Kiosk Mode'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter 4-digit PIN to exit kiosk mode',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // PIN input
            PinCodeTextField(
              appContext: context,
              length: 4,
              controller: _pinController,
              onCompleted: _verifyPin,
              keyboardType: TextInputType.number,
              enabled: !_isVerifying,
              autoFocus: true,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 60,
                fieldWidth: 50,
                borderWidth: 2,
                activeFillColor: theme.colorScheme.surface,
                selectedFillColor: _isIncorrect
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
                inactiveFillColor: theme.colorScheme.surface,
                activeColor: theme.colorScheme.primary,
                selectedColor: _isIncorrect
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.outline,
                errorBorderColor: theme.colorScheme.error,
              ),
              enableActiveFill: true,
              animationType: AnimationType.fade,
              animationDuration: const Duration(milliseconds: 200),
            ),

            // Error message
            if (_isIncorrect)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Incorrect PIN',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Verifying indicator
            if (_isVerifying)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Verifying...',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
