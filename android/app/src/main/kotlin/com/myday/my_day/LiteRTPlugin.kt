package com.myday.my_day

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LiteRTPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var bridge: LiteRTBridge? = null
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        bridge = LiteRTBridge(context)
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
        bridge = null
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> handleInitialize(result)
            "detectVoiceActivity" -> handleDetectVoiceActivity(call, result)
            "transcribe" -> handleTranscribe(call, result)
            "generateFunctionCall" -> handleGenerateFunctionCall(call, result)
            "processAudioChunk" -> handleProcessAudioChunk(call, result)
            "release" -> handleRelease(result)
            else -> result.notImplemented()
        }
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    private fun handleInitialize(result: MethodChannel.Result) {
        bridge?.initialize()
        result.success(null)
    }
    private fun handleDetectVoiceActivity(call: MethodCall, result: MethodChannel.Result) {
        val audioChunk = call.argument<FloatArray>("audioData") ?: FloatArray(0)
        val detected = bridge?.detectVoiceActivity(audioChunk) ?: false
        result.success(detected)
    }
    private fun handleTranscribe(call: MethodCall, result: MethodChannel.Result) {
        val audioData = call.argument<FloatArray>("audioData") ?: FloatArray(0)
        val transcript = bridge?.transcribe(audioData) ?: ""
        result.success(transcript)
    }
    private fun handleGenerateFunctionCall(call: MethodCall, result: MethodChannel.Result) {
        val transcript = call.argument<String>("transcript") ?: ""
        val functionCall = bridge?.generateFunctionCall(transcript) ?: emptyMap<String, Any?>()
        result.success(functionCall)
    }
    private fun handleProcessAudioChunk(call: MethodCall, result: MethodChannel.Result) {
        val audioChunk = call.argument<FloatArray>("chunk") ?: FloatArray(0)
        val detected = bridge?.detectVoiceActivity(audioChunk) ?: false
        if (detected) {
            eventSink?.success(
                mapOf(
                    "text" to "",
                    "intent" to null,
                    "confidence" to 0.0,
                ),
            )
        }
        result.success(null)
    }
    private fun handleRelease(result: MethodChannel.Result) {
        bridge?.release()
        result.success(null)
    }
    companion object {
        private const val METHOD_CHANNEL = "com.myday.my_day/litert"
        private const val EVENT_CHANNEL = "com.myday.my_day/litert/stream"
    }
}
