import Foundation
import Combine

/// 语音记账服务
/// 整合语音识别、智能分类和数据存储
public class VoiceTransactionService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isProcessing = false
    @Published public var recordingState: ProcessingState = .ready
    @Published public var recognizedTransaction: TransactionSuggestion?
    @Published public var errorMessage: String?
    
    // MARK: - Processing States
    public enum ProcessingState {
        case ready              // 准备就绪
        case recording          // 录音中
        case recognizing        // 语音识别中
        case categorizing       // 智能分类中
        case saving            // 保存中
        case completed         // 完成
        case error             // 错误
        
        public var description: String {
            switch self {
            case .ready: return "准备就绪"
            case .recording: return "录音中..."
            case .recognizing: return "识别语音..."
            case .categorizing: return "智能分析..."
            case .saving: return "保存记录..."
            case .completed: return "记账完成"
            case .error: return "处理失败"
            }
        }
    }
    
    // MARK: - Transaction Suggestion
    public struct TransactionSuggestion {
        public let originalText: String
        public let category: TransactionCategory
        public let amount: Decimal?
        public let description: String?
        public let confidence: Double
        public let date: Date
        
        public init(originalText: String, category: TransactionCategory, amount: Decimal?, description: String?, confidence: Double, date: Date = Date()) {
            self.originalText = originalText
            self.category = category
            self.amount = amount
            self.description = description
            self.confidence = confidence
            self.date = date
        }
    }
    
    // MARK: - Dependencies
    private let speechService: SpeechRecognitionService
    private let categorizerService: TransactionCategorizerService
    private let transactionRepository: TransactionRepositoryProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(
        speechService: SpeechRecognitionService,
        categorizerService: TransactionCategorizerService,
        transactionRepository: TransactionRepositoryProtocol
    ) {
        self.speechService = speechService
        self.categorizerService = categorizerService
        self.transactionRepository = transactionRepository
        
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // 监听语音识别状态变化
        speechService.$recordingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speechState in
                self?.updateStateFromSpeech(speechState)
            }
            .store(in: &cancellables)
        
        // 监听识别结果
        speechService.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                if !text.isEmpty && self?.speechService.recordingState == .completed {
                    self?.processSpeechResult(text)
                }
            }
            .store(in: &cancellables)
        
        // 监听语音服务错误
        speechService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMsg in
                if let error = errorMsg {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    public func startVoiceTransaction() {
        guard !isProcessing else { return }
        
        // 重置状态
        reset()
        isProcessing = true
        recordingState = .recording
        
        // 开始语音识别
        speechService.startRecording()
    }
    
    public func stopVoiceTransaction() {
        speechService.stopRecording()
    }
    
    /// 停止录音 (兼容测试)
    public func stopRecording() {
        stopVoiceTransaction()
    }
    
    public func confirmTransaction() {
        guard let suggestion = recognizedTransaction else { return }
        
        recordingState = .saving
        
        let transaction = TransactionEntity(
            id: UUID(),
            amount: suggestion.amount ?? 0,
            categoryID: suggestion.category.rawValue,
            categoryName: suggestion.category.localizedName,
            note: suggestion.description,
            date: suggestion.date,
            source: .voice,
            createdAt: Date(),
            syncStatus: .pending
        )
        
        transactionRepository.create(transaction)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.recordingState = .completed
                        self?.completeProcess()
                    case .failure(let error):
                        self?.handleError(error.localizedDescription)
                    }
                },
                receiveValue: { _ in
                    // 保存成功
                }
            )
            .store(in: &cancellables)
    }
    
    public func editTransaction(amount: Decimal?, description: String?, category: TransactionCategory?) {
        guard var suggestion = recognizedTransaction else { return }
        
        if let amount = amount {
            suggestion = TransactionSuggestion(
                originalText: suggestion.originalText,
                category: category ?? suggestion.category,
                amount: amount,
                description: description ?? suggestion.description,
                confidence: suggestion.confidence,
                date: suggestion.date
            )
        }
        
        self.recognizedTransaction = suggestion
    }
    
    public func cancelTransaction() {
        if speechService.isRecording {
            speechService.stopRecording()
        }
        reset()
    }
    
    // MARK: - Private Methods
    private func updateStateFromSpeech(_ speechState: SpeechRecognitionService.RecordingState) {
        switch speechState {
        case .recording:
            recordingState = .recording
        case .processing:
            recordingState = .recognizing
        case .completed:
            // 将在processSpeechResult中处理
            break
        case .error:
            recordingState = .error
        case .ready:
            if recordingState == .recording || recordingState == .recognizing {
                recordingState = .ready
                isProcessing = false
            }
        }
    }
    
    private func processSpeechResult(_ text: String) {
        recordingState = .categorizing
        processRecognizedText(text)
    }
    
    // MARK: - Business Logic Methods (Required by Audit)
    
    /// 处理识别的文本，提取交易信息
    public func processRecognizedText(_ text: String) {
        // 使用分类服务处理语音文本
        let categoryMatch = categorizerService.categorizeTransaction(from: text)
        
        // 创建交易建议
        let suggestion = TransactionSuggestion(
            originalText: text,
            category: categoryMatch.category,
            amount: categoryMatch.extractedAmount,
            description: categoryMatch.extractedDescription,
            confidence: categoryMatch.confidence,
            date: Date()
        )
        
        self.recognizedTransaction = suggestion
        self.recordingState = .completed
        
        // 如果置信度高且有金额，可以自动确认
        if categoryMatch.confidence > 0.8 && categoryMatch.extractedAmount != nil && categoryMatch.extractedAmount! > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.saveTransaction()
            }
        }
    }
    
    /// 保存交易记录到数据库
    public func saveTransaction() {
        guard let suggestion = recognizedTransaction else {
            errorMessage = "没有可保存的交易信息"
            recordingState = .error
            return
        }
        
        guard let amount = suggestion.amount, amount > 0 else {
            errorMessage = "交易金额无效"
            recordingState = .error
            return
        }
        
        recordingState = .saving
        
        let transaction = TransactionEntity(
            id: UUID(),
            amount: amount,
            categoryID: suggestion.category.rawValue,
            categoryName: suggestion.category.localizedName,
            note: suggestion.description,
            date: suggestion.date,
            source: .voice,
            createdAt: Date(),
            syncStatus: .pending
        )
        
        transactionRepository.create(transaction)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "保存失败: \(error.localizedDescription)"
                        self?.recordingState = .error
                    }
                    self?.isProcessing = false
                },
                receiveValue: { [weak self] savedTransaction in
                    // 保存成功
                    self?.recordingState = .saved
                    self?.isProcessing = false
                    
                    // 3秒后自动重置
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        self?.reset()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        recordingState = .error
        isProcessing = false
        
        // 3秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.reset()
        }
    }
    
    private func completeProcess() {
        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.reset()
        }
    }
    
    private func reset() {
        isProcessing = false
        recordingState = .ready
        recognizedTransaction = nil
        errorMessage = nil
        speechService.reset()
    }
}

// MARK: - Permissions
extension VoiceTransactionService {
    
    public var hasRequiredPermissions: Bool {
        return speechService.hasSpeechPermission && speechService.hasMicrophonePermission
    }
    
    public func requestPermissions() async -> Bool {
        // 请求麦克风权限
        let micPermission = await speechService.requestMicrophonePermission()
        
        // 语音识别权限已在初始化时请求
        let speechPermission = speechService.hasSpeechPermission
        
        return micPermission && speechPermission
    }
}

// MARK: - Quick Actions
extension VoiceTransactionService {
    
    /// 快速记账（不使用语音）
    public func quickTransaction(amount: Decimal, category: TransactionCategory, description: String? = nil) {
        recordingState = .saving
        isProcessing = true
        
        let transaction = TransactionEntity(
            id: UUID(),
            amount: amount,
            categoryID: category.rawValue,
            categoryName: category.localizedName,
            note: description,
            date: Date(),
            source: .manual,
            createdAt: Date(),
            syncStatus: .pending
        )
        
        transactionRepository.create(transaction)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        self?.recordingState = .completed
                        self?.completeProcess()
                    case .failure(let error):
                        self?.handleError(error.localizedDescription)
                    }
                },
                receiveValue: { _ in
                    // 保存成功
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Testing Support
#if DEBUG
extension VoiceTransactionService {
    
    public func simulateVoiceInput(_ text: String) {
        recordingState = .recognizing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.processSpeechResult(text)
        }
    }
    
    public func testCategorization() {
        categorizerService.testCategorization()
    }
}
#endif