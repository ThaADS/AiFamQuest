import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Widget for PIN/OTP code input
///
/// Provides a consistent UI for entering 2FA codes with proper validation
/// and Material 3 styling. Used in TwoFASetupScreen and TwoFAVerifyScreen.
class PinInputWidget extends StatelessWidget {
  /// Callback when user completes entering the PIN
  final Function(String) onCompleted;

  /// Callback for each character change (optional)
  final Function(String)? onChanged;

  /// Length of the PIN (default: 6 for TOTP codes)
  final int length;

  /// Controller for the text field
  final TextEditingController? controller;

  /// Whether to show an error state
  final bool hasError;

  const PinInputWidget({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.controller,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PinCodeTextField(
      appContext: context,
      length: length,
      controller: controller,
      onCompleted: onCompleted,
      onChanged: onChanged ?? (_) {},
      keyboardType: TextInputType.number,
      autoDisposeControllers: false,
      animationType: AnimationType.fade,
      animationDuration: const Duration(milliseconds: 300),
      enableActiveFill: true,
      errorAnimationController: null,
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(12),
        fieldHeight: 60,
        fieldWidth: 50,
        activeFillColor: theme.colorScheme.surface,
        inactiveFillColor: theme.colorScheme.surface,
        selectedFillColor: theme.colorScheme.primaryContainer,
        activeColor: theme.colorScheme.primary,
        inactiveColor: theme.colorScheme.outline,
        selectedColor: theme.colorScheme.primary,
        errorBorderColor: theme.colorScheme.error,
        borderWidth: 2,
      ),
      cursorColor: theme.colorScheme.primary,
      textStyle: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: Colors.transparent,
      autoFocus: true,
    );
  }
}
