import Speech
import AVFoundation
import Combine

/// 语音识别服务
/// 使用iOS Speech Framework实现语音转文本功能
public class SpeechRecognitionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var recognizedText = ""
    @Published public var isRecording = false
    @Published public var isAuthorized = false
    @Published public var errorMessage: String?
    @Published public var recordingState: RecordingState = .ready
    
    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Recording States
    public enum RecordingState {
        case ready          // 准备就绪
        case recording      // 正在录音
        case processing     // 处理中
        case completed      // 完成
        case error          // 错误
        
        var description: String {
            switch self {
            case .ready: return "准备就绪"
            case .recording: return "正在录音..."
            case .processing: return "识别中..."
            case .completed: return "识别完成"
            case .error: return "识别失败"
            }
        }
    }
    
    // MARK: - Initialization
    public init() {
        requestSpeechAuthorization()
        setupAudioSession()
    }
    
    // MARK: - Authorization
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.isAuthorized = true
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    self?.errorMessage = "语音识别未授权"
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Recording Control
    public func startRecording() {
        guard isAuthorized else {
            errorMessage = "语音识别未授权，请在设置中允许"
            return
        }
        
        guard !audioEngine.isRunning else { return }
        
        // 重置状态
        recognizedText = ""
        errorMessage = nil
        recordingState = .recording
        isRecording = true
        
        // 停止之前的任务
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            handleError("无法创建识别请求")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // 获取音频输入节点
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // 安装音频tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // 准备和启动音频引擎
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            handleError("音频引擎启动失败: \(error.localizedDescription)")
            return
        }
        
        // 开始识别任务
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.recognizedText = result.bestTranscription.formattedString
                    self?.recordingState = result.isFinal ? .processing : .recording
                }
                
                if let error = error {
                    self?.handleError("语音识别错误: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func stopRecording() {
        guard audioEngine.isRunning else { return }
        
        // 停止音频引擎
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 完成识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 更新状态
        recordingState = recognizedText.isEmpty ? .error : .completed
        isRecording = false
        
        // 如果有识别结果，2秒后重置状态
        if !recognizedText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.recordingState = .ready
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ message: String) {
        errorMessage = message
        recordingState = .error
        isRecording = false
        
        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.recordingState = .ready
            self?.errorMessage = nil
        }
    }
    
    // MARK: - Public Methods
    public func reset() {
        recognizedText = ""
        errorMessage = nil
        recordingState = .ready
        isRecording = false
    }
    
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}

// MARK: - Permissions Extension
extension SpeechRecognitionService {
    
    public func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    public var hasMicrophonePermission: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    public var hasSpeechPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    /// 请求所有必需的权限
    public func requestPermissions() async -> Bool {
        let microphoneGranted = await requestMicrophonePermission()
        
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        return microphoneGranted && speechGranted
    }
    
    /// 统一权限请求方法 (兼容测试)
    public func requestPermission() async -> Bool {
        return await requestPermissions()
    }
}