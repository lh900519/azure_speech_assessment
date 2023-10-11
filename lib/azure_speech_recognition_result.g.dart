// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'azure_speech_recognition_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AzureSpeechRecognitionResult _$AzureSpeechRecognitionResultFromJson(
    Map<String, dynamic> json) {
  return AzureSpeechRecognitionResult(
    (json['alternates'] as List<dynamic>)
        .map((e) =>
            AzureSpeechRecognitionWords.fromJson(e as Map<String, dynamic>))
        .toList(),
    json['finalResult'] as bool,
  );
}

Map<String, dynamic> _$AzureSpeechRecognitionResultToJson(
        AzureSpeechRecognitionResult instance) =>
    <String, dynamic>{
      'alternates': instance.alternates.map((e) => e.toJson()).toList(),
      'finalResult': instance.finalResult,
    };

AzureSpeechRecognitionWords _$SpeechRecognitionWordsFromJson(
    Map<String, dynamic> json) {
  return AzureSpeechRecognitionWords(
    json['recognizedWords'] as String,
    (json['confidence'] as num).toDouble(),
  );
}

Map<String, dynamic> _$SpeechRecognitionWordsToJson(
        AzureSpeechRecognitionWords instance) =>
    <String, dynamic>{
      'recognizedWords': instance.recognizedWords,
      'confidence': instance.confidence,
    };
