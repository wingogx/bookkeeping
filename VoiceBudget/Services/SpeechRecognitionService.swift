import Foundation
import Speech
import AVFoundation
import Combine

protocol SpeechRecognitionServiceProtocol {
    var isAvailable: Bool { get }
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func startRecording() async throws
    func stopRecording()
    var recognizedTextPublisher: AnyPublisher<String, Never> { get }
    var errorPublisher: AnyPublisher<Error, Never> { get }
}

class SpeechRecognitionService: NSObject, SpeechRecognitionServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private let recognizedTextSubject = PassthroughSubject<String, Never>()
    private let errorSubject = PassthroughSubject<Error, Never>()
    
    @Published var isRecording = false
    
    var isAvailable: Bool {
        speechRecognizer?.isAvailable ?? false
    }
    
    var recognizedTextPublisher: AnyPublisher<String, Never> {
        recognizedTextSubject.eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    @MainActor
    func startRecording() async throws {
        // 取消之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 检查权限
        let hasPermission = await requestPermission()
        guard hasPermission else {
            throw SpeechRecognitionError.permissionDenied
        }
        
        // 检查可用性
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        // 设置音频会话
        try setupAudioSessionForRecording()
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 设置音频引擎
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // 准备并启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        // 开始识别
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let recognizedText = result.bestTranscription.formattedString
                    self?.recognizedTextSubject.send(recognizedText)
                    
                    if result.isFinal {
                        self?.stopRecording()
                    }
                }
                
                if let error = error {
                    self?.errorSubject.send(error)
                    self?.stopRecording()
                }
            }
        }
        
        isRecording = true
    }
    
    @MainActor
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        
        // 恢复音频会话
        resetAudioSession()
    }
    
    // MARK: - Private Methods
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            errorSubject.send(SpeechRecognitionError.audioSessionSetupFailed)
        }
    }
    
    private func setupAudioSessionForRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func resetAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to reset audio session: \(error)")
        }
    }
}

// MARK: - Error Types
enum SpeechRecognitionError: Error, LocalizedError {
    case permissionDenied
    case recognizerUnavailable
    case unableToCreateRequest
    case audioSessionSetupFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "语音识别权限被拒绝"
        case .recognizerUnavailable:
            return "语音识别服务不可用"
        case .unableToCreateRequest:
            return "无法创建语音识别请求"
        case .audioSessionSetupFailed:
            return "音频会话设置失败"
        }
    }
}