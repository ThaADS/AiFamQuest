import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/voice_service.dart';

/// Full-screen voice command interface
/// Shows listening animation, transcription, intent parsing, and response
class VoiceCommandScreen extends StatefulWidget {
  final String locale;
  final List<String>? userNames;

  const VoiceCommandScreen({
    super.key,
    this.locale = 'nl-NL',
    this.userNames,
  });

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with TickerProviderStateMixin {
  final _voiceService = VoiceService.instance;

  // State
  VoiceCommandState _state = VoiceCommandState.idle;
  String _transcript = '';
  Map<String, dynamic>? _intent;
  VoiceCommandResult? _result;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize voice service
    _voiceService.initialize(locale: widget.locale);

    // Pulse animation for microphone
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wave animation for listening
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Auto-start listening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _state = VoiceCommandState.listening;
      _transcript = '';
      _intent = null;
      _result = null;
    });

    try {
      final result = await _voiceService.processVoiceCommand(
        userNames: widget.userNames,
        onListening: () {
          setState(() => _state = VoiceCommandState.listening);
        },
        onTranscript: (transcript) {
          setState(() => _transcript = transcript);
        },
        onIntent: (intent) {
          setState(() {
            _state = VoiceCommandState.processing;
            _intent = intent;
          });
        },
      );

      setState(() {
        _state = VoiceCommandState.complete;
        _result = result;
      });

      // Auto-close after 3 seconds on success
      if (result.success) {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.pop(context, result);
        }
      }
    } catch (e) {
      setState(() {
        _state = VoiceCommandState.error;
        _result = VoiceCommandResult(
          success: false,
          message: 'Error: $e',
          intent: 'error',
        );
      });
    }
  }

  void _retry() {
    _startListening();
  }

  void _cancel() {
    _voiceService.stop();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Stack(
          children: [
            // Background waves (listening state)
            if (_state == VoiceCommandState.listening) _buildWaveBackground(),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Microphone icon with animation
                  _buildMicrophone(),

                  const SizedBox(height: 48),

                  // State text
                  _buildStateText(),

                  const SizedBox(height: 24),

                  // Transcript
                  if (_transcript.isNotEmpty) _buildTranscript(),

                  const SizedBox(height: 24),

                  // Intent
                  if (_intent != null) _buildIntent(),

                  const SizedBox(height: 24),

                  // Result
                  if (_result != null) _buildResult(),

                  const SizedBox(height: 48),

                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),

            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: _cancel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveBackground() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: WavePainter(
            animationValue: _waveController.value,
          ),
        );
      },
    );
  }

  Widget _buildMicrophone() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getMicrophoneColor(),
          boxShadow: [
            BoxShadow(
              color: _getMicrophoneColor().withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Icon(
          _getMicrophoneIcon(),
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getMicrophoneColor() {
    switch (_state) {
      case VoiceCommandState.idle:
        return Colors.grey;
      case VoiceCommandState.listening:
        return Colors.deepPurple;
      case VoiceCommandState.processing:
        return Colors.blue;
      case VoiceCommandState.complete:
        return _result?.success == true ? Colors.green : Colors.red;
      case VoiceCommandState.error:
        return Colors.red;
    }
  }

  IconData _getMicrophoneIcon() {
    switch (_state) {
      case VoiceCommandState.idle:
      case VoiceCommandState.listening:
        return Icons.mic;
      case VoiceCommandState.processing:
        return Icons.psychology;
      case VoiceCommandState.complete:
        return _result?.success == true ? Icons.check_circle : Icons.error;
      case VoiceCommandState.error:
        return Icons.error;
    }
  }

  Widget _buildStateText() {
    final text = _getStateText();
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  String _getStateText() {
    switch (_state) {
      case VoiceCommandState.idle:
        return 'Tap to speak';
      case VoiceCommandState.listening:
        return 'Listening...';
      case VoiceCommandState.processing:
        return 'Processing...';
      case VoiceCommandState.complete:
        return _result?.success == true ? 'Success!' : 'Failed';
      case VoiceCommandState.error:
        return 'Error';
    }
  }

  Widget _buildTranscript() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'You said:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _transcript,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIntent() {
    final intent = _intent!['intent'] as String;
    final confidence = _intent!['confidence'] as double;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            'Intent:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            intent.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final success = _result!.success;
    final message = _result!.message;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: success
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.red.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_state == VoiceCommandState.listening ||
        _state == VoiceCommandState.processing) {
      return ElevatedButton(
        onPressed: _cancel,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        child: const Text(
          'Cancel',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    if (_state == VoiceCommandState.complete ||
        _state == VoiceCommandState.error) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _cancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

/// Voice command processing states
enum VoiceCommandState {
  idle,
  listening,
  processing,
  complete,
  error,
}

/// Wave painter for listening animation
class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centerY = size.height / 2;
    const waveCount = 3;

    for (int i = 0; i < waveCount; i++) {
      final path = Path();
      final amplitude = 30.0 + (i * 20);
      final frequency = 0.02 + (i * 0.005);
      final phase = animationValue * 2 * math.pi + (i * math.pi / 3);

      path.moveTo(0, centerY);

      for (double x = 0; x <= size.width; x += 5) {
        final y = centerY + amplitude * math.sin(frequency * x + phase);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
