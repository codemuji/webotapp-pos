package com.grocerypos.mobile

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.grocerypos.mobile/scanner_sound"
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (_: Exception) {}

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playBeep" -> {
                    try {
                        if (toneGenerator == null) {
                            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                        }
                        // Authentic retail scanner gun chirp: 2048Hz high tone for 120ms
                        toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 120)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "playErrorBeep" -> {
                    try {
                        if (toneGenerator == null) {
                            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                        }
                        // Rejection / not found alert tone
                        toneGenerator?.startTone(ToneGenerator.TONE_PROP_NACK, 200)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
