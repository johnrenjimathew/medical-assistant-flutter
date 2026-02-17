import 'package:medicine_reminder/services/stt_service.dart';
import 'package:medicine_reminder/services/tts_service.dart';

// Deprecated compatibility facade. Prefer using TtsService and SttService directly.
class AccessibilityService {
  static final AccessibilityService _instance =
      AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  final TtsService _ttsService = TtsService();
  final SttService _sttService = SttService();

  Future<void> init() async {
    await _ttsService.init();
    await _sttService.init();
  }

  Future<void> textToSpeech(String text) => _ttsService.textToSpeech(text);
  Future<void> stopSpeech() => _ttsService.stopSpeech();
  Future<void> pauseSpeech() => _ttsService.pauseSpeech();
  Future<void> resumeSpeech() => _ttsService.resumeSpeech();

  Future<String?> startListening() => _sttService.startListening();
  Future<String?> stopListening() => _sttService.stopListening();
  Future<String?> speechToText() => _sttService.speechToText();
  Future<String?> simpleSpeechToText() => _sttService.simpleSpeechToText();

  Future<void> speakMedicineReminder(
    String medicineName,
    String dosage,
    String time,
  ) =>
      _ttsService.speakMedicineReminder(medicineName, dosage, time);

  Future<void> speakInteractionWarning(
    String medicineName,
    List<String> conflictingMedicines,
  ) =>
      _ttsService.speakInteractionWarning(medicineName, conflictingMedicines);

  Future<void> speakAlert(String message) => _ttsService.speakAlert(message);
  Future<void> speakConfirmation(String message) =>
      _ttsService.speakConfirmation(message);

  bool get isSpeechAvailable => _sttService.isSpeechAvailable;
  bool get isListening => _sttService.isListening;
  String get lastWords => _sttService.lastWords;
  String? get lastSttError => _sttService.lastSttError;

  TtsState get ttsState => _ttsService.ttsState;
  double get speechRate => _ttsService.speechRate;
  double get pitch => _ttsService.pitch;

  Future<void> setSpeechRate(double rate) => _ttsService.setSpeechRate(rate);
  Future<void> setPitch(double pitch) => _ttsService.setPitch(pitch);
  Future<void> setVolume(double volume) => _ttsService.setVolume(volume);
  Future<void> setLanguage(String language) => _ttsService.setLanguage(language);

  bool get isSpeaking => _ttsService.isSpeaking;
  bool get isPaused => _ttsService.isPaused;
  Future<List<dynamic>> getAvailableLanguages() =>
      _ttsService.getAvailableLanguages();

  void dispose() {
    _ttsService.dispose();
  }
}
