import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let bridge = LiteRTBridge()
  private let streamHandler = LiteRTStreamHandler()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(name: "com.myday.my_day/litert", binaryMessenger: controller.binaryMessenger)
      let eventChannel = FlutterEventChannel(name: "com.myday.my_day/litert/stream", binaryMessenger: controller.binaryMessenger)
      eventChannel.setStreamHandler(streamHandler)
      methodChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "bridge_unavailable", message: "LiteRT bridge unavailable", details: nil))
          return
        }
        switch call.method {
        case "initialize":
          self.bridge.initialize()
          result(nil)
        case "detectVoiceActivity":
          let audioData = self.extractFloatArray(call.arguments, key: "audioData")
          result(self.bridge.detectVoiceActivity(audioChunk: audioData))
        case "transcribe":
          let audioData = self.extractFloatArray(call.arguments, key: "audioData")
          DispatchQueue.global(qos: .userInitiated).async {
            let transcript = self.bridge.transcribe(audioData: audioData)
            DispatchQueue.main.async {
              result(transcript)
            }
          }
        case "generateFunctionCall":
          let arguments = call.arguments as? [String: Any]
          let transcript = arguments?["transcript"] as? String ?? ""
          result(self.bridge.generateFunctionCall(transcript: transcript))
        case "processAudioChunk":
          let audioChunk = self.extractFloatArray(call.arguments, key: "chunk")
          let detected = self.bridge.detectVoiceActivity(audioChunk: audioChunk)
          if detected {
            self.streamHandler.eventSink?([
              "text": "",
              "intent": nil,
              "confidence": 0.0,
            ])
          }
          result(nil)
        case "release":
          self.bridge.release()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  private func extractFloatArray(_ value: Any?, key: String) -> [Float] {
    guard let arguments = value as? [String: Any] else {
      return []
    }
    let data = arguments[key] as? FlutterStandardTypedData
    guard let typedData = data else {
      return []
    }
    return typedData.data.withUnsafeBytes { buffer in
      let floatBuffer = buffer.bindMemory(to: Float.self)
      return Array(floatBuffer)
    }
  }
}
