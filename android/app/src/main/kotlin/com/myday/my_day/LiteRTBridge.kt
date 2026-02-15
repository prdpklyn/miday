package com.myday.my_day

import android.content.Context

class LiteRTBridge(private val context: Context) {
    fun initialize() {
    }
    fun detectVoiceActivity(audioChunk: FloatArray): Boolean {
        return audioChunk.isNotEmpty()
    }
    fun transcribe(audioData: FloatArray): String {
        return ""
    }
    fun generateFunctionCall(transcript: String): Map<String, Any?> {
        return mapOf(
            "name" to "",
            "parameters" to emptyMap<String, Any?>(),
        )
    }
    fun release() {
    }
}
