package com.fastkirana.app

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fastkirana.app/voice_search"
    private var speechRecognizer: SpeechRecognizer? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    val available = SpeechRecognizer.isRecognitionAvailable(this)
                    result.success(available)
                }
                "startListening" -> {
                    startNativeListening(result)
                }
                "stopListening" -> {
                    stopNativeListening()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startNativeListening(result: MethodChannel.Result) {
        runOnUiThread {
            try {
                if (speechRecognizer != null) {
                    speechRecognizer?.destroy()
                    speechRecognizer = null
                }

                if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                    result.error("UNAVAILABLE", "Speech recognition not available on device", null)
                    return@runOnUiThread
                }

                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "en-IN")
                    putExtra(RecognizerIntent.EXTRA_SUPPORTED_LANGUAGES, arrayListOf("en-IN", "en-US", "hi-IN"))
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                }

                speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        methodChannel?.invokeMethod("onStatus", "listening")
                    }

                    override fun onBeginningOfSpeech() {
                        methodChannel?.invokeMethod("onStatus", "speaking")
                    }

                    override fun onRmsChanged(rmsdB: Float) {}
                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        methodChannel?.invokeMethod("onStatus", "processing")
                    }

                    override fun onError(error: Int) {
                        methodChannel?.invokeMethod("onError", "Error code: $error")
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        methodChannel?.invokeMethod("onFinalResult", text)
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        if (text.isNotEmpty()) {
                            methodChannel?.invokeMethod("onPartialResult", text)
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })

                speechRecognizer?.startListening(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("EXCEPTION", e.message, null)
            }
        }
    }

    private fun stopNativeListening() {
        runOnUiThread {
            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
                speechRecognizer = null
            } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        stopNativeListening()
        super.onDestroy()
    }
}
