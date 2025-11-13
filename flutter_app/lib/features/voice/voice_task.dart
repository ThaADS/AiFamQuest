import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../api/client.dart';

class VoiceTaskScreen extends StatefulWidget {
  const VoiceTaskScreen({super.key});
  @override
  State<VoiceTaskScreen> createState() => _VoiceTaskScreenState();
}

class _VoiceTaskScreenState extends State<VoiceTaskScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _available = await _speech.initialize();
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spreek taak in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_text.isEmpty ? 'Druk op opnemen en spreek je taak in…' : _text),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: !_available ? null : () async {
                if (!_speech.isListening) {
                  await _speech.listen(onResult: (r){ setState(()=>_text = r.recognizedWords); });
                } else {
                  await _speech.stop();
                }
              },
              icon: Icon(_speech.isListening ? Icons.stop : Icons.mic),
              label: Text(_speech.isListening ? 'Stop' : 'Opnemen')
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _text.isEmpty ? null : () async {
                await ApiClient.instance.createTask({'title': _text, 'assignees': [], 'points': 10});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Maak taak van spraak')
            )
          ],
        ),
      ),
    );
  }
}
