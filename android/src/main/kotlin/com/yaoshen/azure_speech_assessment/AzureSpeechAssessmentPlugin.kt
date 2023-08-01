package com.yaoshen.azure_speech_assessment;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import com.microsoft.cognitiveservices.speech.audio.AudioConfig;
import com.microsoft.cognitiveservices.speech.intent.LanguageUnderstandingModel;
import com.microsoft.cognitiveservices.speech.intent.IntentRecognitionResult;
import com.microsoft.cognitiveservices.speech.intent.IntentRecognizer;
import com.yaoshen.azure_speech_assessment.MicrophoneStream;
import com.microsoft.cognitiveservices.speech.PronunciationAssessmentConfig;
import android.app.Activity;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.Callable;
import android.os.Handler;
import android.os.Looper;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
//import androidx.core.app.ActivityCompat;
import java.net.URI;
import android.util.Log;
import android.text.TextUtils;
import com.microsoft.cognitiveservices.speech.*

import java.util.concurrent.Semaphore 

/** AzureSpeechAssessmentPlugin */
public class AzureSpeechAssessmentPlugin: FlutterPlugin, Activity(),MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var azureChannel : MethodChannel;
  private var microphoneStream : MicrophoneStream? = null;
  private  lateinit var handler : Handler;
  var continuousListeningStarted : Boolean = false;
  lateinit var  reco : SpeechRecognizer;
  var enableDictation : Boolean = false;
  private fun createMicrophoneStream() : MicrophoneStream{
    if (microphoneStream != null) {
        microphoneStream!!.close();
        microphoneStream = null;
    }

    microphoneStream = MicrophoneStream();
    return microphoneStream!!;
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    azureChannel = MethodChannel(flutterPluginBinding.getFlutterEngine().getDartExecutor(), "azure_speech_recognition")
    azureChannel.setMethodCallHandler(this);
    
  }

  init{
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "azure_speech_recognition")

      this.azureChannel = MethodChannel(registrar.messenger(), "azure_speech_recognition");
      this.azureChannel.setMethodCallHandler(this);
    }

    handler = Handler(Looper.getMainLooper());
  }

  /*companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "azure_speech_recognition")
      channel.setMethodCallHandler(AzureSpeechRecognitionPlugin(registrar.activity(),channel))
    }
  }

  init{
    this.azureChannel = channel;
    this.azureChannel.setMethodCallHandler(this);

    handler = Handler(Looper.getMainLooper());
  }*/


  fun getAudioConfig() : AudioConfig {
    return AudioConfig.fromDefaultMicrophoneInput();
  }


  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if(call.method == "simpleVoice"){
      //_result = result;
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var lang : String = ""+call.argument("language");
      var timeoutMs : String = ""+call.argument("timeout");

      simpleSpeechRecognition(speechSubscriptionKey,serviceRegion,lang,timeoutMs);
      result.success(true);

    }else if(call.method == "micStream"){
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var lang : String = ""+call.argument("language");


      micStreamRecognition(speechSubscriptionKey,serviceRegion,lang);
      result.success(true);

    }else if(call.method == "continuousStream"){
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var lang : String =  ""+call.argument("language");


      micStreamContinuosly(speechSubscriptionKey,serviceRegion,lang);
      result.success(true);

    }else if(call.method == "dictationMode"){
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var lang : String =  ""+call.argument("language");

      enableDictation = true;
      micStreamContinuosly(speechSubscriptionKey,serviceRegion,lang);
      result.success(true);

    }
    else if(call.method == "intentRecognizer"){
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var appId : String= ""+call.argument("appId");
      var lang : String =  ""+call.argument("language");


      recognizeIntent(speechSubscriptionKey,serviceRegion,appId,lang);
      result.success(true);

    }else if(call.method == "keywordRecognizer"){
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var lang : String =  ""+call.argument("language");
      var kwsModel : String = ""+call.argument("kwsModel");

      keywordRecognizer(speechSubscriptionKey, serviceRegion, lang, kwsModel);
      result.success(true);

    }else if(call.method == "simpleVoicePlus"){
      //_result = result;
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var lang : String = ""+call.argument("language");
      var timeoutMs : String = ""+call.argument("timeout");

      simpleSpeechRecognitionPlus(speechSubscriptionKey,serviceRegion,lang,timeoutMs);
      result.success(true);

    }else if(call.method == "soundRecord"){
      //_result = result;
      var permissionRequestId : Int = 5;
      var speechSubscriptionKey : String = ""+call.argument("subscriptionKey");
      var serviceRegion : String= ""+call.argument("region");
      var lang : String = ""+call.argument("language");
      var timeoutMs : String = ""+call.argument("timeout");
      var path : String = ""+call.argument("path");
      print("soundRecord called");

      soundRecord(speechSubscriptionKey,serviceRegion,lang,timeoutMs,path);
      result.success(true);

    }
    else{
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    azureChannel.setMethodCallHandler(null)
  }

  fun simpleSpeechRecognition(speechSubscriptionKey:String,serviceRegion:String,lang:String,timeoutMs:String) {
    val logTag : String = "simpleVoice";


    try{
      
      var audioInput : AudioConfig = AudioConfig.fromStreamInput(createMicrophoneStream());

      var config : SpeechConfig = SpeechConfig.fromSubscription(speechSubscriptionKey, serviceRegion); 
      assert(config != null);

      config.speechRecognitionLanguage = lang;
      config.setProperty(PropertyId.Speech_SegmentationSilenceTimeoutMs, timeoutMs);

      var reco : SpeechRecognizer = SpeechRecognizer(config,audioInput);

      assert(reco != null);

      var task : Future<SpeechRecognitionResult> = reco.recognizeOnceAsync();

      assert(task != null);

      invokeMethod("speech.onRecognitionStarted",null);

      setOnTaskCompletedListener(task, { result ->
        val s = result.getText()
        Log.i(logTag, "Recognizer returned: " + s)
        if (result.getReason() == ResultReason.RecognizedSpeech) {
          invokeMethod("speech.onFinalResponse",s);
        }
        else {
          invokeMethod("speech.onFinalResponse","");
        }

        reco.close()

      })

    }catch(exec:Exception){
      assert(false);
      invokeMethod("speech.onException", "Exception: "+exec.message);

    }
  }

  // Mic Streaming, it need the additional method implementend to get the data from the async task
  fun micStreamRecognition(speechSubscriptionKey:String,serviceRegion:String,lang:String){
    val logTag : String = "micStream";

    try{
      
      var audioInput : AudioConfig = AudioConfig.fromStreamInput(createMicrophoneStream());


      var config : SpeechConfig = SpeechConfig.fromSubscription(speechSubscriptionKey, serviceRegion); 
      assert(config != null);

      config.speechRecognitionLanguage = lang;

      var reco : SpeechRecognizer = SpeechRecognizer(config,audioInput);

      assert(reco != null);

      invokeMethod("speech.onRecognitionStarted",null);

      reco.recognizing.addEventListener({ o, speechRecognitionResultEventArgs->
        val s = speechRecognitionResultEventArgs.getResult().getText()
        //Log.i(logTag, "Intermediate result received: " + s)
        invokeMethod("speech.onSpeech",s);
      });
      
  
      val task : Future<SpeechRecognitionResult> = reco.recognizeOnceAsync();


      setOnTaskCompletedListener(task, { result ->
        val s = result.getText()
        reco.close()
        //Log.i(logTag, "Recognizer returned: " + s)
        invokeMethod("speech.onFinalResponse",s);
      })

    }catch(exec:Exception){
      assert(false);
      invokeMethod("speech.onException", "Exception: "+exec.message);
    }
  }



  // stream continuosly until you press the button to stop ! STILL NOT WORKING COMPLETELY

  fun micStreamContinuosly(speechSubscriptionKey:String,serviceRegion:String,lang:String){
    val logTag : String = "micStreamContinuos";
    
    
    lateinit var  audioInput : AudioConfig;
    var content :  ArrayList<String> = ArrayList<String>();


    Log.i(logTag, "StatoRiconoscimentoVocale: " + continuousListeningStarted);

    if(continuousListeningStarted){
      if(reco != null){
        val _task1  = reco.stopContinuousRecognitionAsync();

        setOnTaskCompletedListener(_task1, { result ->
          Log.i(logTag, "Continuous recognition stopped.");
          continuousListeningStarted = false;
          invokeMethod("speech.onRecognitionStopped",null);
                reco.close();

        })
      }else{
        continuousListeningStarted = false;
      }
      

      return;
    }
    
    content.clear();

    try{
      
      //audioInput = AudioConfig.fromStreamInput(createMicrophoneStream());


      var config : SpeechConfig = SpeechConfig.fromSubscription(speechSubscriptionKey, serviceRegion); 
      assert(config != null);

      config.speechRecognitionLanguage = lang;

      if(enableDictation){
        Log.i(logTag, "Enabled BF dictation");
        config.enableDictation();
        Log.i(logTag, "Enabled AF dictation");

      }

      reco = SpeechRecognizer(config,getAudioConfig());

      assert(reco != null);


      

      reco.recognizing.addEventListener({ o, speechRecognitionResultEventArgs->
        val s = speechRecognitionResultEventArgs.getResult().getText()
        content.add(s);
        Log.i(logTag, "Intermediate result received: " + s)
        invokeMethod("speech.onSpeech",s);
        content.removeAt(content.size - 1);
      });

      reco.recognized.addEventListener({ o, speechRecognitionResultEventArgs->
        val s = speechRecognitionResultEventArgs.getResult().getText()
        content.add(s);
        Log.i(logTag, "Final result received: " + s)
        invokeMethod("speech.onFinalResponse",s);
      });
      
  
      val _task2 = reco.startContinuousRecognitionAsync();

      setOnTaskCompletedListener(_task2, { result ->
        continuousListeningStarted = true;
        invokeMethod("speech.onRecognitionStarted",null);

        //invokeMethod("speech.onStopAvailable",null);
      })
      

    }catch(exec:Exception){
      assert(false);
      invokeMethod("speech.onException", "Exception: "+exec.message);

    }
  }





  /// Recognize Intent method from microsoft sdk

  fun recognizeIntent(speechSubscriptionKey:String,serviceRegion:String,appId:String,lang:String){
    val logTag : String = "intent";

    var content :  ArrayList<String> = ArrayList<String>();

    content.add("");
    content.add("");

    try{
       
      val audioInput = AudioConfig.fromStreamInput(createMicrophoneStream());


      var config : SpeechConfig = SpeechConfig.fromSubscription(speechSubscriptionKey, serviceRegion); 

      assert(config != null);

      config.speechRecognitionLanguage = lang;

      val reco = IntentRecognizer(config,audioInput);

      var intentModel : LanguageUnderstandingModel = LanguageUnderstandingModel.fromAppId(appId);
      reco.addAllIntents(intentModel);

      reco.recognizing.addEventListener({ o, intentRecognitionResultEventArgs->
        val s = intentRecognitionResultEventArgs.getResult().getText()
        content.set(0,s);
        Log.i(logTag, "Final result received: " + s)
        invokeMethod("speech.onFinalResponse",TextUtils.join(System.lineSeparator(), content));
      });
      
      
      val task : Future<IntentRecognitionResult> = reco.recognizeOnceAsync();

      

      setOnTaskCompletedListener(task, { result ->
        Log.i(logTag, "Continuous recognition stopped.");

        var s = result.getText();

        if (result.getReason() != ResultReason.RecognizedIntent) {
          var errorDetails = if(result.getReason() == ResultReason.Canceled) CancellationDetails.fromResult(result).getErrorDetails() else "";
          s = "Intent failed with " + result.getReason() + ". Did you enter your Language Understanding subscription?" + System.lineSeparator() + errorDetails;
        } 

        var intentId = result.getIntentId();


        content.set(0,s);
        content.set(1,"[intent: "+intentId+" ]");

        invokeMethod("speech.onSpeech",TextUtils.join(System.lineSeparator(), content));
        println("Stopped");
      })



    }catch(exec:Exception){
      //Log.e("SpeechSDKDemo", "unexpected " + exec.message);
      assert(false);
      invokeMethod("speech.onException", "Exception: "+exec.message);
    }
  }

  fun keywordRecognizer(speechSubscriptionKey:String,serviceRegion:String,lang:String,kwsModelFile:String) {
    val logTag : String = "keyword";
    var continuousListeningStarted : Boolean = false;
    lateinit var reco : SpeechRecognizer;
    lateinit var audioInput : AudioConfig;
    var content :  ArrayList<String> = ArrayList<String>();




    if(continuousListeningStarted) {
      if(reco != null){
        val task : Future<Void> = reco.stopContinuousRecognitionAsync();

        setOnTaskCompletedListener(task, { result ->
          Log.i(logTag, "Continuous recognition stopped.");
          continuousListeningStarted = false;
          azureChannel.invokeMethod("speech.onStartAvailable",null);
        })

      }else{
        continuousListeningStarted = false;
      }

      return;
    }
    
    content.clear();
    try{

      audioInput = AudioConfig.fromStreamInput(createMicrophoneStream());

      var config : SpeechConfig = SpeechConfig.fromSubscription(speechSubscriptionKey, serviceRegion); 

      assert(config != null);

      config.speechRecognitionLanguage = lang;

      reco = SpeechRecognizer(config,audioInput); 

      reco.recognizing.addEventListener({ o, speechRecognitionResultEventArgs->
        val s = speechRecognitionResultEventArgs.getResult().getText()
        content.add(s);
        Log.i(logTag, "Intermediate result received: " + s)
        invokeMethod("speech.onSpeech",TextUtils.join(" ", content));
        content.removeAt(content.size - 1);
      });

      reco.recognizing.addEventListener({ o, speechRecognitionResultEventArgs->
        var s: String;
        if (speechRecognitionResultEventArgs.getResult().getReason() == ResultReason.RecognizedKeyword)
          {
              s = "Keyword: " + speechRecognitionResultEventArgs.getResult().getText();
              Log.i(logTag, "Keyword recognized result received: " + s);
          }
          else
          {
              s = "Recognized: " + speechRecognitionResultEventArgs.getResult().getText();
              Log.i(logTag, "Final result received: " + s);
          }
          content.add(s);
        invokeMethod("speech.onSpeech",s);
      });
      
      var kwsModel = KeywordRecognitionModel.fromFile(copyAssetToCacheAndGetFilePath(kwsModelFile));
      val task : Future<Void> = reco.startKeywordRecognitionAsync(kwsModel);

      
      setOnTaskCompletedListener(task, { result ->
        continuousListeningStarted = true;

        invokeMethod("speech.onStopAvailable",null);
        println("Stopped");
      })


    }catch(exc:Exception){

    }
  } 


    /**
 * 执行一次语音识别操作
 *
 * @param speechSubscriptionKey Azure 语音服务订阅密钥
 * @param serviceRegion Azure 语音服务区域
 * @param lang 语音识别语言
 * @param timeoutMs 分段静默超时时间
 */
fun simpleSpeechRecognitionPlus(speechSubscriptionKey: String, serviceRegion: String, lang: String, timeoutMs: String) {
    // 创建用于日志输出的标签
    val logTag: String = "simpleVoicePlus"

    try {
        // 从麦克风创建 AudioConfig 对象，用于配置语音识别的音频输入
        var audioInput: AudioConfig = AudioConfig.fromStreamInput(createMicrophoneStream())

        // 从 Azure 语音服务订阅密钥和服务区域创建 SpeechConfig 对象，用于配置语音识别的参数
        var config: SpeechConfig = SpeechConfig.fromSubscription(speechSubscriptionKey, serviceRegion)
        // 如果 SpeechConfig 对象创建失败，则会抛出异常
        assert(config != null)

        // 设置语音识别的语言和分段静默超时时间
        config.speechRecognitionLanguage = lang
        config.setProperty(PropertyId.Speech_SegmentationSilenceTimeoutMs, timeoutMs)

        // 从 SpeechConfig 和 AudioConfig 对象创建 SpeechRecognizer 对象，用于执行语音识别操作
        var reco: SpeechRecognizer = SpeechRecognizer(config, audioInput)
        // 如果 SpeechRecognizer 对象创建失败，则会抛出异常
        assert(reco != null)

        val gradingSystem = PronunciationAssessmentGradingSystem.HundredMark
        val granularity = PronunciationAssessmentGranularity.Phoneme
        // 创建语音评估对象
        val pronunciationAssessmentConfig = PronunciationAssessmentConfig("",gradingSystem,granularity,true)
        pronunciationAssessmentConfig.setPhonemeAlphabet("IPA")
        // 设置语音评估对象
        pronunciationAssessmentConfig.applyTo(reco);

        // 调用 recognizeOnceAsync() 方法执行一次语音识别操作，并返回一个 Future<SpeechRecognitionResult> 对象，表示异步操作的结果
        var task: Future<SpeechRecognitionResult> = reco.recognizeOnceAsync()
        // 如果异步操作失败，则会抛出异常
        assert(task != null)

        // 通知 Flutter 界面语音识别已经开始
        invokeMethod("speech.onRecognitionStarted", null)


        // 等待语音识别操作完成，并在语音识别完成后执行回调函数
        setOnTaskCompletedListener(task, { result ->
            // 获取语音识别结果
            val s = result.getText()
            Log.i(logTag, "Recognizer returned: " + s)

            // 将语音识别结果传递给语音评估对象
            pronunciationAssessmentConfig.setReferenceText(s)


            // 获取语音评估结果
            var pronunciationAssessmentResultJson = result.getProperties().getProperty(PropertyId.SpeechServiceResponse_JsonResult).toString();
            //.getProperty(PropertyId.SpeechServiceResponse_JsonResult)
            Log.i(logTag, "Pronunciation assessment result: " + pronunciationAssessmentResultJson);

            
            
            // 如果语音识别成功，则将识别结果传递给 Flutter 界面
            if (result.getReason() == ResultReason.RecognizedSpeech) {
                invokeMethod("speech.onFinalResponse", s);
                invokeMethod("speech.onFinalAssessment", pronunciationAssessmentResultJson);
            } else {
                // 如果语音识别失败，则将空字符串传递给 Flutter 界面
                invokeMethod("speech.onFinalResponse", "");
            }

            // 关闭 SpeechRecognizer 对象
            reco.close()
            pronunciationAssessmentConfig.close();
            audioInput.close();
            config.close();

        })

    } catch (exec: Exception) {
        // 如果在语音识别过程中发生异常，则将异常信息传递给 Flutter 界面
        assert(false)
        invokeMethod("speech.onException", "Exception: " + exec.message)

    }
}

fun soundRecord(speechSubscriptionKey: String, serviceRegion: String, lang: String, timeoutMs: String, path: String) {
  // 创建用于日志输出的标签
  val logTag: String = "soundRecord"

  Log.i(logTag, "path:" + path);

  try {
      // 从麦克风创建 AudioConfig 对象，用于配置语音识别的音频输入
      var audioInput: AudioConfig = AudioConfig.fromWavFileInput(path);

      // 从 Azure 语音服务订阅密钥和服务区域创建 SpeechConfig 对象，用于配置语音识别的参数
      var config: SpeechConfig = SpeechConfig.fromSubscription(speechSubscriptionKey, serviceRegion)
      // 如果 SpeechConfig 对象创建失败，则会抛出异常
      assert(config != null)

      // 设置语音识别的语言和分段静默超时时间
      config.speechRecognitionLanguage = lang
      //config.setProperty(PropertyId.Speech_SegmentationSilenceTimeoutMs, timeoutMs)

      // 从 SpeechConfig 和 AudioConfig 对象创建 SpeechRecognizer 对象，用于执行语音识别操作
      var reco: SpeechRecognizer = SpeechRecognizer(config, audioInput)
      // 如果 SpeechRecognizer 对象创建失败，则会抛出异常
      assert(reco != null)

      val gradingSystem = PronunciationAssessmentGradingSystem.HundredMark
      val granularity = PronunciationAssessmentGranularity.Phoneme
      // 创建语音评估对象
      val pronunciationAssessmentConfig = PronunciationAssessmentConfig("",gradingSystem,granularity,true)
      pronunciationAssessmentConfig.setPhonemeAlphabet("IPA")
      // 设置语音评估对象
      pronunciationAssessmentConfig.applyTo(reco);

      // 调用 recognizeOnceAsync() 方法执行一次语音识别操作，并返回一个 Future<SpeechRecognitionResult> 对象，表示异步操作的结果
      var task: Future<SpeechRecognitionResult> = reco.recognizeOnceAsync()
      // 如果异步操作失败，则会抛出异常
      assert(task != null)

      // 通知 Flutter 界面语音识别已经开始
      invokeMethod("speech.onRecognitionStarted", null)


      // 等待语音识别操作完成，并在语音识别完成后执行回调函数
      setOnTaskCompletedListener(task, { result ->
          // 获取语音识别结果
          val s = result.getText()
          Log.i(logTag, "Recognizer returned: " + s)

          // 将语音识别结果传递给语音评估对象
          pronunciationAssessmentConfig.setReferenceText(s)


          // 获取语音评估结果
          var pronunciationAssessmentResultJson = result.getProperties().getProperty(PropertyId.SpeechServiceResponse_JsonResult).toString();
          //.getProperty(PropertyId.SpeechServiceResponse_JsonResult)
          Log.i(logTag, "Pronunciation assessment result: " + pronunciationAssessmentResultJson);

          
          
          // 如果语音识别成功，则将识别结果传递给 Flutter 界面
          if (result.getReason() == ResultReason.RecognizedSpeech) {
              invokeMethod("speech.onFinalResponse", s);
              invokeMethod("speech.onFinalAssessment", pronunciationAssessmentResultJson);
          } else {
              // 如果语音识别失败，则将空字符串传递给 Flutter 界面
              invokeMethod("speech.onFinalResponse", "failed");
              invokeMethod("speech.onFinalAssessment", "failed");
          }

          // 关闭 SpeechRecognizer 对象
          reco.close()
          pronunciationAssessmentConfig.close();
          audioInput.close();
          config.close();

      })

  } catch (exec: Exception) {
      // 如果在语音识别过程中发生异常，则将异常信息传递给 Flutter 界面
      assert(false)
      invokeMethod("speech.onException", "Exception: " + exec.message)

  }
}

       




   private val s_executorService : ExecutorService = Executors.newCachedThreadPool();



  
  
   private fun <T> setOnTaskCompletedListener(task:Future<T>, listener: (T) -> Unit){
    s_executorService.submit({ 
      val result = task.get()
      listener(result)
    });
  }


  private interface OnTaskCompletedListener<T> {
    fun onCompleted(taskResult : T);
  }

  private fun setRecognizedText (s : String) {
    azureChannel.invokeMethod("speech.onSpeech",s);
  }

  private fun invokeMethod(method:String, arguments:Any?){

    handler.post{
        azureChannel.invokeMethod(method,arguments); 
    }
  }


  private fun copyAssetToCacheAndGetFilePath(filename : String) : String{
    var cacheFile : File = File(""+ getCacheDir() + "/" + filename);
    if (!cacheFile.exists()) {
        try {
            var iS : InputStream = getAssets().open(filename);
            val size : Int = iS.available();
            var buffer : ByteArray = ByteArray(size);
            iS.read(buffer);
            iS.close();
            var fos:FileOutputStream = FileOutputStream(cacheFile);
            fos.write(buffer);
            fos.close();
        }
        catch (e:Exception) {
            throw RuntimeException(e);
        }
    }
    return cacheFile.getPath();
  }
}
