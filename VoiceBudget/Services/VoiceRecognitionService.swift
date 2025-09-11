import Foundation
import Speech
import AVFoundation
import Combine

class VoiceRecognitionService: NSObject, ObservableObject {
    
    // MARK: - Publishers
    private let recognizedTextSubject = PassthroughSubject<String, Never>()
    private let recordingStateSubject = PassthroughSubject<Bool, Never>()
    private let errorSubject = PassthroughSubject<Error?, Never>()
    
    var recognizedTextPublisher: AnyPublisher<String, Never> {
        recognizedTextSubject.eraseToAnyPublisher()
    }
    
    var recordingStatePublisher: AnyPublisher<Bool, Never> {
        recordingStateSubject.eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<Error?, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var isRecording = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    // MARK: - Public Methods
    
    func startRecording() {
        guard !isRecording else { return }
        
        Task {
            do {
                try await requestPermissions()
                try await startSpeechRecognition()
            } catch {
                await MainActor.run {
                    self.errorSubject.send(error)
                }
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
        recordingStateSubject.send(false)
    }
    
    // MARK: - Private Methods
    
    private func setupSpeechRecognizer() {
        // 优先使用中文识别器
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        
        // 如果中文不可用，使用系统默认
        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer()
        }
        
        speechRecognizer?.delegate = self
    }
    
    private func requestPermissions() async throws {
        // 请求语音识别权限
        let speechAuthStatus = await SFSpeechRecognizer.requestAuthorization()
        guard speechAuthStatus == .authorized else {
            throw VoiceRecognitionError.speechRecognitionDenied
        }
        
        // 请求麦克风权限
        let micAuthStatus = await AVAudioSession.sharedInstance().requestRecordPermission()
        guard micAuthStatus else {
            throw VoiceRecognitionError.microphoneAccessDenied
        }
    }
    
    private func startSpeechRecognition() async throws {
        // 取消之前的任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 配置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecognitionError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 获取输入节点
        let inputNode = audioEngine.inputNode
        
        // 创建识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                self.recognizedTextSubject.send(recognizedText)
            }
            
            if error != nil || result?.isFinal == true {
                self.stopRecording()
                if let error = error {
                    self.errorSubject.send(error)
                }
            }
        }
        
        // 配置音频输入格式
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // 启动音频引擎
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        recordingStateSubject.send(true)
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            stopRecording()
            errorSubject.send(VoiceRecognitionError.speechRecognitionUnavailable)
        }
    }
}

// MARK: - Error Types

enum VoiceRecognitionError: Error, LocalizedError {
    case speechRecognitionDenied
    case microphoneAccessDenied
    case speechRecognitionUnavailable
    case unableToCreateRequest
    case audioEngineError
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionDenied:
            return "语音识别权限被拒绝"
        case .microphoneAccessDenied:
            return "麦克风访问权限被拒绝"
        case .speechRecognitionUnavailable:
            return "语音识别服务不可用"
        case .unableToCreateRequest:
            return "无法创建语音识别请求"
        case .audioEngineError:
            return "音频引擎错误"
        }
    }
}