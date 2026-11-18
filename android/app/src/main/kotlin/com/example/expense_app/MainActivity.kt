package com.example.expense_app

import android.Manifest
import android.content.ComponentName
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
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    private companion object {
        const val VOICE_CHANNEL = "com.byepro.finance/assistant_voice"
        const val APP_ICON_CHANNEL = "com.byepro.finance/app_icon"
        const val MICROPHONE_PERMISSION_REQUEST = 9142
    }

    private var pendingSpeechResult: MethodChannel.Result? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var speechAttemptGeneration = 0
    private var offlineFallbackAttempted = false
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_ICON_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queueAppIcon" -> queueLauncherIcon(
                        call.argument<String>("mode"),
                        result
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun queueLauncherIcon(mode: String?, result: MethodChannel.Result) {
        if (mode != "dark" && mode != "light") {
            result.error(
                "invalid_app_icon_mode",
                "App icon mode must be either dark or light.",
                null
            )
            return
        }

        // Launcher changes broadcast PACKAGE_CHANGED. Queue the requested icon
        // and apply it only after the Activity has left the foreground.
        getSharedPreferences("bye_pro_launcher", MODE_PRIVATE)
            .edit()
            .putString("pending_icon_mode", mode)
            .apply()
        result.success(true)
    }

    override fun onStop() {
        super.onStop()
        applyPendingLauncherIcon()
    }

    private fun applyPendingLauncherIcon() {
        val preferences = getSharedPreferences("bye_pro_launcher", MODE_PRIVATE)
        val mode = preferences.getString("pending_icon_mode", null) ?: return
        val lastAppliedMode = preferences.getString("active_icon_mode", null)
        if (lastAppliedMode == mode) {
            preferences.edit().remove("pending_icon_mode").apply()
            return
        }

        val enabledAlias = when (mode) {
            "dark" -> ComponentName(packageName, "$packageName.MainActivityDarkIcon")
            "light" -> ComponentName(packageName, "$packageName.MainActivityLightIcon")
            else -> return
        }
        val disabledAlias = if (mode == "dark") {
            ComponentName(packageName, "$packageName.MainActivityLightIcon")
        } else {
            ComponentName(packageName, "$packageName.MainActivityDarkIcon")
        }

        try {
            // Apply both states atomically on Android 13+, after the app is
            // backgrounded. Older versions enable the new alias before
            // disabling the previous one, so a launcher entry always exists.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.setComponentEnabledSettings(
                    mutableListOf(
                        PackageManager.ComponentEnabledSetting(
                            enabledAlias,
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            PackageManager.DONT_KILL_APP
                        ),
                        PackageManager.ComponentEnabledSetting(
                            disabledAlias,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                    )
                )
            } else {
                packageManager.setComponentEnabledSetting(
                    enabledAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                packageManager.setComponentEnabledSetting(
                    disabledAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
            preferences.edit()
                .putString("active_icon_mode", mode)
                .remove("pending_icon_mode")
                .apply()
        } catch (error: Exception) {
            // Keep the pending choice so a later background transition can retry.
            android.util.Log.w("MainActivity", "Deferred launcher icon update failed", error)
        }
    }

    private fun recognizeArabicSpeech(result: MethodChannel.Result) {
        if (pendingSpeechResult != null) {
            result.error("speech_busy", "Speech recognition is already running.", null)
            return
        }

        pendingSpeechResult = result
        offlineFallbackAttempted = false
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

        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            finishSpeechWithError(
                "speech_unavailable",
                "No Android speech recognition service is available."
            )
            return
        }

        val canUseOnDeviceArabic = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

        if (canUseOnDeviceArabic) {
            beginOnDeviceArabicSpeechRecognition()
        } else {
            beginDefaultArabicSpeechRecognition()
        }
    }

    private fun beginOnDeviceArabicSpeechRecognition() {
        if (pendingSpeechResult == null) return

        try {
            val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            speechRecognizer = recognizer
            val attempt = ++speechAttemptGeneration
            val intent = createArabicRecognitionIntent(preferOffline = true)
            attachRecognitionListener(recognizer, attempt, allowDefaultFallback = true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                recognizer.checkRecognitionSupport(
                    intent,
                    mainExecutor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                            if (!isCurrentSpeechAttempt(attempt)) return

                            val hasInstalledArabic = recognitionSupport.installedOnDeviceLanguages
                                .any {
                                    Locale.forLanguageTag(it).language.equals(
                                        "ar",
                                        ignoreCase = true
                                    )
                                }

                            if (hasInstalledArabic) {
                                startSpeechListening(
                                    recognizer,
                                    intent,
                                    attempt,
                                    allowDefaultFallback = true
                                )
                            } else {
                                fallbackToDefaultArabicRecognition()
                            }
                        }

                        override fun onError(error: Int) {
                            if (isCurrentSpeechAttempt(attempt)) {
                                fallbackToDefaultArabicRecognition()
                            }
                        }
                    }
                )
            } else {
                startSpeechListening(
                    recognizer,
                    intent,
                    attempt,
                    allowDefaultFallback = true
                )
            }
        } catch (_: SecurityException) {
            finishSpeechWithError("permission_denied", "Microphone permission is required.")
        } catch (_: Exception) {
            fallbackToDefaultArabicRecognition()
        }
    }

    private fun beginDefaultArabicSpeechRecognition() {
        if (pendingSpeechResult == null) return

        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            finishSpeechWithError(
                "speech_unavailable",
                "No Android speech recognition service is available."
            )
            return
        }

        try {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
            speechRecognizer = recognizer
            val attempt = ++speechAttemptGeneration
            attachRecognitionListener(recognizer, attempt, allowDefaultFallback = false)
            startSpeechListening(
                recognizer,
                createArabicRecognitionIntent(preferOffline = false),
                attempt,
                allowDefaultFallback = false
            )
        } catch (_: SecurityException) {
            finishSpeechWithError("permission_denied", "Microphone permission is required.")
        } catch (_: Exception) {
            finishSpeechWithError("speech_failed", "Unable to start speech recognition.")
        }
    }

    private fun createArabicRecognitionIntent(preferOffline: Boolean): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ar")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "ar")
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, preferOffline)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
    }

    private fun attachRecognitionListener(
        recognizer: SpeechRecognizer,
        attempt: Int,
        allowDefaultFallback: Boolean
    ) {
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onPartialResults(partialResults: Bundle?) = Unit
            override fun onEvent(eventType: Int, params: Bundle?) = Unit

            override fun onError(error: Int) {
                if (!isCurrentSpeechAttempt(attempt)) return

                if (allowDefaultFallback && shouldFallbackToDefault(error)) {
                    fallbackToDefaultArabicRecognition()
                    return
                }

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
                if (!isCurrentSpeechAttempt(attempt)) return

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
    }

    private fun startSpeechListening(
        recognizer: SpeechRecognizer,
        intent: Intent,
        attempt: Int,
        allowDefaultFallback: Boolean
    ) {
        if (!isCurrentSpeechAttempt(attempt)) return

        try {
            recognizer.startListening(intent)
        } catch (_: SecurityException) {
            finishSpeechWithError("permission_denied", "Microphone permission is required.")
        } catch (_: Exception) {
            if (allowDefaultFallback) {
                fallbackToDefaultArabicRecognition()
            } else {
                finishSpeechWithError("speech_failed", "Unable to start speech recognition.")
            }
        }
    }

    private fun shouldFallbackToDefault(error: Int): Boolean {
        return error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
            error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ||
            error == SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT ||
            error == SpeechRecognizer.ERROR_SERVER ||
            error == SpeechRecognizer.ERROR_SERVER_DISCONNECTED ||
            error == SpeechRecognizer.ERROR_NETWORK ||
            error == SpeechRecognizer.ERROR_NETWORK_TIMEOUT ||
            error == SpeechRecognizer.ERROR_SERVER_RECOGNITION
    }

    private fun fallbackToDefaultArabicRecognition() {
        if (pendingSpeechResult == null || offlineFallbackAttempted) return

        offlineFallbackAttempted = true
        releaseSpeechRecognizer()
        beginDefaultArabicSpeechRecognition()
    }

    private fun isCurrentSpeechAttempt(attempt: Int): Boolean {
        return pendingSpeechResult != null && speechAttemptGeneration == attempt
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
        speechAttemptGeneration++
        val recognizer = speechRecognizer
        speechRecognizer = null
        recognizer?.cancel()
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
