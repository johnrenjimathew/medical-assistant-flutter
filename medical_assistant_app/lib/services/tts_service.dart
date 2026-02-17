import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  late FlutterTts _tts;
  bool _isInitialized = false;

  TtsState _ttsState = TtsState.stopped;
  double _volume = 1.0;
  double _rate = 0.5;
  double _pitch = 1.0;

  Future<void> init() async {
    if (_isInitialized) return;
    _tts = FlutterTts();
    await _configureTts();
    _isInitialized = true;
  }

  Future<void> _configureTts() async {
    await _tts.setVolume(_volume);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);

    final languages = await _tts.getLanguages;
    if (languages.contains('en-US')) {
      await _tts.setLanguage('en-US');
    } else if (languages.contains('en-GB')) {
      await _tts.setLanguage('en-GB');
    } else if (languages.isNotEmpty) {
      await _tts.setLanguage(languages.first as String);
    }

    _tts.setStartHandler(() {
      _ttsState = TtsState.playing;
    });

    _tts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
    });

    _tts.setPauseHandler(() {
      _ttsState = TtsState.paused;
    });

    _tts.setErrorHandler((_) {
      _ttsState = TtsState.stopped;
    });
  }

  Future<void> textToSpeech(String text) async {
    if (text.isEmpty) return;
    if (!_isInitialized) await init();

    final prefs = await SharedPreferences.getInstance();
    final voiceRemindersEnabled = prefs.getBool('voiceReminders') ?? true;
    if (!voiceRemindersEnabled) return;

    try {
      if (_ttsState == TtsState.playing) {
        await _tts.stop();
      }
      await _tts.speak(text);
    } catch (_) {
      _ttsState = TtsState.stopped;
    }
  }

  Future<void> stopSpeech() async {
    if (!_isInitialized) return;
    try {
      await _tts.stop();
      _ttsState = TtsState.stopped;
    } catch (_) {}
  }

  Future<void> pauseSpeech() async {
    if (!_isInitialized) return;
    try {
      await _tts.pause();
      _ttsState = TtsState.paused;
    } catch (_) {}
  }

  Future<void> resumeSpeech() async {
    _ttsState = TtsState.playing;
  }

  Future<void> speakMedicineReminder(
    String medicineName,
    String dosage,
    String time,
  ) async {
    await textToSpeech(
      'Reminder: Time to take your $medicineName. Dosage: $dosage. Scheduled for $time.',
    );
  }

  Future<void> speakInteractionWarning(
    String medicineName,
    List<String> conflictingMedicines,
  ) async {
    final medicines = conflictingMedicines.join(', ');
    await textToSpeech(
      'Warning: $medicineName may interact with $medicines. '
      'Please consult your doctor before taking these medicines together.',
    );
  }

  Future<void> speakAlert(String message) async {
    await textToSpeech('Alert: $message');
  }

  Future<void> speakConfirmation(String message) async {
    await textToSpeech('Confirmed: $message');
  }

  TtsState get ttsState => _ttsState;
  double get speechRate => _rate;
  double get pitch => _pitch;
  bool get isSpeaking => _ttsState == TtsState.playing;
  bool get isPaused => _ttsState == TtsState.paused;

  Future<void> setSpeechRate(double rate) async {
    _rate = rate;
    if (_isInitialized) {
      await _tts.setSpeechRate(rate);
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    if (_isInitialized) {
      await _tts.setPitch(pitch);
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    if (_isInitialized) {
      await _tts.setVolume(volume);
    }
  }

  Future<void> setLanguage(String language) async {
    if (!_isInitialized) await init();
    await _tts.setLanguage(language);
  }

  Future<List<dynamic>> getAvailableLanguages() async {
    if (!_isInitialized) await init();
    final languages = await _tts.getLanguages;
    return List<dynamic>.from(languages as List);
  }

  void dispose() {
    if (_isInitialized) {
      _tts.stop();
    }
  }
}
