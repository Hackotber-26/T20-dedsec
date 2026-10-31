import 'package:flutter_tts/flutter_tts.dart';

import 'service/detection_service.dart';

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  static const Map<String, String> _locales = {
    'English': 'en-IN',
    'Hindi': 'hi-IN',
    'Kannada': 'kn-IN',
  };

  Future<void> initialize() async {
    if (_initialized) return;

    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((message) {
      _isSpeaking = false;
    });

    _initialized = true;
  }

  Future<void> speakResult(
    RiskResult result, {
    String language = 'English',
  }) async {
    await initialize();

    final locale = _locales[language] ?? 'en-IN';

    await stop();

    try {
      await _tts.setLanguage(locale);

      final speech = _buildSpeech(result, language);

      await _tts.speak(speech);
    } catch (e) {
      throw Exception('Unable to play speech: $e');
    }
  }

  String _buildSpeech(RiskResult result, String language) {
    final level = _getTranslatedRisk(result.level, language);

    final reasons = result.reasons.isEmpty
        ? _getNoReasonsMessage(language)
        : result.reasons.join('. ');

    final prefix = switch (language) {
      'Hindi' => 'पेहचान सुरक्षा विश्लेषण।',
      'Kannada' => 'ಪೆಹಚಾನ್ ಭದ್ರತಾ ವಿಶ್ಲೇಷಣೆ.',
      _ => 'Pehchaan security analysis.',
    };

    final score = switch (language) {
      'Hindi' => 'जोखिम स्कोर ${result.score} में से 100 है।',
      'Kannada' => 'ಅಪಾಯದ ಸ್ಕೋರ್ 100 ರಲ್ಲಿ ${result.score}.',
      _ => 'The risk score is ${result.score} out of 100.',
    };

    return '''
$prefix
$level.
$score
${result.verdict}.
${result.summary}.
$reasons
''';
  }

  String _getTranslatedRisk(RiskLevel level, String language) {
    if (language == 'Hindi') {
      switch (level) {
        case RiskLevel.green:
          return 'कम जोखिम';
        case RiskLevel.yellow:
          return 'संदिग्ध सामग्री';
        case RiskLevel.red:
          return 'उच्च जोखिम';
      }
    }

    if (language == 'Kannada') {
      switch (level) {
        case RiskLevel.green:
          return 'ಕಡಿಮೆ ಅಪಾಯ';
        case RiskLevel.yellow:
          return 'ಅನುಮಾನಾಸ್ಪದ';
        case RiskLevel.red:
          return 'ಹೆಚ್ಚಿನ ಅಪಾಯ';
      }
    }

    switch (level) {
      case RiskLevel.green:
        return 'Low risk';
      case RiskLevel.yellow:
        return 'Suspicious content';
      case RiskLevel.red:
        return 'High risk';
    }
  }

  String _getNoReasonsMessage(String language) {
    switch (language) {
      case 'Hindi':
        return 'कोई विशेष चेतावनी संकेत नहीं मिले।';
      case 'Kannada':
        return 'ಯಾವುದೇ ನಿರ್ದಿಷ್ಟ ಎಚ್ಚರಿಕೆಯ ಸೂಚನೆಗಳು ಕಂಡುಬಂದಿಲ್ಲ.';
      default:
        return 'No specific warning indicators were detected.';
    }
  }

  Future<void> speakText(
    String text, {
    String language = 'English',
  }) async {
    await initialize();
    await stop();

    await _tts.setLanguage(_locales[language] ?? 'en-IN');
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    await stop();
  }
}