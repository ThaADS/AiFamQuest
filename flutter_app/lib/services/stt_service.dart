import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/app_logger.dart';

/// Speech-to-Text service using Web Speech API (free, browser-based)
/// Fallback to device STT if Web Speech API is unavailable
class STTService {
  static final STTService instance = STTService._();
  STTService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _initialized = await _speech.initialize(
        onError: (error) => AppLogger.debug('STT Error: ${error.errorMsg}'),
        onStatus: (status) => AppLogger.debug('STT Status: $status'),
      );
      return _initialized;
    } catch (e) {
      AppLogger.debug('STT initialization failed: $e');
      return false;
    }
  }

  /// Check if speech recognition is available
  Future<bool> isAvailable() async {
    if (!_initialized) {
      await initialize();
    }
    return _initialized;
  }

  /// Listen for speech and return transcribed text
  ///
  /// [locale] - Language code (nl-NL, en-US, de-DE, fr-FR)
  /// [onPartial] - Callback for partial results (real-time transcription)
  /// Returns the final transcribed text or null if no speech detected
  Future<String?> listen({
    required String locale,
    Function(String)? onPartial,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!await isAvailable()) {
      throw Exception('Speech recognition not available');
    }

    String? finalResult;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          finalResult = result.recognizedWords;
        } else if (onPartial != null) {
          onPartial(result.recognizedWords);
        }
      },
      localeId: locale,
      listenFor: timeout,
      pauseFor: const Duration(seconds: 5),
      cancelOnError: true,
    );

    // Wait for final result
    await Future.delayed(timeout);

    return finalResult;
  }

  /// Stop listening
  Future<void> stop() async {
    await _speech.stop();
  }

  /// Cancel listening
  Future<void> cancel() async {
    await _speech.cancel();
  }

  /// Check if currently listening
  bool get isListening => _speech.isListening;

  /// Get available locales
  Future<List<String>> getAvailableLocales() async {
    if (!await isAvailable()) return [];

    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  /// Check if specific locale is supported
  Future<bool> isLocaleSupported(String locale) async {
    final availableLocales = await getAvailableLocales();
    return availableLocales.contains(locale);
  }
}
