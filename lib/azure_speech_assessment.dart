import 'dart:async';
import 'dart:convert';

import 'package:azure_speech_assessment/azure_speech_recognition_result.dart';

import 'azure_speech_assessment_platform_interface.dart';
import 'package:flutter/services.dart';

/// Describes the goal of your speech recognition to the system.
///
/// Currently only supported on **iOS**.
///
/// See also:
/// * https://developer.apple.com/documentation/speech/sfspeechrecognitiontaskhint
enum AzureListenMode {
  /// The device default.
  deviceDefault,

  /// When using captured speech for text entry.
  ///
  /// Use this when you are using speech recognition for a task that's similar to the keyboard's built-in dictation function.
  dictation,

  /// When using captured speech to specify search terms.
  ///
  /// Use this when you are using speech recognition to identify search terms.
  search,

  /// When using captured speech for short, confirmation-style requests.
  ///
  /// Use this when you are using speech recognition to handle confirmation commands, such as "yes", "no" or "maybe".
  confirmation,
}

/// Notified as words are recognized with the current set of recognized words.
///
/// See the [onResult] argument on the [SpeechToText.listen] method for use.
typedef AzureSpeechResultListener = void Function(
    AzureSpeechRecognitionResult result);

typedef void StringResultHandler(String text);

class AzureSpeechAssessment {
  Future<String?> getPlatformVersion() {
    return AzureSpeechAssessmentPlatform.instance.getPlatformVersion();
  }

  static const MethodChannel _channel =
      const MethodChannel('azure_speech_recognition');

  static final AzureSpeechAssessment _azureSpeechRecognition =
      new AzureSpeechAssessment._internal();

  factory AzureSpeechAssessment() => _azureSpeechRecognition;

  AzureSpeechAssessment._internal() {
    _channel.setMethodCallHandler(_platformCallHandler);
  }

  static String? _subKey;
  static String? _region;
  static String _lang = "en-EN";
  static String _voiceName = "en-US-JennyNeural";
  static String _timeout = "500";

  static String? _languageUnderstandingSubscriptionKey;
  static String? _languageUnderstandingServiceRegion;
  static String? _languageUnderstandingAppId;

  /// default intitializer for almost every type except for the intent recognizer.
  /// Default language -> English
  AzureSpeechAssessment.initialize(String subKey, String region,
      {String? lang, String? timeout, String? voiceName}) {
    _subKey = subKey;
    _region = region;
    if (lang != null) _lang = lang;
    if (voiceName != null) _voiceName = voiceName;
    if (timeout != null) {
      if (int.parse(timeout) >= 100 && int.parse(timeout) <= 5000) {
        _timeout = timeout;
      } else {
        throw "Segmentation silence timeout must be an integer in the range 100 to 5000. See https://learn.microsoft.com/en-us/azure/cognitive-services/speech-service/how-to-recognize-speech?pivots=programming-language-csharp#change-how-silence-is-handled for more information.";
      }
    }
  }

  /// initializer for intent purpose
  /// Default language -> English
  AzureSpeechAssessment.initializeLanguageUnderstading(
      String subKey, String region, String appId,
      {lang, voiceName}) {
    _languageUnderstandingSubscriptionKey = subKey;
    _languageUnderstandingServiceRegion = region;
    _languageUnderstandingAppId = appId;
    if (lang != null) _lang = lang;
    if (voiceName != null) _voiceName = voiceName;
  }

  StringResultHandler? exceptionHandler;
  StringResultHandler? recognitionResultHandler;
  StringResultHandler? finalTranscriptionHandler;
  StringResultHandler? finalAssessmentHandler;
  VoidCallback? recognitionStartedHandler;
  VoidCallback? startRecognitionHandler;
  VoidCallback? recognitionStoppedHandler;
  static AzureSpeechResultListener? recognitionHandler;

  VoidCallback? speakStartedHandler;
  VoidCallback? speakStoppedHandler;

  Future _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case "speech.onRecognitionStarted":
        if (recognitionStartedHandler != null) recognitionStartedHandler!();
        break;
      case "speech.onSpeech":
        if (recognitionResultHandler != null)
          recognitionResultHandler!(call.arguments);
        break;
      case "speech.onFinalResponse":
        if (finalTranscriptionHandler != null)
          finalTranscriptionHandler!(call.arguments);
        break;
      case "speech.onFinalAssessment":
        if (finalAssessmentHandler != null)
          finalAssessmentHandler!(call.arguments);
        break;
      case "speech.onStartAvailable":
        if (startRecognitionHandler != null) startRecognitionHandler!();
        break;
      case "speech.onRecognitionStopped":
        if (recognitionStoppedHandler != null) recognitionStoppedHandler!();
        break;
      case "speech.onSpeakStarted":
        if (speakStartedHandler != null) speakStartedHandler!();
        break;
      case "speech.onSpeakStopped":
        if (speakStoppedHandler != null) speakStoppedHandler!();
        break;
      case "speech.onException":
        if (exceptionHandler != null) exceptionHandler!(call.arguments);
        break;
      case "speech.OnRecognition":
        if (call.arguments is String && recognitionHandler != null) {
          Map<String, dynamic> resultMap = jsonDecode(call.arguments);
          var speechResult = AzureSpeechRecognitionResult.fromJson(resultMap);
          recognitionHandler!(speechResult);
        }

        break;

      default:
        print("Error: method called not found");
    }
  }

  /// called each time a result is obtained from the async call
  void setRecognitionResultHandler(StringResultHandler handler) =>
      recognitionResultHandler = handler;

  /// final transcription is passed here
  void setFinalTranscription(StringResultHandler handler) =>
      finalTranscriptionHandler = handler;

  /// final assessment is passed here
  void setFinalAssessment(StringResultHandler handler) =>
      finalAssessmentHandler = handler;

  /// called when an exception occur
  void onExceptionHandler(StringResultHandler handler) =>
      exceptionHandler = handler;

  /// called when the recognition is started
  void setRecognitionStartedHandler(VoidCallback handler) =>
      recognitionStartedHandler = handler;

  /// only for continuosly
  void setStartHandler(VoidCallback handler) =>
      startRecognitionHandler = handler;

  /// only for continuosly
  void setRecognitionStoppedHandler(VoidCallback handler) =>
      recognitionStoppedHandler = handler;

  /// called when the speak is started
  void setSpeakStartedHandler(VoidCallback handler) =>
      speakStartedHandler = handler;

  /// called when the speak is started
  void setSpeakStoppedHandler(VoidCallback handler) =>
      speakStoppedHandler = handler;

  /// Simple voice Recognition, the result will be sent only at the end.
  /// Return the text obtained or the error catched

  static simpleVoiceRecognition() {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('simpleVoice', {
        'language': _lang,
        'subscriptionKey': _subKey,
        'region': _region,
        'timeout': _timeout
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  static simpleVoiceRecognitionPlus() {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('simpleVoicePlus', {
        'language': _lang,
        'subscriptionKey': _subKey,
        'region': _region,
        'timeout': _timeout
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  static soundRecord(String path) {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('soundRecord', {
        'language': _lang,
        'subscriptionKey': _subKey,
        'region': _region,
        'timeout': _timeout,
        'path': path
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  /// Speech recognition that return text while still recognizing
  /// Return the text obtained or the error catched

  static micStream() {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('micStream',
          {'language': _lang, 'subscriptionKey': _subKey, 'region': _region});
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  /// Synthesize speech
  static speakText(String text) {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('speakText', {
        'text': text,
        'language': _lang,
        'voiceName': _voiceName,
        'subscriptionKey': _subKey,
        'region': _region
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  /// Synthesize speech stop
  static speakStop() {
    _channel.invokeMethod('speakStop');
  }

  /// Synthesize speech
  static initSpeakTextPlus() {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('initSpeakTextPlus', {
        'language': _lang,
        'voiceName': _voiceName,
        'subscriptionKey': _subKey,
        'region': _region
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  /// Synthesize speech
  static speakSSMLPlus(String ssml) {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('speakSSMLPlus', {
        'ssml': ssml,
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  /// Synthesize speech
  static speakTextPlus(String text) {
    if ((_subKey != null && _region != null)) {
      _channel.invokeMethod('speakTextPlus', {
        'text': text,
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  /// Synthesize speech stop
  static speakTextPlusPause() {
    _channel.invokeMethod('speakTextPlusPause');
  }

  /// Synthesize speech stop
  static speakTextPlusStop() {
    _channel.invokeMethod('speakTextPlusStop');
  }

  /// Speech recognition that doesnt stop recording text until you stopped it by calling again this function
  /// Return the text obtained or the error catched

  static continuousRecording() {
    if (_subKey != null && _region != null) {
      _channel.invokeMethod('continuousStream',
          {'language': _lang, 'subscriptionKey': _subKey, 'region': _region});
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  static dictationMode() {
    if (_subKey != null && _region != null) {
      _channel.invokeMethod('dictationMode',
          {'language': _lang, 'subscriptionKey': _subKey, 'region': _region});
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  /// Intent recognition
  /// Return the intent obtained or the error catched

  static intentRecognizer() {
    if (_languageUnderstandingSubscriptionKey != null &&
        _languageUnderstandingServiceRegion != null &&
        _languageUnderstandingAppId != null) {
      _channel.invokeMethod('intentRecognizer', {
        'language': _lang,
        'subscriptionKey': _languageUnderstandingSubscriptionKey,
        'appId': _languageUnderstandingAppId,
        'region': _languageUnderstandingServiceRegion
      });
    } else {
      throw "Error: LanguageUnderstading not initialized correctly";
    }
  }

  /// Speech recognition with Keywords
  /// [kwsModelName] name of the file in the asset folder that contains the keywords
  /// Return the speech obtained or the error catched

  static speechRecognizerWithKeyword(String kwsModelName) {
    if (_subKey != null && _region != null) {
      _channel.invokeMethod('keywordRecognizer', {
        'language': _lang,
        'subscriptionKey': _subKey,
        'region': _region,
        'kwsModel': kwsModelName
      });
    } else {
      throw "Error: SpeechRecognitionParameters not initialized correctly";
    }
  }

  // recognizerStop
  static Future recognizerStop() async {
    return await _channel.invokeMethod('recognizerStop');
  }

  // recognizerStart
  static Future recognizerStart({
    AzureSpeechResultListener? onResult,
    String? localeId,
    onDevice = false,
    AzureListenMode listenMode = AzureListenMode.confirmation,
  }) async {
    recognitionHandler = onResult;

    return await _channel.invokeMethod('recognizerStart', {
      "partialResults": true,
      "onDevice": onDevice,
      "listenMode": listenMode.index,
      "localeId": localeId
    });
  }
}
