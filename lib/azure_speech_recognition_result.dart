import 'package:json_annotation/json_annotation.dart';

part 'azure_speech_recognition_result.g.dart';

/// A sequence of recognized words from the speech recognition
/// service.
///
/// Depending on the platform behaviour the words may come in all
/// at once at the end or as partial results as each word is
/// recognized. Use the [finalResult] flag to determine if the
/// result is considered final by the platform.
@JsonSerializable(explicitToJson: true)
class AzureSpeechRecognitionResult {
  List<AzureSpeechRecognitionWords> alternates;

  /// Returns a list of possible transcriptions of the speech.
  ///
  /// The first value is always the same as the [recognizedWords]
  /// value. Use the confidence for each alternate transcription
  /// to determine how likely it is. Note that not all platforms
  /// do a good job with confidence, there are convenience methods
  /// on [AzureSpeechRecognitionWords] to work with possibly missing
  /// confidence values.
  // TODO: Fix up the interface.
  // List<SpeechRecognitionWords> get alternates =>
  //    UnmodifiableListView(alternates);

  /// The sequence of words that is the best transcription of
  /// what was said.
  ///
  /// This is the same as the first value of [alternates].
  String get recognizedWords =>
      alternates.isNotEmpty ? alternates.first.recognizedWords : '';

  /// False means the words are an interim result, true means
  /// they are the final recognition.
  final bool finalResult;

  /// The confidence that the [recognizedWords] are correct.
  ///
  /// Confidence is expressed as a value between 0 and 1. -1
  /// means that the confidence value was not available.
  double get confidence =>
      alternates.isNotEmpty ? alternates.first.confidence : 0;

  /// true if there is confidence in this recognition, false otherwise.
  ///
  /// There are two separate ways for there to be confidence, the first
  /// is if the confidence is missing, which is indicated by a value of
  /// -1. The second is if the confidence is greater than or equal
  /// [threshold]. If [threshold] is not provided it defaults to 0.8.
  bool isConfident(
          {double threshold =
              AzureSpeechRecognitionWords.confidenceThreshold}) =>
      alternates.isNotEmpty
          ? alternates.first.isConfident(threshold: threshold)
          : false;

  /// true if [confidence] is not the [AzureSpeechRecognitionWords.missingConfidence] value, false
  /// otherwise.
  bool get hasConfidenceRating =>
      alternates.isNotEmpty ? alternates.first.hasConfidenceRating : false;

  AzureSpeechRecognitionResult(this.alternates, this.finalResult);

  @override
  String toString() {
    return 'AzureSpeechRecognitionResult words: $alternates, final: $finalResult';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AzureSpeechRecognitionResult &&
            recognizedWords == other.recognizedWords &&
            finalResult == other.finalResult;
  }

  @override
  int get hashCode => recognizedWords.hashCode;

  factory AzureSpeechRecognitionResult.fromJson(Map<String, dynamic> json) =>
      _$AzureSpeechRecognitionResultFromJson(json);
  Map<String, dynamic> toJson() => _$AzureSpeechRecognitionResultToJson(this);

  AzureSpeechRecognitionResult toFinal() {
    return AzureSpeechRecognitionResult(alternates, true);
  }
}

/// A set of words recognized in a [AzureSpeechRecognitionResult].
///
/// Each result will have one or more [AzureSpeechRecognitionWords]
/// with a varying degree of confidence about each set of words.
@JsonSerializable()
class AzureSpeechRecognitionWords {
  /// The sequence of words recognized
  final String recognizedWords;

  /// The confidence that the [recognizedWords] are correct.
  ///
  /// Confidence is expressed as a value between 0 and 1. 0
  /// means that the confidence value was not available. Use
  /// [isConfident] which will ignore 0 values automatically.
  final double confidence;

  static const double confidenceThreshold = 0.8;
  static const double missingConfidence = -1;

  const AzureSpeechRecognitionWords(this.recognizedWords, this.confidence);

  /// true if there is confidence in this recognition, false otherwise.
  ///
  /// There are two separate ways for there to be confidence, the first
  /// is if the confidence is missing, which is indicated by a value of
  /// -1. The second is if the confidence is greater than or equal
  /// [threshold]. If [threshold] is not provided it defaults to 0.8.
  bool isConfident({double threshold = confidenceThreshold}) =>
      confidence == missingConfidence || confidence >= threshold;

  /// true if [confidence] is not the [missingConfidence] value, false
  /// otherwise.
  bool get hasConfidenceRating => confidence != missingConfidence;

  @override
  String toString() {
    return 'AzureSpeechRecognitionWords words: $recognizedWords,  confidence: $confidence';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AzureSpeechRecognitionWords &&
            recognizedWords == other.recognizedWords &&
            confidence == other.confidence;
  }

  @override
  int get hashCode => recognizedWords.hashCode;

  factory AzureSpeechRecognitionWords.fromJson(Map<String, dynamic> json) =>
      _$SpeechRecognitionWordsFromJson(json);
  Map<String, dynamic> toJson() => _$SpeechRecognitionWordsToJson(this);
}
