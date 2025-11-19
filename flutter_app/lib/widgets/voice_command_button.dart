import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../screens/voice_command_screen.dart';

/// Floating voice command button
/// Triggers full-screen voice interface when pressed
class VoiceCommandButton extends StatefulWidget {
  final String locale;
  final List<String>? userNames;
  final Function(VoiceCommandResult)? onResult;

  const VoiceCommandButton({
    super.key,
    this.locale = 'nl-NL',
    this.userNames,
    this.onResult,
  });

  @override
  State<VoiceCommandButton> createState() => _VoiceCommandButtonState();
}

class _VoiceCommandButtonState extends State<VoiceCommandButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Pulsing animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openVoiceInterface() async {
    // Navigate to full-screen voice command interface
    final result = await Navigator.push<VoiceCommandResult>(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCommandScreen(
          locale: widget.locale,
          userNames: widget.userNames,
        ),
      ),
    );

    if (result != null && widget.onResult != null) {
      widget.onResult!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FloatingActionButton.large(
        onPressed: _openVoiceInterface,
        backgroundColor: Colors.deepPurple,
        child: const Icon(
          Icons.mic,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }
}
