import Flutter
import AVFoundation
import UIKit
import MicrosoftCognitiveServicesSpeech

public class AzureSpeechAssessmentPlugin: NSObject, FlutterPlugin {
    var azureChannel: FlutterMethodChannel
    var continuousListeningStarted: Bool = false
    private var speechRecognizer: SPXSpeechRecognizer?
    private var speakSynthesizer: SPXSpeechSynthesizer?
    
    var text = ""
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "azure_speech_recognition", binaryMessenger: registrar.messenger())
        let instance: AzureSpeechAssessmentPlugin = AzureSpeechAssessmentPlugin(azureChannel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    init(azureChannel: FlutterMethodChannel) {
        self.azureChannel = azureChannel
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? Dictionary<String, String>
        if (call.method == "simpleVoice") {
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let timeoutMs = args?["timeout"] ?? ""
            print("Called simpleVoice \(speechSubscriptionKey) \(serviceRegion) \(lang) \(timeoutMs)")
            simpleSpeechRecognition(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs)
        } else if(call.method == "micStream"){
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let timeoutMs = args?["timeout"] ?? ""
            print("Called simpleVoice \(speechSubscriptionKey) \(serviceRegion) \(lang) \(timeoutMs)")
            DispatchQueue.global(qos: .userInteractive).async {
                self.micStreamSpeechRecognition(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs)
            }
        } else if (call.method == "simpleVoicePlus") {
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let timeoutMs = args?["timeout"] ?? ""
            print("Called simpleVoicePlus \(speechSubscriptionKey) \(serviceRegion) \(lang) \(timeoutMs)")
            simpleSpeechRecognitionPlus(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs)
        } else if (call.method == "soundRecord") {
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let timeoutMs = args?["timeout"] ?? ""
            let path = args?["path"] ?? ""
            print("Called soundRecord \(speechSubscriptionKey) \(serviceRegion) \(lang) \(timeoutMs) \(path)")
            soundRecord(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs, path: path)
        } else if (call.method == "speakText") {
            let text = args?["text"] ?? ""
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let voiceName = args?["voiceName"] ?? ""
            
            print("Called speakText \(speechSubscriptionKey) \(serviceRegion) \(lang)")
            
            speakText(text: text,speechSubscriptionKey: speechSubscriptionKey,serviceRegion: serviceRegion, lang: lang, voiceName: voiceName);
        } else if(call.method == "speakStop"){
            print("Called speakStop")
            speakStop();
        }
        else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func simpleSpeechRecognition(speechSubscriptionKey : String, serviceRegion : String, lang: String, timeoutMs: String) {
        var speechConfig: SPXSpeechConfiguration?
        do {
            try speechConfig = SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
            speechConfig!.enableDictation();
        } catch {
            print("error \(error) happened")
            speechConfig = nil
        }
        speechConfig?.speechRecognitionLanguage = lang
        speechConfig?.setPropertyTo(timeoutMs, by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
        
        let audioConfig = SPXAudioConfiguration()
        
        let reco = try! SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)
        
        //               reco.addRecognizingEventHandler() {reco, evt in
        
        //                   print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
        
        //               }
        
        print("Listening...")
        
        let result = try! reco.recognizeOnce()
        print("recognition result: \(result.text ?? "(no result)"), reason: \(result.reason.rawValue)")
        
        if result.reason != SPXResultReason.recognizedSpeech {
            let cancellationDetails = try! SPXCancellationDetails(fromCanceledRecognitionResult: result)
            print("cancelled: \(result.reason), \(String(describing: cancellationDetails.errorDetails))")
            print("Did you set the speech resource key and region values?")
            azureChannel.invokeMethod("speech.onFinalResponse", arguments: "")
        } else {
            azureChannel.invokeMethod("speech.onFinalResponse", arguments: result.text)
        }
        
    }
    public func speakStop() {
        try! speakSynthesizer?.stopSpeaking()
    }
    
    public func speakText(text:String, speechSubscriptionKey : String, serviceRegion : String, lang: String, voiceName: String) {
        if (speakSynthesizer == nil) {
            var speechConfig: SPXSpeechConfiguration?
            do {
                try speechConfig = SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
                // speechConfig!.enableDictation()
                speechConfig!.speechSynthesisLanguage = lang
                speechConfig!.speechSynthesisVoiceName = voiceName
                
                // 设置音频格式
                speechConfig!.setSpeechSynthesisOutputFormat(.raw16Khz16BitMonoPcm)
            } catch {
                print("error \(error) happened")
                speechConfig = nil
            }
            // let audioConfig = SPXAudioConfiguration()
            speakSynthesizer = try! SPXSpeechSynthesizer(speechConfiguration: speechConfig!, audioConfiguration: nil)
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, options: [.defaultToSpeaker,.allowBluetooth,.allowBluetoothA2DP])
            print("####################### speech AudioCategory \(audioSession.category)")
            print("####################### speech AudioCategoryOptions \(audioSession.categoryOptions)")
            try audioSession.setMode(AVAudioSession.Mode.default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession error \(error) happened")
        }
        
        DispatchQueue.global().async{
            self.stopAudio()
            self.azureChannel.invokeMethod("speech.onSpeakStarted", arguments: "")
            let speechResult = try! self.speakSynthesizer?.startSpeakingText(text)
            if (speechResult != nil) {

                self.speechStream = try! SPXAudioDataStream(from: speechResult!)
//                var data = NSMutableData(capacity: 16000)
//                while (stream.read(data!, length: 16000) > 0) {
//                    print("speechResult data \(data)")
//                }

                self.startAudio()
            }
            
//            let speechResult = try! self.speakSynthesizer?.speakText(text)
//            print("####################### speechResult first byte latency \(String(describing: speechResult?.properties?.getPropertyBy(.speechServiceResponseSynthesisFirstByteLatencyMs)))")
//            print("####################### speechResult finish latency  \(String(describing: speechResult?.properties?.getPropertyBy(.speechServiceResponseSynthesisFinishLatencyMs)))")
//            self.azureChannel.invokeMethod("speech.onSpeakStopped", arguments: "")
        }
        
    }
    
    var speechStream: SPXAudioDataStream? = nil
    var speeching: Bool = false
    private func stopAudio() {
        if (!speeching) {return}
        speeching = false
        do {
            print("stopAudio STOP 1 \(String(describing: remoteIOUnit))")
            if (remoteIOUnit != nil) {
                print("stopAudio STOP 2 \(String(describing: remoteIOUnit))")
                AudioOutputUnitStop(remoteIOUnit!);
                // AudioComponentInstanceDispose(remoteIOUnit!);
                print("stopAudio STOP 3 \(String(describing: remoteIOUnit))")
            }
            self.azureChannel.invokeMethod("speech.onSpeakStopped", arguments: "")
        } catch {
            print("stopAudio STOP error")
        }
    }
    
    //需要实例化的AudioUnit
    var remoteIOUnit: AudioUnit? = nil;
    let callback: AURenderCallback = {
        (inRefCon: UnsafeMutableRawPointer,
         ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
         inTimeStamp:  UnsafePointer<AudioTimeStamp>,
         inBusNumber: UInt32,
         inNumberFrames: UInt32,
         ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        var status = noErr
        let this = unsafeBitCast(inRefCon, to: AzureSpeechAssessmentPlugin.self)
        
        if (!this.speeching) {return status}
        
        if (this.speechStream != nil) {
            let bufferData: AudioBuffer = ioData!.pointee.mBuffers
            guard let length = ioData?.pointee.mBuffers.mDataByteSize else { return noErr }
            guard let buffer = ioData?.pointee.mBuffers.mData else { return noErr }
           
            var data = NSMutableData(capacity: Int(length))
            if this.speechStream!.read(data!, length: UInt(length)) > 0 {
                memset(ioData?.pointee.mBuffers.mData, 0, Int(length))
                
                ioData?.pointee.mBuffers.mData = data!.mutableBytes
            } else {
                print("speechResult stop")
                this.stopAudio()
            }
        }
        
        return status
    }
    
    private func startAudio() {
        speeching = true
        // 1.1 创建AudioComponentDescription用来标识AudioUnit
        // AudioUnit描述
        var componentDesc = AudioComponentDescription();
        //AudioUnit的主类型
        componentDesc.componentType = kAudioUnitType_Output;
        //AudioUnit的子类型
        componentDesc.componentSubType = kAudioUnitSubType_RemoteIO;
        //AudioUnit制造商，目前只支持苹果
        componentDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
        //以下两个字段固定是0
        componentDesc.componentFlags = 0;
        componentDesc.componentFlagsMask = 0;
        
        // 1.2 创建AudioComponent获取AudioUnit实例
        //查找AudioComponent
        //第一个参数传递NULL，告诉此函数使用系统定义的顺序查找匹配的第一个系统音频单元
        guard let foundIoUnitReference = AudioComponentFindNext (nil, &componentDesc) else {
            print("speechResult ####################### 创建AudioComponent获取AudioUnit实例错误")
            return
        };
        //实例化AudioUnit
        var status = AudioComponentInstanceNew(foundIoUnitReference, &remoteIOUnit);
        if (status != 0) {
            print("speechResult ####################### 实例化AudioUnit错误")
            return
        }
//        var disableFlag: UInt32 = 0
//        var enableFlag: UInt32 = 1;
//
//        //开启扬声器
//        AudioUnitSetProperty(remoteIOUnit!,
//                     kAudioOutputUnitProperty_EnableIO,
//                     kAudioUnitScope_Output,
//                     0,
//                     &enableFlag,
//                     UInt32(MemoryLayout<UInt32>.size))
        
        // 设置AudioUnit基本参数
        var mAudioFormat = AudioStreamBasicDescription()
        mAudioFormat.mSampleRate = 16000;
        mAudioFormat.mFormatID = kAudioFormatLinearPCM;
        mAudioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        mAudioFormat.mReserved = 0;
        mAudioFormat.mChannelsPerFrame = 1;
        mAudioFormat.mBitsPerChannel = 16;
        mAudioFormat.mFramesPerPacket = 1;
        mAudioFormat.mBytesPerFrame = (mAudioFormat.mBitsPerChannel / 8) * mAudioFormat.mChannelsPerFrame; // 每帧的bytes数2
        mAudioFormat.mBytesPerPacket =  mAudioFormat.mFramesPerPacket*mAudioFormat.mBytesPerFrame;//每个包的字节数2
        
        let size: UInt32 = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = AudioUnitSetProperty(remoteIOUnit!,
                            kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Output,
                            1,
                            &mAudioFormat,
                            size)
        if (status != 0) {
            print("speechResult ####################### kAudioUnitProperty_StreamFormat of bus 1 failed")
            return
        }
        status = AudioUnitSetProperty(remoteIOUnit!,
                            kAudioUnitProperty_StreamFormat,
                            kAudioUnitScope_Input,
                            0,
                            &mAudioFormat,
                            size)
        if (status != 0) {
            print("speechResult ####################### kAudioUnitProperty_StreamFormat of bus 0 failed")
            return
        }
        
        var callbackStruct = AURenderCallbackStruct(inputProc: callback, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        status = AudioUnitSetProperty(remoteIOUnit!,
                            kAudioUnitProperty_SetRenderCallback,
                            kAudioUnitScope_Input,
                            0,
                            &callbackStruct,
                            UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        if (status != 0) {
            print("speechResult ####################### 设置采集回调失败")
            return
        }
        
        // 初始化AudioUnit
        status = AudioUnitInitialize(remoteIOUnit!)
        if (status != 0) {
            print("speechResult ####################### 初始化AudioUnit 失败")
            return
        }
        // 启动AudioUnit
        status = AudioOutputUnitStart(remoteIOUnit!)
        if (status != 0) {
            print("speechResult ####################### 启动AudioUnit 失败")
            return
        }
    }
    
    
    
    public func micStreamSpeechRecognition(speechSubscriptionKey : String, serviceRegion : String, lang: String, timeoutMs: String) {
        if continuousListeningStarted == true {
            do {
                print("stopContinuousRecognition start \(continuousListeningStarted)")
                try speechRecognizer?.stopContinuousRecognition()
                print("stopContinuousRecognition end")
            } catch {
                
            }
            continuousListeningStarted = false
            return
        }
        var speechConfig: SPXSpeechConfiguration?
        do {
            try speechConfig = SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
            speechConfig!.enableDictation()
        } catch {
            print("error \(error) happened")
            speechConfig = nil
        }
        //speechConfig?.speechRecognitionLanguage = lang
        //speechConfig?.setPropertyTo(timeoutMs, by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
        let audioConfig = SPXAudioConfiguration()
        speechRecognizer = try! SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)
        speechRecognizer?.addRecognizedEventHandler() { reco, evt in
            if self.text.isEmpty == false {
                self.text += " "
            }
            self.text += evt.result.text ?? ""
            DispatchQueue.global().async{
                self.azureChannel.invokeMethod("speech.onSpeech",arguments:evt.result.text ?? "")
                print("sentence recognition result: \(evt.result.text ?? "(no result)")")
            }
            //              self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: self.text ?? "")
        }
        speechRecognizer?.addSessionStoppedEventHandler() {reco, evt in
            print("Received session stopped event. SessionId: \(evt.sessionId)")
            DispatchQueue.global().async{
                self.azureChannel.invokeMethod("speech.onFinalResponse", arguments: self.text)
                self.text = ""
                self.azureChannel.invokeMethod("speech.onRecognitionStopped",arguments:nil);
                self.speechRecognizer = nil
            }
            
        }
        DispatchQueue.global().async{
            self.azureChannel.invokeMethod("speech.onRecognitionStarted",arguments:nil)
        }
        
        print("Listening...")
        continuousListeningStarted = true
        do {
            try? speechRecognizer?.startContinuousRecognition()
        } catch {
            print("error \(error) happened")
        }
    }
    
    public func simpleSpeechRecognitionPlus(speechSubscriptionKey : String, serviceRegion : String, lang: String, timeoutMs: String) {
        var speechConfig: SPXSpeechConfiguration?
        do {
            try speechConfig = SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
            speechConfig!.enableDictation();
        } catch {
            print("error \(error) happened")
            speechConfig = nil
        }
        speechConfig?.speechRecognitionLanguage = lang
        speechConfig?.setPropertyTo(timeoutMs, by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
        
        var referenceText: String = "";
        var pronunciationAssessmentConfig: SPXPronunciationAssessmentConfiguration?
        do {
            try pronunciationAssessmentConfig = SPXPronunciationAssessmentConfiguration.init(
                referenceText,
                gradingSystem: SPXPronunciationAssessmentGradingSystem.hundredMark,
                granularity: SPXPronunciationAssessmentGranularity.phoneme,
                enableMiscue: true)
        } catch {
            print("error \(error) happened")
            pronunciationAssessmentConfig = nil
            return
        }
        
        pronunciationAssessmentConfig?.phonemeAlphabet = "IPA"
        
        let audioConfig = SPXAudioConfiguration()
        
        let reco = try! SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)
        
        try! pronunciationAssessmentConfig?.apply(to: reco)
        
        //               reco.addRecognizingEventHandler() {reco, evt in
        
        //                   print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
        
        //               }
        
        
        print("Listening...")
        
        let result = try! reco.recognizeOnce()
        print("recognition result: \(result.text ?? "(no result)"), reason: \(result.reason.rawValue)")
        
        pronunciationAssessmentConfig?.referenceText = result.text;
        
        let pronunciationAssessmentResultJson = result.properties?.getPropertyBy(SPXPropertyId.speechServiceResponseJsonResult)
        print("pronunciationAssessmentResultJson: \(pronunciationAssessmentResultJson ?? "(no result)")")
        
        if result.reason != SPXResultReason.recognizedSpeech {
            let cancellationDetails = try! SPXCancellationDetails(fromCanceledRecognitionResult: result)
            print("cancelled: \(result.reason), \(cancellationDetails.errorDetails)")
            print("Did you set the speech resource key and region values?")
            azureChannel.invokeMethod("speech.onFinalResponse", arguments: "")
        } else {
            azureChannel.invokeMethod("speech.onFinalResponse", arguments: result.text)
            azureChannel.invokeMethod("speech.onFinalAssessment", arguments: pronunciationAssessmentResultJson)
        }
        
        
        
    }
    
    
    public func soundRecord(speechSubscriptionKey : String, serviceRegion : String, lang: String, timeoutMs: String, path: String) {
        var speechConfig: SPXSpeechConfiguration?
        do {
            try speechConfig = SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
        } catch {
            print("error \(error) happened")
            speechConfig = nil
        }
        speechConfig?.speechRecognitionLanguage = lang
        speechConfig?.setPropertyTo(timeoutMs, by: SPXPropertyId.speechSegmentationSilenceTimeoutMs)
        
        var referenceText: String = "";
        var pronunciationAssessmentConfig: SPXPronunciationAssessmentConfiguration?
        do {
            try pronunciationAssessmentConfig = SPXPronunciationAssessmentConfiguration.init(
                referenceText,
                gradingSystem: SPXPronunciationAssessmentGradingSystem.hundredMark,
                granularity: SPXPronunciationAssessmentGranularity.phoneme,
                enableMiscue: true)
        } catch {
            print("error \(error) happened")
            pronunciationAssessmentConfig = nil
            return
        }
        
        pronunciationAssessmentConfig?.phonemeAlphabet = "IPA"
        
        let audioConfig = SPXAudioConfiguration(wavFileInput:path)!
        
        let reco = try! SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)
        
        try! pronunciationAssessmentConfig?.apply(to: reco)
        
        //               reco.addRecognizingEventHandler() {reco, evt in
        
        //                   print("intermediate recognition result: \(evt.result.text ?? "(no result)")")
        
        //               }
        
        
        print("Listening...")
        
        let result = try! reco.recognizeOnce()
        print("recognition result: \(result.text ?? "(no result)"), reason: \(result.reason.rawValue)")
        
        pronunciationAssessmentConfig?.referenceText = result.text;
        
        let pronunciationAssessmentResultJson = result.properties?.getPropertyBy(SPXPropertyId.speechServiceResponseJsonResult)
        print("pronunciationAssessmentResultJson: \(pronunciationAssessmentResultJson ?? "(no result)")")
        
        if result.reason != SPXResultReason.recognizedSpeech {
            let cancellationDetails = try! SPXCancellationDetails(fromCanceledRecognitionResult: result)
            print("cancelled: \(result.reason), \(cancellationDetails.errorDetails)")
            print("Did you set the speech resource key and region values?")
            azureChannel.invokeMethod("speech.onFinalResponse", arguments: "")
        } else {
            azureChannel.invokeMethod("speech.onFinalResponse", arguments: result.text)
            azureChannel.invokeMethod("speech.onFinalAssessment", arguments: pronunciationAssessmentResultJson)
        }
        
        
        
    }    
}

