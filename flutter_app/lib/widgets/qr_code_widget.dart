import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Widget for displaying QR codes for 2FA setup
///
/// Renders a QR code with proper styling and error handling.
/// Used in TwoFASetupScreen to display TOTP authentication QR codes.
class QRCodeWidget extends StatelessWidget {
  /// The data to encode in the QR code (typically otpauth:// URL)
  final String data;

  /// Size of the QR code in logical pixels
  final double size;

  /// Background color of the QR code
  final Color backgroundColor;

  /// Foreground color of the QR code
  final Color foregroundColor;

  const QRCodeWidget({
    super.key,
    required this.data,
    this.size = 250.0,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: backgroundColor,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: foregroundColor,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: foregroundColor,
        ),
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}
