import Flutter
import Foundation
import TensorFlowLite
import Speech
import AVFoundation

// MARK: - LiteRT Bridge

final class LiteRTBridge {

    // MARK: - Properties

    private var vadInterpreter: Interpreter?
    private var functionGemmaInterpreter: Interpreter?
    private var speechRecognizer: SFSpeechRecognizer?

    private let modelQueue = DispatchQueue(label: "com.myday.litert.models", qos: .userInitiated)

    // VAD state (Silero VAD uses stateful LSTM)
    private var vadState: [Float] = Array(repeating: 0.0, count: 128)
    private var vadSr: [Float] = [16000.0]

    private var isInitialized = false

    // MARK: - Initialization

    func initialize() {
        modelQueue.async { [weak self] in
            self?.loadModels()
        }
    }

    private func loadModels() {
        // Load Silero VAD model
        if let vadPath = Bundle.main.path(forResource: "silero_vad", ofType: "tflite") {
            do {
                var options = Interpreter.Options()
                options.threadCount = 2
                vadInterpreter = try Interpreter(modelPath: vadPath, options: options)
                try vadInterpreter?.allocateTensors()
                print("[LiteRT] Silero VAD loaded successfully")
            } catch {
                print("[LiteRT] Failed to load VAD model: \(error)")
            }
        } else {
            print("[LiteRT] VAD model not found in bundle")
        }

        // Load FunctionGemma model
        if let gemmaPath = Bundle.main.path(forResource: "functiongemma-myday", ofType: "tflite") {
            do {
                var options = Interpreter.Options()
                options.threadCount = 4

                functionGemmaInterpreter = try Interpreter(modelPath: gemmaPath, options: options)
                try functionGemmaInterpreter?.allocateTensors()
                print("[LiteRT] FunctionGemma loaded successfully")
            } catch {
                print("[LiteRT] Failed to load FunctionGemma model: \(error)")
            }
        } else {
            print("[LiteRT] FunctionGemma model not found in bundle")
        }

        // Initialize Speech Recognizer (fallback for Whisper)
        // Note: Replace with whisper.cpp for better offline accuracy
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("[LiteRT] Speech recognition authorized")
            case .denied:
                print("[LiteRT] Speech recognition denied by user")
            case .restricted:
                print("[LiteRT] Speech recognition restricted on this device")
            case .notDetermined:
                print("[LiteRT] Speech recognition authorization not determined")
            @unknown default:
                print("[LiteRT] Speech recognition unknown authorization status")
            }
        }

        isInitialized = true
        print("[LiteRT] Initialization complete")
    }

    // MARK: - Voice Activity Detection

    func detectVoiceActivity(audioChunk: [Float]) -> Bool {
        guard let interpreter = vadInterpreter, !audioChunk.isEmpty else {
            // Fallback to energy-based detection
            return energyBasedVAD(audioChunk: audioChunk)
        }

        do {
            // Silero VAD expects: [batch, audio_length] for audio, plus state tensors
            // Simplified: just use energy-based for now if model format doesn't match

            // For production, you'd properly format inputs for Silero VAD:
            // Input 0: audio [1, 512] or similar chunk size
            // Input 1: state [1, 2, 1, 128]
            // Input 2: sr [1] (sample rate)

            // For now, use reliable energy-based detection
            return energyBasedVAD(audioChunk: audioChunk)

        } catch {
            print("[LiteRT] VAD inference error: \(error)")
            return energyBasedVAD(audioChunk: audioChunk)
        }
    }

    private func energyBasedVAD(audioChunk: [Float]) -> Bool {
        guard !audioChunk.isEmpty else { return false }

        // Calculate RMS energy
        let sumOfSquares = audioChunk.reduce(0.0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(audioChunk.count))

        // Threshold tuned for speech (adjust based on testing)
        let threshold: Float = 0.02
        return rms > threshold
    }

    // MARK: - Transcription

    func transcribe(audioData: [Float]) -> String {
        // For now, we'll use a synchronous approach
        // In production, this should be async with proper audio buffering

        // Convert float array to audio buffer
        guard let audioBuffer = createAudioBuffer(from: audioData) else {
            print("[LiteRT] Failed to create audio buffer")
            return ""
        }

        // Write to temporary file for speech recognition
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")

        do {
            try writeWAVFile(buffer: audioBuffer, to: tempURL)
        } catch {
            print("[LiteRT] Failed to write temp audio file: \(error)")
            return ""
        }

        // Use Speech framework
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("[LiteRT] Speech recognizer not available")
            return ""
        }

        let semaphore = DispatchSemaphore(value: 0)
        var transcription = ""

        let request = SFSpeechURLRecognitionRequest(url: tempURL)
        request.shouldReportPartialResults = false

        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                print("[LiteRT] Speech recognition error: \(error)")
            }
            if let result = result, result.isFinal {
                transcription = result.bestTranscription.formattedString
            }
            semaphore.signal()
        }

        // Wait for recognition (with timeout)
        _ = semaphore.wait(timeout: .now() + 10.0)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        print("[LiteRT] Transcription: \(transcription)")
        return transcription
    }

    private func createAudioBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)

        if let channelData = buffer.floatChannelData {
            for (index, sample) in samples.enumerated() {
                channelData[0][index] = sample
            }
        }

        return buffer
    }

    private func writeWAVFile(buffer: AVAudioPCMBuffer, to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }

    // MARK: - Function Generation

    func generateFunctionCall(transcript: String) -> [String: Any] {
        guard let interpreter = functionGemmaInterpreter, !transcript.isEmpty else {
            print("[LiteRT] FunctionGemma not available or empty transcript")
            return ["name": "", "parameters": [:] as [String: Any]]
        }

        do {
            // Build prompt in FunctionGemma format
            let prompt = """
            <|developer|>You are a model that can do function calling with the following functions</s>
            <|user|>\(transcript)</s>
            <|assistant|>
            """

            // Tokenize (simplified - in production use proper tokenizer)
            let tokens = tokenize(prompt)

            // Pad/truncate to expected length (256 based on model spec)
            let paddedTokens = padTokens(tokens, toLength: 256)

            // Convert to Data for input tensor
            let inputData = paddedTokens.withUnsafeBufferPointer { Data(buffer: $0) }

            // Copy to input tensor
            try interpreter.copy(inputData, toInputAt: 0)

            // Run inference
            try interpreter.invoke()

            // Get output
            let outputTensor = try interpreter.output(at: 0)
            let outputData = outputTensor.data

            // Decode output tokens
            let outputTokens = decodeOutputTokens(outputData)
            let outputText = detokenize(outputTokens)

            // Parse function call from output
            return parseFunctionCall(outputText)

        } catch {
            print("[LiteRT] FunctionGemma inference error: \(error)")
            return ["name": "", "parameters": [:] as [String: Any]]
        }
    }

    // MARK: - Tokenization (Simplified)

    private func tokenize(_ text: String) -> [Int64] {
        // Simplified tokenization - in production, use proper SentencePiece tokenizer
        // This is a placeholder that won't work correctly
        // You need to load the tokenizer.json from the model and use it

        // For now, return placeholder tokens
        // TODO: Implement proper tokenization using the model's tokenizer
        print("[LiteRT] Warning: Using placeholder tokenization")
        return text.unicodeScalars.map { Int64($0.value) }
    }

    private func padTokens(_ tokens: [Int64], toLength length: Int) -> [Int64] {
        if tokens.count >= length {
            return Array(tokens.prefix(length))
        }
        return tokens + Array(repeating: 0, count: length - tokens.count)
    }

    private func decodeOutputTokens(_ data: Data) -> [Int64] {
        // Get logits and find argmax for each position
        // Output shape is [1, 256, vocab_size]
        // For simplicity, just extract first few tokens

        // TODO: Implement proper greedy/beam search decoding
        return []
    }

    private func detokenize(_ tokens: [Int64]) -> String {
        // TODO: Implement proper detokenization
        return tokens.map { String(UnicodeScalar(Int($0)) ?? UnicodeScalar(32)!) }.joined()
    }

    private func parseFunctionCall(_ text: String) -> [String: Any] {
        // Parse FunctionGemma output format:
        // <start_function_call>call:FUNCTION_NAME{key:<escape>value<escape>,...}<end_function_call>

        guard let startRange = text.range(of: "<start_function_call>call:"),
              let endRange = text.range(of: "<end_function_call>") else {
            print("[LiteRT] Could not parse function call from: \(text)")
            return ["name": "", "parameters": [:] as [String: Any]]
        }

        let callContent = String(text[startRange.upperBound..<endRange.lowerBound])

        // Extract function name
        guard let braceIndex = callContent.firstIndex(of: "{") else {
            return ["name": callContent, "parameters": [:] as [String: Any]]
        }

        let functionName = String(callContent[..<braceIndex])
        let paramsString = String(callContent[braceIndex...]).dropFirst().dropLast()

        // Parse parameters
        var parameters: [String: Any] = [:]
        let pairs = paramsString.components(separatedBy: ",")

        for pair in pairs {
            let parts = pair.components(separatedBy: ":")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                var value = parts.dropFirst().joined(separator: ":")
                    .replacingOccurrences(of: "<escape>", with: "")
                    .trimmingCharacters(in: .whitespaces)
                parameters[key] = value
            }
        }

        return ["name": functionName, "parameters": parameters]
    }

    // MARK: - Cleanup

    func release() {
        vadInterpreter = nil
        functionGemmaInterpreter = nil
        speechRecognizer = nil
        isInitialized = false
        print("[LiteRT] Resources released")
    }
}

// MARK: - Stream Handler

final class LiteRTStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
