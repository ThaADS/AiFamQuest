import 'package:flutter_tts/flutter_tts.dart';
import '../core/app_logger.dart';

/// Text-to-Speech service using platform TTS engines
/// Primary: Web Speech API (browser)
/// Fallback: Native device TTS (iOS/Android)
class TTSService {
  static final TTSService instance = TTSService._();
  TTSService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  /// Initialize TTS
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Configure TTS
      await _tts.setLanguage('nl-NL');
      await _tts.setSpeechRate(0.5); // Normal speed
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Set iOS-specific settings
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      _initialized = true;
    } catch (e) {
      AppLogger.debug('TTS initialization failed: $e');
    }
  }

  /// Speak the given text
  ///
  /// [text] - Text to speak
  /// [locale] - Language code (nl-NL, en-US, de-DE, fr-FR)
  /// [rate] - Speech rate (0.0 - 1.0, default 0.5)
  /// [pitch] - Voice pitch (0.5 - 2.0, default 1.0)
  Future<void> speak(
    String text, {
    String? locale,
    double? rate,
    double? pitch,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Set language if provided
      if (locale != null) {
        await _tts.setLanguage(locale);
      }

      // Set rate if provided
      if (rate != null) {
        await _tts.setSpeechRate(rate);
      }

      // Set pitch if provided
      if (pitch != null) {
        await _tts.setPitch(pitch);
      }

      // Speak
      await _tts.speak(text);
    } catch (e) {
      AppLogger.debug('TTS speak failed: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Pause speaking
  Future<void> pause() async {
    await _tts.pause();
  }

  /// Get available voices for a locale
  Future<List<String>> getVoices(String locale) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        return voices
            .where((v) => v['locale'] == locale)
            .map((v) => v['name'] as String)
            .toList();
      }
    } catch (e) {
      AppLogger.debug('Get voices failed: $e');
    }

    return [];
  }

  /// Check if TTS is speaking
  Future<bool> get isSpeaking async {
    return await _tts.awaitSpeakCompletion(true) == 0;
  }

  /// Set completion callback
  void setCompletionHandler(Function callback) {
    _tts.setCompletionHandler(() {
      callback();
    });
  }

  /// Set error callback
  void setErrorHandler(Function(dynamic) callback) {
    _tts.setErrorHandler((msg) {
      callback(msg);
    });
  }
}
