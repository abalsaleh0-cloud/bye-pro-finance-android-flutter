package com.example.expense_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.RecognitionListener
import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private companion object {
        const val VOICE_CHANNEL = "com.byepro.finance/assistant_voice"
        const val MICROPHONE_PERMISSION_REQUEST = 9142
    }

    private var pendingSpeechResult: MethodChannel.Result? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var ttsInitializing = false
    private var ttsInitialized = false
    private var offlineArabicVoice: Voice? = null
    private val ttsWaiters = mutableListOf<(Boolean) -> Unit>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognizeArabicSpeech" -> recognizeArabicSpeech(result)
                    "cancelArabicSpeechRecognition" -> {
                        speechRecognizer?.cancel()
                        finishSpeechWithError("speech_cancelled", "Speech recognition was cancelled.")
                        result.success(null)
                    }
                    "hasOfflineArabicTts" -> ensureOfflineArabicTts { available ->
                        result.success(available)
                    }
                    "speakArabic" -> {
                        val text = call.argument<String>("text")?.trim().orEmpty()
                        if (text.isEmpty()) {
                            result.error("empty_speech", "Speech text is empty.", null)
                        } else {
                            ensureOfflineArabicTts { available ->
                                if (!available) {
                                    result.error(
                                        "arabic_tts_unavailable",
                                        "No offline Arabic text-to-speech voice is installed.",
                                        null
                                    )
                                } else {
                                    val status = tts?.speak(
                                        text,
                                        TextToSpeech.QUEUE_FLUSH,
                                        null,
                                        "bye-pro-assistant-reply"
                                    ) ?: TextToSpeech.ERROR
                                    if (status == TextToSpeech.ERROR) {
                                        result.error("speech_output_failed", "Unable to start speech output.", null)
                                    } else {
                                        result.success(true)
                                    }
                                }
                            }
                        }
                    }
                    "stopSpeaking" -> {
                        tts?.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun recognizeArabicSpeech(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
        ) {
            result.error(
                "offline_speech_unavailable",
                "On-device speech recognition is not available on this device.",
                null
            )
            return
        }

        if (pendingSpeechResult != null) {
            result.error("speech_busy", "Speech recognition is already running.", null)
            return
        }

        pendingSpeechResult = result
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                arrayOf(Manifest.permission.RECORD_AUDIO),
                MICROPHONE_PERMISSION_REQUEST
            )
            return
        }

        beginArabicSpeechRecognition()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != MICROPHONE_PERMISSION_REQUEST) return

        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            beginArabicSpeechRecognition()
        } else {
            finishSpeechWithError("permission_denied", "Microphone permission was denied.")
        }
    }

    private fun beginArabicSpeechRecognition() {
        if (pendingSpeechResult == null) return

        try {
            val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            speechRecognizer = recognizer
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onPartialResults(partialResults: Bundle?) = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit

                override fun onError(error: Int) {
                    val code = if (
                        error == SpeechRecognizer.ERROR_NO_MATCH ||
                        error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
                    ) {
                        "speech_no_match"
                    } else {
                        "speech_failed"
                    }
                    finishSpeechWithError(code, "Arabic speech could not be recognized.")
                }

                override fun onResults(results: Bundle?) {
                    val recognized = results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        ?.trim()
                        .orEmpty()
                    if (recognized.isEmpty()) {
                        finishSpeechWithError("speech_no_match", "No speech was recognized.")
                    } else {
                        finishSpeechWithSuccess(recognized)
                    }
                }
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ar")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "ar")
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                recognizer.checkRecognitionSupport(
                    intent,
                    mainExecutor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                            val hasInstalledArabic = recognitionSupport.installedOnDeviceLanguages
                                .any { Locale.forLanguageTag(it).language.equals("ar", ignoreCase = true) }
                            if (hasInstalledArabic) {
                                recognizer.startListening(intent)
                            } else {
                                finishSpeechWithError(
                                    "arabic_language_unavailable",
                                    "An offline Arabic speech model is not installed."
                                )
                            }
                        }

                        override fun onError(error: Int) {
                            finishSpeechWithError(
                                "arabic_language_unavailable",
                                "Offline Arabic speech support could not be verified."
                            )
                        }
                    }
                )
            } else {
                recognizer.startListening(intent)
            }
        } catch (_: UnsupportedOperationException) {
            finishSpeechWithError(
                "offline_speech_unavailable",
                "On-device speech recognition is not available on this device."
            )
        } catch (_: SecurityException) {
            finishSpeechWithError("permission_denied", "Microphone permission is required.")
        } catch (_: Exception) {
            finishSpeechWithError("speech_failed", "Unable to start speech recognition.")
        }
    }

    private fun finishSpeechWithSuccess(text: String) {
        val result = pendingSpeechResult
        pendingSpeechResult = null
        releaseSpeechRecognizer()
        result?.success(text)
    }

    private fun finishSpeechWithError(code: String, message: String) {
        val result = pendingSpeechResult
        pendingSpeechResult = null
        releaseSpeechRecognizer()
        result?.error(code, message, null)
    }

    private fun releaseSpeechRecognizer() {
        val recognizer = speechRecognizer
        speechRecognizer = null
        recognizer?.destroy()
    }

    private fun ensureOfflineArabicTts(onReady: (Boolean) -> Unit) {
        if (ttsInitialized) {
            onReady(offlineArabicVoice != null)
            return
        }

        ttsWaiters.add(onReady)
        if (ttsInitializing) return

        ttsInitializing = true
        tts = TextToSpeech(this) { status ->
            val engine = tts
            if (status == TextToSpeech.SUCCESS && engine != null) {
                offlineArabicVoice = engine.voices
                    ?.filter {
                        it.locale.language.equals("ar", ignoreCase = true) &&
                            !it.isNetworkConnectionRequired
                    }
                    ?.sortedBy {
                        if (it.locale.country.equals("LY", ignoreCase = true)) 0 else 1
                    }
                    ?.firstOrNull()

                offlineArabicVoice?.let(engine::setVoice)
            }

            ttsInitialized = true
            ttsInitializing = false
            val waiters = ttsWaiters.toList()
            ttsWaiters.clear()
            waiters.forEach { it(offlineArabicVoice != null) }
        }
    }

    override fun onDestroy() {
        pendingSpeechResult = null
        speechRecognizer?.cancel()
        releaseSpeechRecognizer()
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
