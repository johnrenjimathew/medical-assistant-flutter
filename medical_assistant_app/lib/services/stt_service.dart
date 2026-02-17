import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService {
  static final SttService _instance = SttService._internal();
  factory SttService() => _instance;
  SttService._internal();

  late stt.SpeechToText _speechToText;
  bool _isInitialized = false;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _lastWords = '';
  String? _lastSttError;

  Future<void> init() async {
    if (_isInitialized && _isSpeechAvailable) return;
    _speechToText = stt.SpeechToText();
    _isSpeechAvailable = await _speechToText.initialize(
      onStatus: (_) {},
      onError: (error) {
        _lastSttError = _friendlyErrorMessage(error.errorMsg);
      },
    );
    _isInitialized = true;
  }

  String _friendlyErrorMessage(String? rawError) {
    final normalized = (rawError ?? '').toLowerCase();
    if (normalized.contains('permission')) {
      return 'Microphone permission is required. Allow it in app settings and try again.';
    }
    if (normalized.contains('notavailable') || normalized.contains('recognizer')) {
      return 'Speech recognition is not available on this device.';
    }
    if ((rawError ?? '').isNotEmpty) return rawError!;
    return 'Could not start listening. Check microphone permission.';
  }

  Future<bool> _ensureReady() async {
    await init();
    if (_isSpeechAvailable) return true;

    // Re-try initialization in case permission was changed after first launch.
    _isInitialized = false;
    await init();
    if (_isSpeechAvailable) return true;

    _lastSttError = _lastSttError ??
        'Microphone permission is required. Allow it in app settings and try again.';
    return false;
  }

  Future<String?> startListening() async {
    if (!await _ensureReady()) {
      return null;
    }

    _lastWords = '';
    _lastSttError = null;

    try {
      await _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        localeId: 'en_US',
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 150));
      if (!_speechToText.isListening) {
        _lastSttError = 'Could not start listening. Check microphone permission.';
        return null;
      }

      _isListening = true;
    } catch (e) {
      _lastSttError = _friendlyErrorMessage(e.toString());
      return null;
    }

    return null;
  }

  Future<String?> stopListening() async {
    if (!_isInitialized || !_isListening) return null;

    try {
      await _speechToText.stop();
      _isListening = false;
    } catch (_) {
      return null;
    }

    return _lastWords.isNotEmpty ? _lastWords : null;
  }

  Future<String?> speechToText() async {
    if (!await _ensureReady()) {
      return null;
    }

    final completer = Completer<String?>();
    String recognizedText = '';
    _lastSttError = null;
    Timer? timeoutTimer;
    const listenForDuration = Duration(seconds: 15);
    const pauseForDuration = Duration(seconds: 3);
    const timeoutBuffer = Duration(seconds: 1);

    Future<void> finishRecognition() async {
      if (completer.isCompleted) return;
      try {
        await _speechToText.stop();
      } catch (_) {}
      completer.complete(recognizedText.isNotEmpty ? recognizedText : null);
    }

    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }

      await _speechToText.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
          if (result.finalResult) {
            finishRecognition();
          }
        },
        listenFor: listenForDuration,
        pauseFor: pauseForDuration,
        localeId: 'en_US',
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 150));
      if (!_speechToText.isListening) {
        _lastSttError = 'Could not start listening. Check microphone permission.';
        completer.complete(null);
        return completer.future;
      }

      timeoutTimer = Timer(listenForDuration + timeoutBuffer, () {
        finishRecognition();
      });
    } catch (e) {
      _lastSttError = _friendlyErrorMessage(e.toString());
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    final result = await completer.future;
    timeoutTimer?.cancel();
    return result;
  }

  Future<String?> simpleSpeechToText() async {
    if (!await _ensureReady()) {
      return null;
    }

    String? finalResult;
    _lastSttError = null;

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            finalResult = result.recognizedWords;
          }
        },
        listenFor: const Duration(seconds: 5),
        localeId: 'en_US',
      );

      await Future.delayed(const Duration(milliseconds: 150));
      if (!_speechToText.isListening) {
        _lastSttError = 'Could not start listening. Check microphone permission.';
        return null;
      }

      await Future.delayed(const Duration(seconds: 6));
      await _speechToText.stop();
    } catch (e) {
      _lastSttError = _friendlyErrorMessage(e.toString());
    }

    return finalResult;
  }

  bool get isSpeechAvailable => _isSpeechAvailable;
  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String? get lastSttError => _lastSttError;
}
