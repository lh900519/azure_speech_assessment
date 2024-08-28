import Flutter
import AVFoundation
import UIKit
import Speech
import MicrosoftCognitiveServicesSpeech



public enum ListenMode: Int {
    case deviceDefault = 0
    case dictation = 1
    case search = 2
    case confirmation = 3
}

struct SpeechRecognitionWords : Codable {
    let recognizedWords: String
    let confidence: Decimal
}

struct SpeechRecognitionResult : Codable {
    let alternates: [SpeechRecognitionWords]
    let finalResult: Bool
}

struct SpeechRecognitionError : Codable {
    let errorMsg: String
    let permanent: Bool
}

public class AzureSpeechAssessmentPlugin: NSObject, FlutterPlugin {
    var azureChannel: FlutterMethodChannel
    var continuousListeningStarted: Bool = false
    private var speechRecognizer: SPXSpeechRecognizer?
    private var speakSynthesizer: SPXSpeechSynthesizer?
    private var speakSynthesizerPlus: SPXSpeechSynthesizer?
    private let audioSession = AVAudioSession.sharedInstance()
    
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
            // print("Called simpleVoice \(lang) \(timeoutMs)")
            simpleSpeechRecognition(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs)
        } else if(call.method == "micStream"){
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let timeoutMs = args?["timeout"] ?? ""
            // print("Called simpleVoice \(lang) \(timeoutMs)")
            DispatchQueue.global(qos: .userInteractive).async {
                self.micStreamSpeechRecognition(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs)
            }
        } else if (call.method == "simpleVoicePlus") {
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let timeoutMs = args?["timeout"] ?? ""
            // print("Called simpleVoicePlus \(lang) \(timeoutMs)")
            simpleSpeechRecognitionPlus(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs)
        } else if (call.method == "soundRecord") {
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let timeoutMs = args?["timeout"] ?? ""
            let path = args?["path"] ?? ""
            // print("Called soundRecord \(lang) \(timeoutMs) \(path)")
            soundRecord(speechSubscriptionKey: speechSubscriptionKey, serviceRegion: serviceRegion, lang: lang, timeoutMs: timeoutMs, path: path)
        } else if (call.method == "speakText") {
            let text = args?["text"] ?? ""
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let voiceName = args?["voiceName"] ?? ""
            
            speakText(text: text,speechSubscriptionKey: speechSubscriptionKey,serviceRegion: serviceRegion, lang: lang, voiceName: voiceName);
        } else if(call.method == "speakStop"){
            // print("Called speakStop")
            speakStop();
        } else if (call.method == "initSpeakTextPlus") {
            // 初始化
            let speechSubscriptionKey = args?["subscriptionKey"] ?? ""
            let serviceRegion = args?["region"] ?? ""
            let lang = args?["language"] ?? ""
            let voiceName = args?["voiceName"] ?? ""
            
            initSpeakTextPlus(speechSubscriptionKey: speechSubscriptionKey,serviceRegion: serviceRegion, lang: lang, voiceName: voiceName);
            initializeRecognizer(result)
        } else if (call.method == "speakTextPlus") {
            let text = args?["text"] ?? ""
            speakTextPlus(text: text);
        } else if (call.method == "speakSSMLPlus") {
            let ssml = args?["ssml"] ?? ""
            speakSSMLPlus(ssml: ssml);
        } else if (call.method == "speakTextPlusStop") {
            speakTextPlusStop();
        } else if (call.method == "speakTextPlusPause") {
            speakTextPlusPause();
        } else if (call.method == "recognizerStart") {
            // 开始识别文本
            guard let argsArr = call.arguments as? Dictionary<String,AnyObject>,
                  let partialResults = argsArr["partialResults"] as? Bool, let onDevice = argsArr["onDevice"] as? Bool, let listenModeIndex = argsArr["listenMode"] as? Int
            else {
                DispatchQueue.main.async {
                    result(FlutterError( code: "missingOrInvalidArg",
                                         message:"Missing arg partialResults, onDevice, listenMode, and sampleRate are required",
                                         details: nil ))
                }
                return
            }
            var localeStr: String? = nil
            if let localeParam = argsArr["localeId"] as? String {
                localeStr = localeParam
            }
            guard let listenMode = ListenMode(rawValue: listenModeIndex) else {
                DispatchQueue.main.async {
                    result(FlutterError( code: "missingOrInvalidArg",
                                         message:"invalid value for listenMode, must be 0-2, was \(listenModeIndex)",
                                         details: nil ))
                }
                return
            }
            recognizerStart( result, localeStr: localeStr, partialResults: partialResults, onDevice: onDevice, listenMode: listenMode)
        } else if (call.method == "recognizerStop") {
            // 停止识别文本
            recognizerStop(result);
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
        DispatchQueue.global().async{
            try! self.speakSynthesizer?.stopSpeaking()
        }
    }
    
    public func speakText(text:String, speechSubscriptionKey : String, serviceRegion : String, lang: String, voiceName: String) {

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
        let audioConfig = SPXAudioConfiguration()
        speakSynthesizer = try! SPXSpeechSynthesizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig)

        do {
            try self.audioSession.setCategory(AVAudioSession.Category.playback, options: [.allowBluetooth,.allowBluetoothA2DP,.mixWithOthers])
            try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession error \(error) happened")
        }
        
        DispatchQueue.global().async{
            self.azureChannel.invokeMethod("speech.onSpeakStarted", arguments: "")
            let speechResult = try! self.speakSynthesizer?.speakText(text)
            self.azureChannel.invokeMethod("speech.onSpeakStopped", arguments: "")
        }
    }
    
    private var rememberedAudioCategory: AVAudioSession.Category?
    private var rememberedAudioCategoryOptions: AVAudioSession.CategoryOptions?
    
    // 初始化文字转语音
    public func initSpeakTextPlus(speechSubscriptionKey : String, serviceRegion : String, lang: String, voiceName: String) {
        if (speakSynthesizerPlus == nil) {
            var speechConfig: SPXSpeechConfiguration?
            do {
                try speechConfig = SPXSpeechConfiguration(subscription: speechSubscriptionKey, region: serviceRegion)
                speechConfig!.speechSynthesisLanguage = lang
                speechConfig!.speechSynthesisVoiceName = voiceName
                
                // 设置音频格式
                speechConfig!.setSpeechSynthesisOutputFormat(.raw16Khz16BitMonoPcm)
            } catch {
                print("error \(error) happened")
                speechConfig = nil
            }
            
            speakSynthesizerPlus = try! SPXSpeechSynthesizer(speechConfiguration: speechConfig!, audioConfiguration: nil)
        }
        
        do {
            // print("####################### speech AudioCategory \(self.audioSession.category)")
            // print("####################### speech AudioCategoryOptions \(self.audioSession.categoryOptions)")
            rememberedAudioCategory = self.audioSession.category
            rememberedAudioCategoryOptions = self.audioSession.categoryOptions
            try self.audioSession.setCategory(AVAudioSession.Category.playAndRecord, options: [.defaultToSpeaker,.allowBluetooth,.allowBluetoothA2DP])
            // print("####################### speech AudioCategory \(self.audioSession.category)")
            // print("####################### speech AudioCategoryOptions \(self.audioSession.categoryOptions)")
            // try audioSession.setMode(AVAudioSession.Mode.default)
            try self.audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            try self.audioSession.setPreferredIOBufferDuration(0.02)
            
        } catch {
            print("audioSession error \(error) happened")
        }
        
        DispatchQueue.global().async{
            self.azureChannel.invokeMethod("speech.onSpeakStarted", arguments: "")
        }
        startAudio()
    }
    
    
    var speakPlusPlaying: Bool = true
    public func speakTextPlus(text:String) {
        if (speakSynthesizerPlus == nil) {
            print("speakSynthesizerPlus error no init")
            return
        }
        
        speakPlusPlaying = true
        print("AzureSpeech speakTextPlus \(text)")
        
        DispatchQueue.global().async{
            
            self.azureChannel.invokeMethod("speech.onSpeakStarted", arguments: "")
            let speechResult = try! self.speakSynthesizerPlus?.startSpeakingText(text)
            if (speechResult != nil) {
                self.speechStream = try! SPXAudioDataStream(from: speechResult!)
            }
        }
    }
    
    public func speakSSMLPlus(ssml:String) {
        if (speakSynthesizerPlus == nil) {
            print("speakSynthesizerPlus error no init")
            return
        }
        
        speakPlusPlaying = true
        print("AzureSpeech speakTextPlus \(text)")
        
        DispatchQueue.global().async{
            
            self.azureChannel.invokeMethod("speech.onSpeakStarted", arguments: "")
            let speechResult = try! self.speakSynthesizerPlus?.startSpeakingSsml(ssml)
            if (speechResult != nil) {
                self.speechStream = try! SPXAudioDataStream(from: speechResult!)
            }
        }
    }
    
    public func speakTextPlusPause() {
        DispatchQueue.global().async{
            try! self.speakSynthesizerPlus?.stopSpeaking()
        }
        print("AzureSpeech Plus Pause 1 \(String(describing: remoteIOUnit))")
        speechStream = nil
    }
    public func speakTextPlusStop() {
        DispatchQueue.global().async{
            try! self.speakSynthesizerPlus?.stopSpeaking()
        }
        print("AzureSpeech Plus STOP 1 \(String(describing: remoteIOUnit))")
        if (remoteIOUnit != nil) {
            print("AzureSpeech Plus STOP 2 \(String(describing: remoteIOUnit))")
            AudioOutputUnitStop(remoteIOUnit!);
            print("AzureSpeech Plus STOP 3 \(String(describing: remoteIOUnit))")
            do {
                if let rememberedAudioCategory = rememberedAudioCategory, let rememberedAudioCategoryOptions = rememberedAudioCategoryOptions {
                    try self.audioSession.setCategory(rememberedAudioCategory,options: rememberedAudioCategoryOptions)
                }
                
                try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                
                //                try self.audioSession.setCategory(.playback,options: [.allowBluetooth,.allowBluetoothA2DP,.mixWithOthers])
            }
            catch {
                
            }
        }
    }
    
    private func speakTextPlusPlayEnd() {
        if (!speakPlusPlaying) {
            return
        }
        speakPlusPlaying = false
        print("AzureSpeech play End 1")
        self.azureChannel.invokeMethod("speech.onSpeakStopped", arguments: "")
    }
    
    var speechStream: SPXAudioDataStream? = nil
    var speeching: Bool = false
    private func stopAudio() {
        if (!speeching) {return}
        speeching = false
        
        print("AzureSpeech STOP 1 \(String(describing: remoteIOUnit))")
        if (remoteIOUnit != nil) {
            print("AzureSpeech STOP 2 \(String(describing: remoteIOUnit))")
            AudioOutputUnitStop(remoteIOUnit!);
            // AudioComponentInstanceDispose(remoteIOUnit!);
            print("AzureSpeech STOP 3 \(String(describing: remoteIOUnit))")
        }
        
        self.azureChannel.invokeMethod("speech.onSpeakStopped", arguments: "")
    }
    
    let renderCallback: AURenderCallback = {
        (inRefCon: UnsafeMutableRawPointer,
         ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
         inTimeStamp:  UnsafePointer<AudioTimeStamp>,
         inBusNumber: UInt32,
         inNumberFrames: UInt32,
         ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        
        var status = noErr
        
        guard let length = ioData?.pointee.mBuffers.mDataByteSize else { return noErr }
        memset(ioData?.pointee.mBuffers.mData, 0, Int(length))
        
        return status
    }
    
    let recordCallback: AURenderCallback = {
        (inRefCon: UnsafeMutableRawPointer,
         ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
         inTimeStamp:  UnsafePointer<AudioTimeStamp>,
         inBusNumber: UInt32,
         inNumberFrames: UInt32,
         ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        
        let sstp = unsafeBitCast(inRefCon, to: AzureSpeechAssessmentPlugin.self)
        
        var buffers = AudioBufferList(
            mNumberBuffers: 1,      //只需要一个音频缓冲
            mBuffers: AudioBuffer(
                mNumberChannels: 1, //声道数
                mDataByteSize: inNumberFrames * 2,
                mData: nil
            )
        )
        
        // 从输入 AUHAL 中检索捕获的样本
        let status = AudioUnitRender(
            sstp.remoteIOUnit!,
            ioActionFlags,
            inTimeStamp,
            inBusNumber,
            inNumberFrames,
            &buffers)
        guard status == noErr else {
            print("####################### AudioUnitRender error \(status)")
            return status
        }
        
        
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: AVAudioFrameCount(buffers.mBuffers.mDataByteSize / 2))!
        audioBuffer.frameLength = audioBuffer.frameCapacity
        
        guard let bufferData = buffers.mBuffers.mData else {
            print("####################### bufferData error")
            return status
        }
        
        memcpy(audioBuffer.int16ChannelData?[0], bufferData, Int(buffers.mBuffers.mDataByteSize))
        
        guard let audioformat = sstp.currentRequest?.nativeAudioFormat else {
            return status
        }
        sstp.currentRequest?.append(audioBuffer)
        
        return errno
    }
    
    
    //需要实例化的AudioUnit
    var remoteIOUnit: AudioUnit? = nil;
    let playVoiceCallback: AURenderCallback = {
        (inRefCon: UnsafeMutableRawPointer,
         ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
         inTimeStamp:  UnsafePointer<AudioTimeStamp>,
         inBusNumber: UInt32,
         inNumberFrames: UInt32,
         ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus in
        var status = noErr
        let this = unsafeBitCast(inRefCon, to: AzureSpeechAssessmentPlugin.self)
        
        if (!this.speeching) {
            return status
        }
        if (!this.speakPlusPlaying) {
            return status
        }
        
        guard let length = ioData?.pointee.mBuffers.mDataByteSize else { return noErr }
        
        if (this.speechStream != nil) {
            let bufferData: AudioBuffer = ioData!.pointee.mBuffers
            // guard let buffer = ioData?.pointee.mBuffers.mData else { return noErr }
            
            var data = NSMutableData(capacity: Int(length))
            if this.speechStream!.read(data!, length: UInt(length)) > 0 {
                // memset(ioData?.pointee.mBuffers.mData, 0, Int(length))
                // ioData?.pointee.mBuffers.mData = data!.mutableBytes
                memcpy(ioData?.pointee.mBuffers.mData, data!.mutableBytes, Int(length))
            } else {
                memset(ioData?.pointee.mBuffers.mData, 0, Int(length))
                this.speakTextPlusPlayEnd()
            }
        } else {
            memset(ioData?.pointee.mBuffers.mData, 0, Int(length))
        }
        
        return status
    }
    
    // 开启音频输出模式
    private func startAudio() {
        speeching = true
        // 1.1 创建AudioComponentDescription用来标识AudioUnit
        // AudioUnit描述
        var componentDesc = AudioComponentDescription();
        //AudioUnit的主类型
        componentDesc.componentType = kAudioUnitType_Output;
        //AudioUnit的子类型
        componentDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
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
        
        var disableFlag: UInt32 = 0
        var enableFlag: UInt32 = 1;
        
        //开启麦克风
        AudioUnitSetProperty(remoteIOUnit!,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             1,
                             &enableFlag,
                             UInt32(MemoryLayout<UInt32>.size))
        
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
        
        //        var cb = AURenderCallbackStruct(
        //                inputProc: renderCallback,
        //                inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        //        status = AudioUnitSetProperty(remoteIOUnit!,
        //                            kAudioUnitProperty_SetRenderCallback,
        //                            kAudioUnitScope_Output,
        //                            0,
        //                            &cb,
        //                            UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        //        if (status != 0) {
        //            print("####################### 设置采集回调失败 1")
        //            return
        //        }
        // 设置录音回调
        var recordCallbackStruct = AURenderCallbackStruct(
            inputProc: recordCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        
        status = AudioUnitSetProperty(remoteIOUnit!,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Output,
                                      0,
                                      &recordCallbackStruct,
                                      UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        if (status != 0) {
            print("speechResult ####################### 设置录音回调失败")
            return
        }
        
        // 设置播放回调
        var playVoiceCallbackStruct = AURenderCallbackStruct(inputProc: playVoiceCallback, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        status = AudioUnitSetProperty(remoteIOUnit!,
                                      kAudioUnitProperty_SetRenderCallback,
                                      kAudioUnitScope_Input,
                                      0,
                                      &playVoiceCallbackStruct,
                                      UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        if (status != 0) {
            print("speechResult ####################### 设置播放回调失败")
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
    
    // 初始化语音识别
    private func initializeRecognizer( _ result: @escaping FlutterResult) {
        var success = false
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case SFSpeechRecognizerAuthorizationStatus.notDetermined:
            SFSpeechRecognizer.requestAuthorization({(status)->Void in
                success = status == SFSpeechRecognizerAuthorizationStatus.authorized
                if ( success ) {
                    self.audioSession.requestRecordPermission({(granted: Bool)-> Void in
                        if granted {
                            self.setupSpeechRecognition(result)
                        } else{
                            self.sendBoolResult( false, result );
                        }
                    })
                }
                else {
                    self.sendBoolResult( false, result );
                }
            });
        case SFSpeechRecognizerAuthorizationStatus.denied:
            sendBoolResult( false, result );
        case SFSpeechRecognizerAuthorizationStatus.restricted:
            sendBoolResult( false, result );
        default:
            setupSpeechRecognition(result)
        }
    }
    
    private func setupSpeechRecognition( _ result: @escaping FlutterResult) {
        setupRecognizerForLocale( locale: Locale.current )
        guard recognizer != nil else {
            sendBoolResult( false, result );
            return
        }
        
        recognizer?.delegate = self
    }
    
    private func setupRecognizerForLocale( locale: Locale ) {
        if ( previousLocale == locale ) {
            return
        }
        previousLocale = locale
        recognizer = SFSpeechRecognizer( locale: locale )
    }
    
    private var recognizer: SFSpeechRecognizer?
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var currentTask: SFSpeechRecognitionTask?
    private var returnPartialResults: Bool = true
    private let jsonEncoder = JSONEncoder()
    private var previousLocale: Locale?
    
    fileprivate func sendBoolResult( _ value: Bool, _ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            result( value )
        }
    }
    
    // 停止系统的语音转文字
    public func recognizerStop( _ result: @escaping FlutterResult) {
        currentRequest?.endAudio()
        currentTask?.finish()
        currentTask = nil
        currentRequest = nil
        sendBoolResult( true, result );
        print("recognizerStop \(String(describing: currentTask))")
    }
    
    // 开始系统的语音转文字
    public func recognizerStart(_ result: @escaping FlutterResult, localeStr: String?, partialResults: Bool, onDevice: Bool, listenMode: ListenMode) {
        if ( nil != currentTask) {
            print("recognizerStart currentTask is not nil. \(String(describing: currentTask))")
            currentRequest?.endAudio()
            currentTask?.finish()
            currentTask = nil
            currentRequest = nil
        }
        
        returnPartialResults = partialResults
        guard let localRecognizer = recognizer else {
            print("Failed to create speech recognizer")
            return
        }
        if ( onDevice ) {
            if #available(iOS 13.0, *), !localRecognizer.supportsOnDeviceRecognition {
                print("Failed to create speech recognizer, on device recognition is not supported on this device")
                result(FlutterError( code: "onDeviceError",
                                     message:"on device recognition is not supported on this device",
                                     details: nil ))
            }
        }
        
        self.currentRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let currentRequest = self.currentRequest else {
            sendBoolResult( false, result );
            print("listenPlusStartSpeech currentTask init error")
            return
        }
        currentRequest.shouldReportPartialResults = true
        if #available(iOS 13.0, *), onDevice {
            currentRequest.requiresOnDeviceRecognition = true
        }
        switch listenMode {
        case ListenMode.dictation:
            currentRequest.taskHint = SFSpeechRecognitionTaskHint.dictation
            break
        case ListenMode.search:
            currentRequest.taskHint = SFSpeechRecognitionTaskHint.search
            break
        case ListenMode.confirmation:
            currentRequest.taskHint = SFSpeechRecognitionTaskHint.confirmation
            break
        default:
            break
        }
        
        self.currentTask = self.recognizer?.recognitionTask(with: currentRequest, delegate: self )
        
        print("listenPlusStartSpeech currentTask init complete \(String(describing: recognizer))")
        
        sendBoolResult( true, result );
        
    }
    
    
    private func handleResult( _ transcriptions: [SFTranscription], isFinal: Bool ) {
        if ( !isFinal && !returnPartialResults ) {
            return
        }
        var speechWords: [SpeechRecognitionWords] = []
        for transcription in transcriptions {
            let words: SpeechRecognitionWords = SpeechRecognitionWords(recognizedWords: transcription.formattedString, confidence: confidenceIn( transcription))
            speechWords.append( words )
        }
        let speechInfo = SpeechRecognitionResult(alternates: speechWords, finalResult: isFinal )
        do {
            let speechMsg = try jsonEncoder.encode(speechInfo)
            if let speechStr = String( data:speechMsg, encoding: .utf8) {
                print("speech.OnRecognition Encoded JSON result: \(speechStr)")
                invokeFlutter( "speech.OnRecognition", arguments: speechStr )
            }
        } catch {
            print("Could not encode JSON \(error)")
        }
    }
    
    private func confidenceIn( _ transcription: SFTranscription ) -> Decimal {
        guard ( transcription.segments.count > 0 ) else {
            return 0;
        }
        var totalConfidence: Float = 0.0;
        for segment in transcription.segments {
            totalConfidence += segment.confidence
        }
        let avgConfidence: Float = totalConfidence / Float(transcription.segments.count )
        let confidence: Float = (avgConfidence * 1000).rounded() / 1000
        return Decimal( string: String( describing: confidence ) )!
    }
    
    
    private func invokeFlutter( _ callbackMethod: String, arguments: Any? ) {
        DispatchQueue.main.async {
            self.azureChannel.invokeMethod(callbackMethod, arguments: arguments )
        }
    }
}

@available(iOS 10.0, *)
extension AzureSpeechAssessmentPlugin : SFSpeechRecognizerDelegate {
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        //        let availability = available ? SpeechToTextStatus.available.rawValue : SpeechToTextStatus.unavailable.rawValue
        //        invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: availability )
    }
}

@available(iOS 10.0, *)
extension AzureSpeechAssessmentPlugin : SFSpeechRecognitionTaskDelegate {
    public func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        // Do nothing for now
        reportError(source: "speechRecognitionDidDetectSpeech", error: task.error)
    }
    
    public func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        reportError(source: "FinishedReadingAudio", error: task.error)
        // invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.notListening.rawValue )
    }
    
    public func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        reportError(source: "TaskWasCancelled", error: task.error)
        // invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.notListening.rawValue )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        reportError(source: "FinishSuccessfully", error: task.error)
        if ( !successfully ) {
            // invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyStatus, arguments: SpeechToTextStatus.doneNoResult.rawValue )
            if let err = task.error as NSError? {
                var errorMsg: String
                switch err.code {
                case 201:
                    errorMsg = "error_speech_recognizer_disabled"
                case 203:
                    errorMsg = "error_retry"
                case 1110:
                    errorMsg = "error_no_match"
                default:
                    errorMsg = "error_unknown (\(err.code))"
                }
                let speechError = SpeechRecognitionError(errorMsg: errorMsg, permanent: true )
                do {
                    let errorResult = try jsonEncoder.encode(speechError)
                    // invokeFlutter( SwiftSpeechToTextCallbackMethods.notifyError, arguments: String(data:errorResult, encoding: .utf8) )
                    print("speechError \(errorResult) ")
                } catch {
                    print("Could not encode JSON ")
                }
            }
        }
        // stopCurrentListen( )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        reportError(source: "HypothesizeTranscription", error: task.error)
        handleResult( [transcription], isFinal: false )
    }
    
    public func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        reportError(source: "FinishRecognition", error: task.error)
        let isFinal = recognitionResult.isFinal
        handleResult( recognitionResult.transcriptions, isFinal: isFinal )
    }
    
    private func reportError( source: String, error: Error?) {
        if ( nil != error) {
            print("\(source) \(String(describing: error))")
        }
    }
}
