package com.severina

import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "severina/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "muteSystemSound" -> {
                        try {
                            audioManager.setStreamVolume(AudioManager.STREAM_SYSTEM, 0, 0)
                            audioManager.adjustStreamVolume(
                                AudioManager.STREAM_SYSTEM, AudioManager.ADJUST_MUTE, 0
                            )
                        } catch (e: SecurityException) {
                            // MIUI/Xiaomi pode bloquear — ignora silenciosamente
                        }
                        result.success(null)
                    }
                    "unmuteSystemSound" -> {
                        try {
                            audioManager.adjustStreamVolume(
                                AudioManager.STREAM_SYSTEM, AudioManager.ADJUST_UNMUTE, 0
                            )
                        } catch (e: SecurityException) {
                            // ignora
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
